class ApplicationController < ActionController::API
  # ---------------------------------------------------------------------------
  # Custom error raised when the default user is not found in the database.
  # This provides a more helpful error message than ActiveRecord::RecordNotFound.
  # ---------------------------------------------------------------------------
  class DefaultUserMissingError < StandardError
    def initialize
      super(
        "The default user (#{User::DEFAULT_EMAIL}) was not found in the database. " \
        "Please run 'rails db:seed' to create the default user."
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Global error handler for DefaultUserMissingError.
  # Returns a 500 status with a helpful error message.
  # ---------------------------------------------------------------------------
  rescue_from DefaultUserMissingError do |error|
    render json: { error: error.message }, status: :internal_server_error
  end

  # ---------------------------------------------------------------------------
  # MVP current_user resolver.
  #
  # At MVP there is no authentication flow.  This helper returns the single
  # seeded default user unconditionally.  When OAuth or session-based auth is
  # added later, replace this method body with the real resolver — the method
  # signature (no arguments, returns a User instance) stays the same.
  # ---------------------------------------------------------------------------
  private

  def current_user
    @current_user ||= begin
      User.find_by(email: User::DEFAULT_EMAIL) || raise(DefaultUserMissingError)
    end
  end
end
