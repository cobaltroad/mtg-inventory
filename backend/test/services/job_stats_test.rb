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

  # Tests for scheduled_one_time_jobs method

  test "scheduled_one_time_jobs returns empty array when no scheduled jobs exist" do
    # GIVEN no scheduled jobs
    SolidQueue::ScheduledExecution.delete_all

    # WHEN we retrieve scheduled one-time jobs
    scheduled_jobs = @stats.scheduled_one_time_jobs

    # THEN it should return an empty array
    assert_equal [], scheduled_jobs,
      "Should return empty array when no scheduled jobs exist"
  end

  test "scheduled_one_time_jobs returns scheduled jobs sorted by scheduled_at ascending" do
    # GIVEN multiple scheduled jobs with different execution times
    job1 = create_scheduled_job("UpdateCardPricesJob", 2.hours.from_now)
    job2 = create_scheduled_job("UpdateCardPricesJob", 30.minutes.from_now)
    job3 = create_scheduled_job("ScrapeCommanderDecklistJob", 1.hour.from_now)

    # WHEN we retrieve scheduled one-time jobs
    scheduled_jobs = @stats.scheduled_one_time_jobs

    # THEN they should be sorted by scheduled_at ascending
    assert_equal 3, scheduled_jobs.length,
      "Should return all scheduled jobs"

    scheduled_times = scheduled_jobs.map { |j| j[:scheduled_at] }
    assert_equal scheduled_times.sort, scheduled_times,
      "Jobs should be sorted by scheduled_at in ascending order"

    # The first job should be scheduled soonest
    assert_equal job2.scheduled_at.to_i, scheduled_jobs.first[:scheduled_at].to_i,
      "First job should be the one scheduled soonest"
  end

  test "scheduled_one_time_jobs excludes jobs scheduled in the past" do
    # GIVEN jobs scheduled in the past and future
    past_job = create_scheduled_job("UpdateCardPricesJob", 1.hour.ago)
    future_job = create_scheduled_job("UpdateCardPricesJob", 1.hour.from_now)

    # WHEN we retrieve scheduled one-time jobs
    scheduled_jobs = @stats.scheduled_one_time_jobs

    # THEN only future jobs should be returned
    assert_equal 1, scheduled_jobs.length,
      "Should only return jobs scheduled in the future"

    assert_equal future_job.scheduled_at.to_i, scheduled_jobs.first[:scheduled_at].to_i,
      "Should return the future job, not the past job"
  end

  test "scheduled_one_time_jobs groups jobs by class name correctly" do
    # GIVEN multiple jobs of different classes
    create_scheduled_job("UpdateCardPricesJob", 1.hour.from_now)
    create_scheduled_job("UpdateCardPricesJob", 2.hours.from_now)
    create_scheduled_job("ScrapeCommanderDecklistJob", 3.hours.from_now)

    # WHEN we retrieve scheduled one-time jobs
    scheduled_jobs = @stats.scheduled_one_time_jobs

    # THEN jobs should be grouped by class
    assert_equal 3, scheduled_jobs.length,
      "Should return all scheduled jobs"

    class_names = scheduled_jobs.map { |j| j[:class_name] }
    assert_includes class_names, "UpdateCardPricesJob",
      "Should include UpdateCardPricesJob"
    assert_includes class_names, "ScrapeCommanderDecklistJob",
      "Should include ScrapeCommanderDecklistJob"

    # Count jobs per class
    update_jobs = scheduled_jobs.count { |j| j[:class_name] == "UpdateCardPricesJob" }
    scrape_jobs = scheduled_jobs.count { |j| j[:class_name] == "ScrapeCommanderDecklistJob" }

    assert_equal 2, update_jobs,
      "Should have 2 UpdateCardPricesJob jobs"
    assert_equal 1, scrape_jobs,
      "Should have 1 ScrapeCommanderDecklistJob job"
  end

  test "scheduled_one_time_jobs returns job details including queue and scheduled_at" do
    # GIVEN a scheduled job
    job = create_scheduled_job("UpdateCardPricesJob", 1.hour.from_now, queue: "default")

    # WHEN we retrieve scheduled one-time jobs
    scheduled_jobs = @stats.scheduled_one_time_jobs

    # THEN it should include all expected details
    assert_equal 1, scheduled_jobs.length,
      "Should return the scheduled job"

    job_info = scheduled_jobs.first
    assert_equal "UpdateCardPricesJob", job_info[:class_name],
      "Should include class name"
    assert_equal "default", job_info[:queue_name],
      "Should include queue name"
    assert_not_nil job_info[:scheduled_at],
      "Should include scheduled_at timestamp"
    assert job_info[:scheduled_at].is_a?(Time) || job_info[:scheduled_at].is_a?(ActiveSupport::TimeWithZone),
      "scheduled_at should be a Time or TimeWithZone object"
  end

  private

  # Helper to create a scheduled job for testing
  #
  # @param class_name [String] Job class name
  # @param scheduled_at [Time] When the job should run
  # @param queue [String] Queue name (default: "default")
  # @return [SolidQueue::ScheduledExecution] The created scheduled execution
  def create_scheduled_job(class_name, scheduled_at, queue: "default")
    # Create the job record first
    job = SolidQueue::Job.create!(
      queue_name: queue,
      class_name: class_name,
      arguments: [].to_json,
      scheduled_at: scheduled_at
    )

    # Check if scheduled execution already exists (shouldn't happen in tests, but be safe)
    existing = SolidQueue::ScheduledExecution.find_by(job_id: job.id)
    return existing if existing

    # Create the scheduled execution record
    SolidQueue::ScheduledExecution.create!(
      job_id: job.id,
      queue_name: queue,
      scheduled_at: scheduled_at
    )
  end

end
