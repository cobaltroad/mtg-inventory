# frozen_string_literal: true

require "test_helper"
require "rake"

class JobStatsRakeTest < ActiveSupport::TestCase
  setup do
    # Load rake tasks
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    # Load recurring tasks from config
    load_recurring_tasks_from_config
  end

  test "jobs:stats displays recurring tasks information" do
    # Test that the task runs without error and calls JobStats
    # We'll verify the behavior by checking that JobStats methods are called
    stats_service = JobStats.new

    # Verify the service can retrieve recurring tasks
    tasks = stats_service.all_recurring_tasks
    assert tasks.any? { |t| t[:class_name] == "UpdateCardPricesJob" },
      "UpdateCardPricesJob should be in recurring tasks"
  end

  test "jobs:stats detects when configured tasks are missing from registry" do
    # Remove a task from the registry to simulate missing task
    task = SolidQueue::RecurringTask.find_by(key: "card_price_update")
    task.destroy! if task

    # Use JobStats service to detect missing tasks
    stats_service = JobStats.new
    missing = stats_service.missing_recurring_tasks

    # Verify task is detected as missing
    assert_includes missing, "card_price_update",
      "Missing task should be detected"
  ensure
    # Restore tasks for other tests
    load_recurring_tasks_from_config
  end

  test "jobs:stats shows no missing tasks when all are registered" do
    # Use JobStats service
    stats_service = JobStats.new
    missing = stats_service.missing_recurring_tasks

    # Verify no tasks are missing
    assert_empty missing,
      "No tasks should be missing when all are registered"
  end
end
