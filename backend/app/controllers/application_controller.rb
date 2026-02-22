class ApplicationController < ActionController::API
  include ActionController::Cookies

  class DefaultUserMissingError < StandardError
    def initialize
      super(
        "The default user (#{User::DEFAULT_EMAIL}) was not found in the database. " \
        "Please run 'rails db:seed' to create the default user."
      )
    end
  end

  rescue_from DefaultUserMissingError do |error|
    render json: { error: error.message }, status: :internal_server_error
  end

  private

  def force_user_reload?
    params.key? :uu
  end

  def current_user
    if session[:user_id]
      user = User.find_by(id: session[:user_id])
      return user if user
    end

    # TODO: Remove this fallback after all users have Discord accounts
    # See issue #226
    Rails.logger.warn("DEPRECATION WARNING: Using seeded default user. This fallback will be removed after migration to Discord OAuth is complete.")
    User.find_by(email: User::DEFAULT_EMAIL) || raise(DefaultUserMissingError)
  end

  def authenticate_api_user
    return render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
  end
end
