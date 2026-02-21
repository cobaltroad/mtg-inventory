require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.delete_all
    OauthProvider.delete_all
  end

  # ---------------------------------------------------------------------------
  # discord action
  # ---------------------------------------------------------------------------
  test "GET /api/auth/discord redirects to Discord OAuth" do
    get "/api/auth/discord"

    assert_response :redirect
    assert_includes response.location, "discord.com"
    assert_includes response.location, "oauth2/authorize"
    assert_includes response.location, "client_id"
    assert_includes response.location, "scope=identify+email"
    assert_includes response.location, "state="
  end

  test "GET /api/auth/discord with return_to preserves the return path" do
    get "/api/auth/discord", params: { return_to: "/inventory" }

    assert_response :redirect
    assert_includes response.location, "state="
  end

  test "GET /api/auth/discord sets state in session" do
    get "/api/auth/discord"

    assert_response :redirect
  end

  # ---------------------------------------------------------------------------
  # status action
  # ---------------------------------------------------------------------------
  test "GET /api/auth/status returns authenticated false when not logged in" do
    get "/api/auth/status"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal false, body["authenticated"]
    assert_nil body["user"]
  end

  test "GET /api/auth/status returns user info when authenticated" do
    user = User.create!(email: "test@example.com", name: "Test User")

    get "/api/auth/status", session: { user_id: user.id }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["authenticated"]
    assert_equal user.id, body["user"]["id"]
    assert_equal user.email, body["user"]["email"]
    assert_equal user.name, body["user"]["name"]
  end

  # ---------------------------------------------------------------------------
  # logout action
  # ---------------------------------------------------------------------------
  test "DELETE /api/auth/logout clears session and redirects" do
    user = User.create!(email: "test@example.com", name: "Test User")

    delete "/api/auth/logout", session: { user_id: user.id }

    assert_response :redirect
  end
end
