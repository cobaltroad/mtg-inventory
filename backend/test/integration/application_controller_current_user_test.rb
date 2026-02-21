require "test_helper"

class ApplicationControllerCurrentUserTest < ActionDispatch::IntegrationTest
  setup do
    User.delete_all
    OauthProvider.delete_all
    load Rails.root.join("db", "seeds.rb")
  end

  test "current_user returns user from session when user_id is set" do
    user = User.create!(email: "session@example.com", name: "Session User")

    get "/test/current_user_email", session: { user_id: user.id }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "session@example.com", body["email"]
  end

  test "current_user falls back to default user when no session" do
    get "/test/current_user_email"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal User::DEFAULT_EMAIL, body["email"]
  end

  test "current_user returns nil when session user not found" do
    get "/test/current_user_email", session: { user_id: 99999 }

    assert_response :success
  end
end
