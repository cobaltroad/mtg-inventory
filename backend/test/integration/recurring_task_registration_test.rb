# frozen_string_literal: true

require "test_helper"

# Integration test to verify that recurring jobs defined in recurring.yml
# are properly registered in SolidQueue::RecurringTask at runtime.
#
# This test addresses Issue #164: UpdateCardPricesJob not showing up in job statistics
#
# BDD Acceptance Criteria:
# 1. Recurring task registration: SolidQueue::RecurringTask table should contain
#    entries with correct schedule, class name, and queue
# 2. All configured jobs should appear in the registry
# 3. Job stats should be able to retrieve information about scheduled tasks
# 4. Diagnostic tooling should warn when configured tasks are missing
class RecurringTaskRegistrationTest < ActiveSupport::TestCase
  # Disable parallel testing for this test class to avoid database conflicts
  # when loading recurring tasks
  parallelize(workers: 1)

  setup do
    # Ensure recurring tasks are loaded from recurring.yml
    # Solid Queue loads these at startup, but tests need explicit loading
    load_recurring_tasks_from_config
  end
  test "UpdateCardPricesJob is registered in SolidQueue::RecurringTask" do
    # GIVEN a Rails application with recurring.yml configured
    # WHEN we query SolidQueue::RecurringTask for the price update job
    task = SolidQueue::RecurringTask.find_by(key: "card_price_update")

    # THEN the task should exist in the registry
    assert_not_nil task, "card_price_update task should be registered in SolidQueue::RecurringTask"
  end

  test "UpdateCardPricesJob has correct class name in registry" do
    # GIVEN a registered recurring task
    task = SolidQueue::RecurringTask.find_by(key: "card_price_update")

    # THEN it should have the correct job class
    assert_equal "UpdateCardPricesJob", task.class_name,
      "Task should reference UpdateCardPricesJob class"
  end

  test "UpdateCardPricesJob has correct schedule in registry" do
    # GIVEN a registered recurring task
    task = SolidQueue::RecurringTask.find_by(key: "card_price_update")

    # THEN it should have the correct schedule based on environment
    if Rails.env.production?
      assert_equal "every day at 7am", task.schedule,
        "Production schedule should be daily at 7am"
    else
      assert_equal "every 2 days at 7am", task.schedule,
        "Development schedule should be every 2 days at 7am"
    end
  end

  test "UpdateCardPricesJob has correct queue assignment" do
    # GIVEN a registered recurring task
    task = SolidQueue::RecurringTask.find_by(key: "card_price_update")

    # THEN it should use the default queue
    assert_equal "default", task.queue_name,
      "Task should be assigned to default queue"
  end

  test "UpdateCardPricesJob appears in JobStats.all_recurring_tasks" do
    # GIVEN a JobStats service instance
    stats = JobStats.new

    # WHEN we retrieve all recurring tasks
    all_tasks = stats.all_recurring_tasks

    # THEN UpdateCardPricesJob should be in the list
    price_update_task = all_tasks.find { |t| t[:class_name] == "UpdateCardPricesJob" }

    assert_not_nil price_update_task,
      "UpdateCardPricesJob should appear in all_recurring_tasks"
    assert_equal "card_price_update", price_update_task[:key],
      "Task key should match recurring.yml configuration"
  end

  test "JobStats can calculate next execution time for UpdateCardPricesJob" do
    # GIVEN a JobStats service instance
    stats = JobStats.new

    # WHEN we calculate next execution time
    next_run = stats.next_execution_time("card_price_update")

    # THEN it should return a valid future time
    assert_not_nil next_run,
      "Next execution time should be calculable from schedule"
    assert next_run > Time.current,
      "Next execution should be in the future"
  end

  test "all configured recurring jobs are registered in SolidQueue" do
    # GIVEN recurring jobs configured in recurring.yml
    recurring_config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    env_config = recurring_config[Rails.env.to_s] || {}

    # Skip if no jobs configured for current environment
    skip "No recurring jobs configured for #{Rails.env}" if env_config.empty?

    # WHEN we check the SolidQueue registry
    registered_keys = SolidQueue::RecurringTask.pluck(:key)

    # THEN all configured jobs should be registered
    env_config.each_key do |job_key|
      assert_includes registered_keys, job_key,
        "Job '#{job_key}' from recurring.yml should be registered in SolidQueue::RecurringTask"
    end
  end

  test "JobStats detects missing recurring tasks" do
    # This test verifies BDD criterion #6: Diagnostic tooling should warn
    # when configured tasks are missing from the database registry

    # GIVEN recurring jobs configured in recurring.yml
    recurring_config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    env_config = recurring_config[Rails.env.to_s] || {}

    # Skip if no jobs configured
    skip "No recurring jobs configured for #{Rails.env}" if env_config.empty?

    # WHEN we check for missing tasks
    stats = JobStats.new
    missing_tasks = stats.missing_recurring_tasks

    # THEN no tasks should be missing
    assert_empty missing_tasks,
      "No configured tasks should be missing from registry. Missing: #{missing_tasks.join(', ')}"
  end
end
