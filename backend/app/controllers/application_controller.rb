class ApplicationController < ActionController::API
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
    @current_user ||= User.find_by!(email: User::DEFAULT_EMAIL)
  end
end
