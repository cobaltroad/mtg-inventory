class OauthController < ApplicationController
  def discord_callback
    auth_info = request.env["omniauth.auth"]

    user = User.find_or_create_by_discord(auth_info)

    render json: { user_id: user.id, email: user.email, name: user.name }
  end

  def logout
    render json: { message: "Logged out" }
  end

  def status
    render json: { authenticated: false }
  end
end
