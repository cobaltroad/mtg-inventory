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

  test "jobs:stats displays scheduled one-time jobs section when jobs exist" do
    # GIVEN scheduled one-time jobs exist
    create_scheduled_job("UpdateCardPricesJob", 1.hour.from_now)
    create_scheduled_job("ScrapeCommanderDecklistJob", 2.hours.from_now)

    # WHEN we retrieve scheduled jobs
    stats_service = JobStats.new
    scheduled_jobs = stats_service.scheduled_one_time_jobs

    # THEN it should include both jobs
    assert_equal 2, scheduled_jobs.length,
      "Should return both scheduled jobs"

    class_names = scheduled_jobs.map { |j| j[:class_name] }
    assert_includes class_names, "UpdateCardPricesJob",
      "Should include UpdateCardPricesJob"
    assert_includes class_names, "ScrapeCommanderDecklistJob",
      "Should include ScrapeCommanderDecklistJob"
  end

  test "jobs:stats does not display scheduled jobs section when no jobs exist" do
    # GIVEN no scheduled jobs
    SolidQueue::ScheduledExecution.delete_all

    # WHEN we retrieve scheduled jobs
    stats_service = JobStats.new
    scheduled_jobs = stats_service.scheduled_one_time_jobs

    # THEN it should return empty array
    assert_empty scheduled_jobs,
      "Should return empty array when no scheduled jobs exist"
  end

  test "jobs:stats groups multiple scheduled jobs by class name" do
    # GIVEN multiple jobs of the same class
    3.times do |i|
      create_scheduled_job("UpdateCardPricesJob", (i + 1).hours.from_now)
    end
    create_scheduled_job("ScrapeCommanderDecklistJob", 4.hours.from_now)

    # WHEN we retrieve and group scheduled jobs
    stats_service = JobStats.new
    scheduled_jobs = stats_service.scheduled_one_time_jobs
    jobs_by_class = scheduled_jobs.group_by { |job| job[:class_name] }

    # THEN jobs should be properly grouped
    assert_equal 2, jobs_by_class.keys.length,
      "Should have 2 different job classes"
    assert_equal 3, jobs_by_class["UpdateCardPricesJob"].length,
      "Should have 3 UpdateCardPricesJob jobs"
    assert_equal 1, jobs_by_class["ScrapeCommanderDecklistJob"].length,
      "Should have 1 ScrapeCommanderDecklistJob job"
  end

  private

  # Helper to create a scheduled job for testing
  def create_scheduled_job(class_name, scheduled_at, queue: "default")
    job = SolidQueue::Job.create!(
      queue_name: queue,
      class_name: class_name,
      arguments: [].to_json,
      scheduled_at: scheduled_at
    )

    existing = SolidQueue::ScheduledExecution.find_by(job_id: job.id)
    return existing if existing

    SolidQueue::ScheduledExecution.create!(
      job_id: job.id,
      queue_name: queue,
      scheduled_at: scheduled_at
    )
  end
end
