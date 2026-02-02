require "test_helper"

class CurrentUserIntegrationTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Scenario 4 -- current_user is available to all API routes without credentials
  # ---------------------------------------------------------------------------
  setup do
    CollectionItem.delete_all
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
  end

  test "GET /test/current_user_email returns the default user email with no auth" do
    get "/test/current_user_email"

    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body, "email", "Response must contain an 'email' key"
    assert_not_empty body["email"], "email must not be blank"

    # Verify it matches the seeded default user
    default_user = User.first
    assert_equal default_user.email, body["email"],
                 "The email returned must be the seeded default user's email"
  end

  test "no authentication token or cookie is required" do
    # Explicitly send request with no cookies and no Authorization header
    get "/test/current_user_email", headers: {}

    assert_response :success
    body = JSON.parse(response.body)
    assert_not_empty body["email"]
  end
end
