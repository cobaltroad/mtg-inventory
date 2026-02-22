require "cgi"

class AuthController < ApplicationController
  def discord
    return render json: { error: "OAuth not configured in development" }, status: :service_unavailable unless production?

    state = SecureRandom.hex(24)
    # Store state in a plain cookie - validated on callback
    cookies[:oauth_state] = { 
      value: state, 
      path: "/",
      secure: true, 
      httponly: true,
      same_site: :none
    }
    cookies[:return_to] = { 
      value: params[:return_to], 
      path: "/",
      same_site: :none, 
      secure: true, 
      httponly: true 
    } if params[:return_to].present?

    redirect_uri = "https://#{ENV.fetch("APP_DOMAIN", "http://localhost")}#{ENV.fetch("PUBLIC_API_PATH", "")}/auth/discord/callback"
    oauth_url = oauth_client.auth_code.authorize_url(
      client_id: ENV["DISCORD_CLIENT_ID"],
      redirect_uri: redirect_uri,
      scope: "identify email",
      state: state
    )

    redirect_to oauth_url, allow_other_host: true
  end

  def callback
    return redirect_to_frontend_with_error("OAuth not configured in development") unless production?

    return redirect_to_frontend_with_error("Authorization denied") if params[:error]

    state_error = verify_state
    return redirect_to_frontend_with_error(state_error) if state_error

    code = params[:code]
    token = exchange_code_for_token(code)

    if token.nil?
      return redirect_to_frontend_with_error("Failed to exchange code for token")
    end

    user_info = fetch_discord_user_info(token)
    return redirect_to_frontend_with_error("Failed to fetch user info") if user_info.nil?

    auth_info = build_auth_info(user_info)
    user = User.find_or_create_by_discord(auth_info)

    # Store user_id in a cookie for authentication
    response.set_cookie(:user_id, { 
      value: user.id.to_s, 
      secure: true, 
      httponly: true, 
      same_site: :lax,
      path: "/" 
    })

    redirect_to frontend_url("/auth/callback"), allow_other_host: true
  end

  def logout
    cookies.delete(:user_id)
    redirect_url = frontend_url("/login")
    redirect_to redirect_url, allow_other_host: true
  end

  def status
    user_id = cookies[:user_id]
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
    return "State mismatch - possible CSRF attack" if params[:state] != cookies[:oauth_state]
    nil
  end

  def production?
    Rails.env.production?
  end

  def redirect_to_frontend_with_error(message)
    redirect_url = frontend_url("/login?error=#{CGI.escape(message)}")
    redirect_to redirect_url, allow_other_host: true
  end

  def frontend_url(path = "")
    "https://#{ENV.fetch("APP_DOMAIN", "localhost")}#{ENV.fetch("PUBLIC_BASE_PATH", "")}#{path}"
  end

  def json_request?
    request.format.json?
  end
end
