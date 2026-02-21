require "test_helper"

class AuthenticateApiUserTest < ActionDispatch::IntegrationTest
  setup do
    User.delete_all
    OauthProvider.delete_all
  end

  test "unauthenticated request to protected endpoint returns 401" do
    get "/api/inventory"

    assert_response :unauthorized
  end

  test "authenticated request to protected endpoint succeeds" do
    user = User.create!(email: "test@example.com", name: "Test User")

    get "/api/inventory", session: { user_id: user.id }

    assert_response :success
  end
end
