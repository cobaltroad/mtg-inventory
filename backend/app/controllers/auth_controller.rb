require "cgi"

# Build identifier for debugging
BUILD_ID = "v2026-02-22-0108"

class AuthController < ApplicationController
  # Using signed cookies for state instead of session

  def discord
    return render json: { error: "OAuth not configured in development" }, status: :service_unavailable unless production?

    state = SecureRandom.hex(24)
    # Store state in a plain cookie without domain - let browser handle it
    cookies[:oauth_state] = { 
      value: state, 
      path: "/",
      secure: true, 
      httponly: false 
    }
    cookies[:return_to] = { 
      value: params[:return_to], 
      path: "/",
      same_site: :none, 
      secure: true, 
      httponly: false 
    } if params[:return_to].present?

    Rails.logger.info "=== DISCORD ACTION ==="
    Rails.logger.info "Stored oauth_state in cookie: #{state}"
    Rails.logger.info "======================"

    redirect_uri = "https://#{ENV.fetch("APP_DOMAIN", "http://localhost")}#{ENV.fetch("PUBLIC_API_PATH", "")}/auth/discord/callback"
    oauth_url = oauth_client.auth_code.authorize_url(
      client_id: ENV["DISCORD_CLIENT_ID"],
      redirect_uri: redirect_uri,
      scope: "identify email",
      state: state
    )
    Rails.logger.debug { "OAuth authorization URL: #{oauth_url}" }

    redirect_to oauth_url, allow_other_host: true
  end

  def callback
    return redirect_to_frontend_with_error("OAuth not configured in development") unless production?

    return redirect_to_frontend_with_error("Authorization denied") if params[:error]

    # Skip state validation for now - third-party cookie issues
    # TODO: Add proper CSRF protection later

    code = params[:code]
    token = exchange_code_for_token(code)

    if token.nil?
      return redirect_to_frontend_with_error("Failed to exchange code for token")
    end

    user_info = fetch_discord_user_info(token)
    return redirect_to_frontend_with_error("Failed to fetch user info") if user_info.nil?

    auth_info = build_auth_info(user_info)
    user = User.find_or_create_by_discord(auth_info)

    Rails.logger.info "=== CALLBACK SUCCESS ==="
    Rails.logger.info "User created/found: #{user.id} - #{user.email}"
    Rails.logger.info "======================"

    # Store user_id in a cookie - try with explicit cookie jar
    response.set_cookie(:user_id, { 
      value: user.id.to_s, 
      secure: true, 
      httponly: false, 
      path: "/" 
    })
    Rails.logger.info "Cookies after setting: #{cookies.to_h.inspect}"
    Rails.logger.info "Set-Cookie header: #{response.headers['Set-Cookie'].inspect}"

    Rails.logger.debug { "Auth callback redirecting to: #{frontend_url("/auth/callback")}" }
    redirect_to frontend_url("/auth/callback"), allow_other_host: true
  end

  def logout
    session.delete(:user_id)
    redirect_url = frontend_url("/login")
    Rails.logger.debug { "Logout redirecting to: #{redirect_url}" }
    redirect_to redirect_url, allow_other_host: true
  end

  def status
    # Check user_id from cookie
    user_id = cookies[:user_id]
    Rails.logger.info "=== STATUS CHECK [#{BUILD_ID}] ==="
    Rails.logger.info "user_id cookie: #{user_id.inspect}"
    if user_id
      user = User.find_by(id: user_id.to_i)
      if user
        return render json: {
          authenticated: true,
          user: {
            id: user.id,
            email: user.email,
            name: user.name
          }
        }
      end
    end

    render json: { authenticated: false }
  end

  private

  def oauth_client
    OAuth2::Client.new(
      ENV["DISCORD_CLIENT_ID"],
      ENV["DISCORD_CLIENT_SECRET"],
      site: "https://discord.com",
      token_url: "/api/oauth2/token",
      authorize_url: "/oauth2/authorize"
    )
  end

  def exchange_code_for_token(code)
    oauth_client.auth_code.get_token(
      code,
      redirect_uri: "https://#{ENV.fetch("APP_DOMAIN", "http://localhost")}#{ENV.fetch("PUBLIC_API_PATH", "")}/auth/discord/callback"
    )
  rescue OAuth2::Error => e
    Rails.logger.error "OAuth token exchange failed: #{e.message}"
    nil
  end

  def fetch_discord_user_info(token)
    access_token = token.token
    response = Faraday.get("https://discord.com/api/users/@me") do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
    end

    return nil unless response.status == 200

    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "Failed to fetch Discord user info: #{e.message}"
    nil
  end

  def build_auth_info(user_info)
    {
      "provider" => "discord",
      "uid" => user_info["id"],
      "info" => {
        "email" => user_info["email"],
        "name" => user_info["username"]
      }
    }
  end

  def verify_state
    return "Missing state parameter" if params[:state].blank?
    return "State mismatch - possible CSRF attack" if params[:state] != session[:oauth_state]
    nil
  end

  def production?
    Rails.env.production?
  end

  def redirect_to_frontend_with_error(message)
    redirect_url = frontend_url("/login?error=#{CGI.escape(message)}")
    Rails.logger.debug { "Redirecting to frontend with error: #{redirect_url}" }
    redirect_to redirect_url, allow_other_host: true
  end

  def frontend_url(path = "")
    url = "https://#{ENV.fetch("APP_DOMAIN", "localhost")}#{ENV.fetch("PUBLIC_BASE_PATH", "")}#{path}"
    Rails.logger.debug { "Generated frontend URL: #{url}" }
    url
  end

  def json_request?
    request.format.json?
  end
end
