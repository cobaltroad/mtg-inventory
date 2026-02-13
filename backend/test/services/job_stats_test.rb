# frozen_string_literal: true

require "test_helper"

class JobStatsTest < ActiveSupport::TestCase
  setup do
    # Load recurring tasks from config before each test
    load_recurring_tasks_from_config
    @stats = JobStats.new
  end

  test "missing_recurring_tasks returns empty array when all tasks are registered" do
    # GIVEN all configured tasks are registered
    # (This is set up by the recurring task loading in recurring.yml)

    # WHEN we check for missing tasks
    missing = @stats.missing_recurring_tasks

    # THEN no tasks should be missing
    assert_equal [], missing,
      "All configured tasks should be registered"
  end

  test "missing_recurring_tasks detects when configured task is not registered" do
    # GIVEN a configured task that is not in the database
    # We need to simulate this by temporarily removing a task

    # Find and remove a task
    task_to_remove = SolidQueue::RecurringTask.find_by(key: "card_price_update")
    skip "No tasks to test with" unless task_to_remove

    task_to_remove.destroy!

    # WHEN we check for missing tasks
    missing = @stats.missing_recurring_tasks

    # THEN it should detect the missing task
    assert_includes missing, "card_price_update",
      "Should detect that card_price_update task is missing from registry"
  ensure
    # Restore the task for other tests
    # Re-load from recurring.yml
    load_recurring_tasks_from_config
  end

  test "missing_recurring_tasks returns task keys, not full task objects" do
    # GIVEN a missing task (simulated by removal)
    task = SolidQueue::RecurringTask.find_by(key: "weekly_commander_scrape")
    skip "No tasks to test with" unless task

    task.destroy!

    # WHEN we check for missing tasks
    missing = @stats.missing_recurring_tasks

    # THEN it should return strings (task keys)
    assert missing.all? { |t| t.is_a?(String) },
      "missing_recurring_tasks should return an array of strings (task keys)"
  ensure
    load_recurring_tasks_from_config
  end

end
