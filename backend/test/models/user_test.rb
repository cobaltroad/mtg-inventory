require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "has many oauth_providers" do
    user = User.create!(email: "assoc_test@example.com", name: "Association Test")
    assert_respond_to user, :oauth_providers
    assert_equal [], user.oauth_providers
  end

  # ---------------------------------------------------------------------------
  # Scenario 5 -- presence validations
  # ---------------------------------------------------------------------------
  test "is valid with email and name present" do
    user = User.new(email: "valid@example.com", name: "Valid User")
    assert user.valid?, user.errors.full_messages.inspect
  end

  test "is invalid without an email" do
    user = User.new(email: "", name: "No Email")
    assert user.invalid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "is invalid without a name" do
    user = User.new(email: "noname@example.com", name: "")
    assert user.invalid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "is invalid when email is nil" do
    user = User.new(email: nil, name: "Nil Email")
    assert user.invalid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "is invalid when name is nil" do
    user = User.new(email: "nilname@example.com", name: nil)
    assert user.invalid?
    assert_includes user.errors[:name], "can't be blank"
  end

  # ---------------------------------------------------------------------------
  # Scenario 2 (uniqueness constraint) -- email must be unique
  # ---------------------------------------------------------------------------
  test "is invalid when another user already has that email" do
    User.create!(email: "taken@example.com", name: "First User")

    duplicate = User.new(email: "taken@example.com", name: "Second User")
    assert duplicate.invalid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "allows two users with different emails" do
    User.create!(email: "one@example.com", name: "User One")
    other = User.new(email: "two@example.com", name: "User Two")
    assert other.valid?, other.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # find_or_create_by_discord
  # ---------------------------------------------------------------------------
  test "find_or_create_by_discord creates new user and oauth_provider for new discord user" do
    auth_info = {
      "provider" => "discord",
      "uid" => "discord123",
      "info" => {
        "email" => "newdiscord@example.com",
        "name" => "New Discord User"
      }
    }

    user = User.find_or_create_by_discord(auth_info)

    assert user.persisted?
    assert_equal "newdiscord@example.com", user.email
    assert_equal "New Discord User", user.name

    oauth_provider = OauthProvider.find_by(provider: "discord", uid: "discord123")
    assert_not_nil oauth_provider
    assert_equal user, oauth_provider.user
  end

  test "find_or_create_by_discord returns existing user for known discord user" do
    existing_user = User.create!(email: "existing@example.com", name: "Existing User")
    OauthProvider.create!(provider: "discord", uid: "known123", user: existing_user)

    auth_info = {
      "provider" => "discord",
      "uid" => "known123",
      "info" => {
        "email" => "existing@example.com",
        "name" => "Existing User"
      }
    }

    user = User.find_or_create_by_discord(auth_info)

    assert_equal existing_user.id, user.id
    assert_equal 1, OauthProvider.where(uid: "known123", provider: "discord").count
  end

  test "find_or_create_by_discord links new oauth_provider to existing user by email" do
    existing_user = User.create!(email: "discord@example.com", name: "Discord User")

    auth_info = {
      "provider" => "discord",
      "uid" => "newdiscorduid",
      "info" => {
        "email" => "discord@example.com",
        "name" => "Discord User"
      }
    }

    user = User.find_or_create_by_discord(auth_info)

    assert_equal existing_user.id, user.id
    oauth_provider = OauthProvider.find_by(provider: "discord", uid: "newdiscorduid")
    assert_not_nil oauth_provider
    assert_equal existing_user, oauth_provider.user
  end
end
