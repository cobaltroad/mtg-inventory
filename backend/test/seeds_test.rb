require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Scenario 1 -- default user is created by seed
  # ---------------------------------------------------------------------------
  test "seed creates exactly one user with non-null email and name" do
    # Wipe any users that test fixtures or other tests may have inserted
    CollectionItem.delete_all
    User.delete_all

    # Execute the seed file
    load Rails.root.join("db", "seeds.rb")

    assert_equal 1, User.count, "Expected exactly one user after seeding"

    user = User.first
    assert_not_nil user.email, "Default user email must not be nil"
    assert_not_empty user.email, "Default user email must not be blank"
    assert_not_nil user.name, "Default user name must not be nil"
    assert_not_empty user.name, "Default user name must not be blank"
  end

  # ---------------------------------------------------------------------------
  # Scenario 2 -- seed is idempotent
  # ---------------------------------------------------------------------------
  test "running seed twice does not create a duplicate user" do
    CollectionItem.delete_all
    User.delete_all

    load Rails.root.join("db", "seeds.rb")
    assert_equal 1, User.count

    # Run seed again
    load Rails.root.join("db", "seeds.rb")
    assert_equal 1, User.count, "Seed must be idempotent; running it again must not duplicate the user"
  end
end
