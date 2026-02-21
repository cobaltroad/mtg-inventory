require "test_helper"

class OauthProviderTest < ActiveSupport::TestCase
  test "is valid with provider, uid, and user" do
    user = User.create!(email: "test@example.com", name: "Test User")
    oauth_provider = OauthProvider.new(provider: "discord", uid: "123456", user: user)
    assert oauth_provider.valid?, oauth_provider.errors.full_messages.inspect
  end

  test "is invalid without provider" do
    user = User.create!(email: "test2@example.com", name: "Test User 2")
    oauth_provider = OauthProvider.new(provider: "", uid: "123456", user: user)
    assert oauth_provider.invalid?
    assert_includes oauth_provider.errors[:provider], "can't be blank"
  end

  test "is invalid without uid" do
    user = User.create!(email: "test3@example.com", name: "Test User 3")
    oauth_provider = OauthProvider.new(provider: "discord", uid: "", user: user)
    assert oauth_provider.invalid?
    assert_includes oauth_provider.errors[:uid], "can't be blank"
  end

  test "is invalid with duplicate provider and uid combination" do
    user = User.create!(email: "test4@example.com", name: "Test User 4")
    OauthProvider.create!(provider: "discord", uid: "123456", user: user)
    
    other_user = User.create!(email: "test5@example.com", name: "Test User 5")
    duplicate = OauthProvider.new(provider: "discord", uid: "123456", user: other_user)
    assert duplicate.invalid?
    assert_includes duplicate.errors[:provider], "has already been taken"
  end

  test "allows same provider with different uid" do
    user = User.create!(email: "test6@example.com", name: "Test User 6")
    OauthProvider.create!(provider: "discord", uid: "111111", user: user)
    
    oauth_provider = OauthProvider.new(provider: "discord", uid: "222222", user: user)
    assert oauth_provider.valid?, oauth_provider.errors.full_messages.inspect
  end

  test "allows same uid with different provider" do
    user = User.create!(email: "test7@example.com", name: "Test User 7")
    OauthProvider.create!(provider: "discord", uid: "123456", user: user)
    
    oauth_provider = OauthProvider.new(provider: "google", uid: "123456", user: user)
    assert oauth_provider.valid?, oauth_provider.errors.full_messages.inspect
  end

  test "belongs to user" do
    user = User.create!(email: "test8@example.com", name: "Test User 8")
    oauth_provider = OauthProvider.create!(provider: "discord", uid: "123456", user: user)
    assert_equal user, oauth_provider.user
  end
end
