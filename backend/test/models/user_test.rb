require "test_helper"

class UserTest < ActiveSupport::TestCase
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
end
