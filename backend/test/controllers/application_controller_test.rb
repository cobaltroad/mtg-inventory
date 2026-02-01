require "test_helper"

class ApplicationControllerTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Scenario 3 -- ApplicationController#current_user returns the default user
  # ---------------------------------------------------------------------------
  test "current_user returns the seeded default User instance" do
    # Ensure the default user exists (mirrors what db:seed does)
    User.delete_all
    load Rails.root.join("db", "seeds.rb")

    # Instantiate a concrete controller that inherits from ApplicationController.
    # We use the test-only CurrentUserProbeController which exposes current_user.
    controller = CurrentUserProbeController.new

    user = controller.send(:current_user)

    assert_instance_of User, user, "current_user must return a User instance"
    assert_not_nil user.id, "current_user must return a persisted record"
  end

  test "current_user is never nil" do
    User.delete_all
    load Rails.root.join("db", "seeds.rb")

    controller = CurrentUserProbeController.new
    assert_not_nil controller.send(:current_user), "current_user must never return nil"
  end

  test "current_user returns the same record on repeated calls" do
    User.delete_all
    load Rails.root.join("db", "seeds.rb")

    controller = CurrentUserProbeController.new
    first_call  = controller.send(:current_user)
    second_call = controller.send(:current_user)

    assert_equal first_call.id, second_call.id, "current_user must return the same user every time"
  end
end
