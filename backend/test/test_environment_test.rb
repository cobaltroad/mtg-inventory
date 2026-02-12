require "test_helper"

class TestEnvironmentTest < ActiveSupport::TestCase
  test "Rails environment must be test when running tests" do
    assert_equal "test", Rails.env,
      "CRITICAL: Tests are running in #{Rails.env} environment instead of test environment! " \
      "This can corrupt your development database. Check RAILS_ENV settings in docker-compose.yml and test_helper.rb"
  end

  test "test database name must be backend_test" do
    db_config = ActiveRecord::Base.connection_db_config
    assert_equal "backend_test", db_config.database,
      "CRITICAL: Tests are using #{db_config.database} database instead of backend_test! " \
      "This can corrupt your development database."
  end

  test "test environment is isolated from development environment" do
    # Verify we're not using development database
    refute_equal "backend_development", ActiveRecord::Base.connection_db_config.database,
      "CRITICAL: Tests are accessing the development database! This violates test isolation."
  end
end
