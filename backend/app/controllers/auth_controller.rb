class AuthController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :json_request?
  before_action :verify_state, only: :callback

  def discord
    state = SecureRandom.hex(24)
    session[:oauth_state] = state
    session[:return_to] = params[:return_to] if params[:return_to].present?

    redirect_to oauth_client.auth_code.authorize_url(
      client_id: ENV["DISCORD_CLIENT_ID"],
      redirect_uri: "#{ENV.fetch("APP_DOMAIN", "http://localhost")}/api/auth/discord/callback",
      scope: "identify email",
      state: state
    )
  end

  def callback
    return render json: { error: "Authorization denied" }, status: :unauthorized if params[:error]

    error = verify_state
    return render json: { error: error }, status: :unauthorized if error

    code = params[:code]
    token = exchange_code_for_token(code)

    if token.nil?
      return render json: { error: "Failed to exchange code for token" }, status: :unauthorized
    end

    user_info = fetch_discord_user_info(token)
    return render json: { error: "Failed to fetch user info" }, status: :unauthorized if user_info.nil?

    auth_info = build_auth_info(user_info)
    user = User.find_or_create_by_discord(auth_info)

    session[:user_id] = user.id

    return_to = session.delete(:return_to) || "/"
    session.delete(:oauth_state)

    render json: { user_id: user.id, email: user.email, name: user.name, return_to: return_to }
  end

  def logout
    session.delete(:user_id)
    redirect_to ENV.fetch("APP_DOMAIN", "http://localhost")
  end

  def status
    if session[:user_id]
      user = User.find_by(id: session[:user_id])
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
      redirect_uri: "#{ENV.fetch("APP_DOMAIN", "http://localhost")}/api/auth/discord/callback"
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

  def json_request?
    request.format.json?
  end
end
