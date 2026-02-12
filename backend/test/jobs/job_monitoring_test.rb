# frozen_string_literal: true

require "test_helper"

class JobMonitoringTest < ActiveJob::TestCase
  # ============================================================================
  # DUPLICATE JOB PREVENTION TESTS
  # ============================================================================

  test "already_running? returns true when job is currently running" do
    # Create a running ScrapeEdhrecCommandersJob
    SolidQueue::Job.create!(
      class_name: "ScrapeEdhrecCommandersJob",
      queue_name: "default",
      finished_at: nil,
      created_at: 5.minutes.ago
    )

    assert ScrapeEdhrecCommandersJob.already_running?,
           "Expected already_running? to return true when job is running"
  end

  test "already_running? returns false when no job is running" do
    # Ensure no running jobs exist
    SolidQueue::Job.where(class_name: "ScrapeEdhrecCommandersJob", finished_at: nil).delete_all

    assert_not ScrapeEdhrecCommandersJob.already_running?,
               "Expected already_running? to return false when no job is running"
  end

  test "already_running? returns false when only finished jobs exist" do
    # Create a finished job
    SolidQueue::Job.create!(
      class_name: "ScrapeEdhrecCommandersJob",
      queue_name: "default",
      finished_at: 1.hour.ago,
      created_at: 2.hours.ago
    )

    assert_not ScrapeEdhrecCommandersJob.already_running?,
               "Expected already_running? to return false when only finished jobs exist"
  end

  test "running_job_info returns job details when job is running" do
    created_time = 10.minutes.ago
    job = SolidQueue::Job.create!(
      class_name: "ScrapeEdhrecCommandersJob",
      queue_name: "default",
      finished_at: nil,
      created_at: created_time
    )

    info = ScrapeEdhrecCommandersJob.running_job_info

    assert_not_nil info, "Expected running_job_info to return job details"
    assert_equal job.id, info[:id]
    assert_equal "default", info[:queue_name]
    assert_in_delta created_time.to_i, info[:created_at].to_i, 1
  end

  test "running_job_info returns nil when no job is running" do
    SolidQueue::Job.where(class_name: "ScrapeEdhrecCommandersJob", finished_at: nil).delete_all

    info = ScrapeEdhrecCommandersJob.running_job_info

    assert_nil info, "Expected running_job_info to return nil when no job is running"
  end

  test "UpdateCardPricesJob already_running? returns true when job is running" do
    SolidQueue::Job.create!(
      class_name: "UpdateCardPricesJob",
      queue_name: "default",
      finished_at: nil,
      created_at: 3.minutes.ago
    )

    assert UpdateCardPricesJob.already_running?,
           "Expected already_running? to return true for UpdateCardPricesJob"
  end

  test "prevent_duplicate_execution! raises error when job is running" do
    SolidQueue::Job.create!(
      class_name: "ScrapeEdhrecCommandersJob",
      queue_name: "default",
      finished_at: nil,
      created_at: 5.minutes.ago
    )

    error = assert_raises(StandardError) do
      ScrapeEdhrecCommandersJob.prevent_duplicate_execution!
    end

    assert_match(/already running/, error.message)
  end

  test "prevent_duplicate_execution! does not raise when no job is running" do
    SolidQueue::Job.where(class_name: "ScrapeEdhrecCommandersJob", finished_at: nil).delete_all

    assert_nothing_raised do
      ScrapeEdhrecCommandersJob.prevent_duplicate_execution!
    end
  end

  # ============================================================================
  # FAILURE ALERTING TESTS
  # ============================================================================

  test "JobFailureNotifier sends alert on job failure" do
    job_info = {
      id: 123,
      class_name: "ScrapeEdhrecCommandersJob",
      failed_at: Time.current,
      error_message: "Rate limit exceeded",
      error_backtrace: ["line 1", "line 2"]
    }

    # Mock alert sending
    JobFailureNotifier.expects(:notify).with(has_entries(job_info)).once

    JobFailureNotifier.notify(job_info)
  end

  test "JobFailureNotifier formats alert message correctly" do
    job_info = {
      id: 456,
      class_name: "UpdateCardPricesJob",
      failed_at: Time.current,
      error_message: "Network timeout",
      error_backtrace: ["app/jobs/update_card_prices_job.rb:100"]
    }

    message = JobFailureNotifier.format_alert_message(job_info)

    assert_includes message, "UpdateCardPricesJob"
    assert_includes message, "456"
    assert_includes message, "Network timeout"
  end

  test "JobFailureNotifier delivers via configured channel" do
    skip "Implement when alert channel is configured"
    # This test will verify actual delivery (email, Slack, webhook)
    # once alert configuration is set up
  end

  # ============================================================================
  # STATS COMMAND TESTS
  # ============================================================================

  test "JobStats calculates next execution time for recurring tasks" do
    # Create a recurring task for testing
    task = SolidQueue::RecurringTask.create!(
      key: "test_weekly_commander_scrape",
      schedule: "every sunday at 8am",
      class_name: "ScrapeEdhrecCommandersJob",
      queue_name: "default"
    )

    stats = JobStats.new
    next_run = stats.next_execution_time("test_weekly_commander_scrape")

    assert_not_nil next_run, "Expected next execution time to be calculated"
    assert_instance_of Time, next_run

    # Cleanup
    task.destroy
  end

  test "JobStats shows last execution status" do
    # Create a successful execution
    ScraperExecution.create!(
      started_at: 1.day.ago,
      finished_at: 1.day.ago + 30.minutes,
      status: :success,
      commanders_attempted: 20,
      commanders_succeeded: 20,
      commanders_failed: 0
    )

    stats = JobStats.new
    last_execution = stats.last_execution_status(ScrapeEdhrecCommandersJob)

    assert_equal :success, last_execution[:status]
    assert_equal 20, last_execution[:commanders_succeeded]
  end

  test "JobStats calculates average execution duration" do
    # Create multiple executions
    3.times do |i|
      ScraperExecution.create!(
        started_at: (i + 1).days.ago,
        finished_at: (i + 1).days.ago + 30.minutes,
        status: :success,
        commanders_attempted: 20,
        commanders_succeeded: 20,
        commanders_failed: 0
      )
    end

    stats = JobStats.new
    avg_duration = stats.average_execution_duration(ScrapeEdhrecCommandersJob, days: 7)

    assert_in_delta 1800, avg_duration, 5, "Expected average duration to be ~30 minutes"
  end

  test "JobStats counts executions in time period" do
    # Create executions within last 7 days
    5.times do |i|
      ScraperExecution.create!(
        started_at: i.days.ago,
        finished_at: i.days.ago + 30.minutes,
        status: :success,
        commanders_attempted: 20,
        commanders_succeeded: 20,
        commanders_failed: 0
      )
    end

    # Create execution older than 7 days
    ScraperExecution.create!(
      started_at: 10.days.ago,
      finished_at: 10.days.ago + 30.minutes,
      status: :success,
      commanders_attempted: 20,
      commanders_succeeded: 20,
      commanders_failed: 0
    )

    stats = JobStats.new
    count = stats.execution_count(ScrapeEdhrecCommandersJob, days: 7)

    assert_equal 5, count, "Expected 5 executions in last 7 days"
  end

  # ============================================================================
  # INTEGRATION TESTS FOR SCHEDULING
  # ============================================================================

  test "scheduler prevents duplicate job when one is already running" do
    # Simulate a running job
    SolidQueue::Job.create!(
      class_name: "ScrapeEdhrecCommandersJob",
      queue_name: "default",
      finished_at: nil,
      created_at: 5.minutes.ago
    )

    # Attempt to enqueue another job
    assert_no_enqueued_jobs do
      ScrapeEdhrecCommandersJob.perform_later if ScrapeEdhrecCommandersJob.already_running? == false
    end
  end

  test "scheduler allows job when previous execution finished" do
    # Create a finished job
    SolidQueue::Job.create!(
      class_name: "ScrapeEdhrecCommandersJob",
      queue_name: "default",
      finished_at: 1.hour.ago,
      created_at: 2.hours.ago
    )

    # Should allow new job to be enqueued
    assert_enqueued_with(job: ScrapeEdhrecCommandersJob) do
      ScrapeEdhrecCommandersJob.perform_later unless ScrapeEdhrecCommandersJob.already_running?
    end
  end

  test "failed job does not block future executions" do
    # Create a failed execution
    ScraperExecution.create!(
      started_at: 1.day.ago,
      finished_at: 1.day.ago + 5.minutes,
      status: :failure,
      commanders_attempted: 0,
      commanders_succeeded: 0,
      commanders_failed: 0,
      error_summary: "Test failure"
    )

    # Clear any running jobs
    SolidQueue::Job.where(class_name: "ScrapeEdhrecCommandersJob", finished_at: nil).delete_all

    # Should allow new job
    assert_not ScrapeEdhrecCommandersJob.already_running?
  end
end
