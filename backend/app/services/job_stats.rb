# frozen_string_literal: true

require "fugit"

# Service to calculate and display statistics for scheduled background jobs.
# Provides information about next execution times, last execution status,
# average duration, and execution counts.
#
# Usage:
#   stats = JobStats.new
#   stats.next_execution_time("weekly_commander_scrape")
#   stats.last_execution_status(ScrapeEdhrecCommandersJob)
class JobStats
  # Calculate next execution time for a recurring task
  #
  # @param task_key [String] Recurring task key from recurring.yml
  # @return [Time, nil] Next execution time or nil if not found
  def next_execution_time(task_key)
    task = SolidQueue::RecurringTask.find_by(key: task_key)
    return nil unless task

    # Parse schedule using fugit - Solid Queue uses natural language format
    # Try parsing as natural language first, then as cron
    schedule = task.schedule

    # Fugit::Nat parses natural language like "every sunday at 8am"
    parsed = Fugit::Nat.parse(schedule)
    if parsed
      next_time = parsed.next_time(Time.current)
      # Convert EtOrbi::EoTime to Ruby Time using to_t
      return Time.at(next_time.to_i) if next_time
    end

    # Fallback to cron parsing
    cron = Fugit::Cron.parse(schedule)
    if cron
      next_time = cron.next_time(Time.current)
      # Convert EtOrbi::EoTime to Ruby Time using to_t
      return Time.at(next_time.to_i) if next_time
    end

    nil
  end

  # Get last execution status for a job class
  #
  # @param job_class [Class] Job class (e.g., ScrapeEdhrecCommandersJob)
  # @return [Hash, nil] Last execution details or nil if no executions
  def last_execution_status(job_class)
    execution_class = execution_class_for_job(job_class)
    return nil unless execution_class

    last_execution = execution_class.order(started_at: :desc).first
    return nil unless last_execution

    {
      status: last_execution.status.to_sym,
      started_at: last_execution.started_at,
      finished_at: last_execution.finished_at,
      duration_seconds: last_execution.execution_time_seconds,
      commanders_succeeded: last_execution.try(:commanders_succeeded),
      cards_succeeded: last_execution.try(:cards_succeeded),
      error_summary: last_execution.try(:error_summary)
    }
  end

  # Calculate average execution duration over a time period
  #
  # @param job_class [Class] Job class
  # @param days [Integer] Number of days to look back (default: 7)
  # @return [Float, nil] Average duration in seconds or nil if no executions
  def average_execution_duration(job_class, days: 7)
    execution_class = execution_class_for_job(job_class)
    return nil unless execution_class

    since = days.days.ago
    executions = execution_class
      .where("started_at >= ?", since)
      .where.not(finished_at: nil)

    return nil if executions.empty?

    total_duration = executions.sum do |execution|
      (execution.finished_at - execution.started_at)
    end

    total_duration / executions.count
  end

  # Count executions in a time period
  #
  # @param job_class [Class] Job class
  # @param days [Integer] Number of days to look back (default: 7)
  # @return [Integer] Number of executions
  def execution_count(job_class, days: 7)
    execution_class = execution_class_for_job(job_class)
    return 0 unless execution_class

    since = days.days.ago
    execution_class.where("started_at >= ?", since).count
  end

  # Get all recurring tasks with their schedules
  #
  # @return [Array<Hash>] Array of task information
  def all_recurring_tasks
    SolidQueue::RecurringTask.all.map do |task|
      {
        key: task.key,
        schedule: task.schedule,
        class_name: task.class_name,
        queue_name: task.queue_name,
        next_run: next_execution_time(task.key)
      }
    end
  end

  # Detect recurring tasks that are configured in recurring.yml but missing
  # from the SolidQueue::RecurringTask registry.
  #
  # This helps diagnose configuration issues where Solid Queue hasn't loaded
  # the recurring tasks from recurring.yml, possibly due to:
  # - Solid Queue process not restarted after configuration changes
  # - Configuration file syntax errors
  # - Database initialization issues
  #
  # @return [Array<String>] Array of task keys that are configured but not registered
  def missing_recurring_tasks
    # Load expected tasks from recurring.yml
    recurring_config_path = Rails.root.join("config/recurring.yml")
    return [] unless File.exist?(recurring_config_path)

    recurring_config = YAML.load_file(recurring_config_path)
    env_config = recurring_config[Rails.env.to_s] || {}
    configured_keys = env_config.keys

    # Get actually registered task keys
    registered_keys = SolidQueue::RecurringTask.pluck(:key)

    # Return tasks that are configured but not registered
    configured_keys - registered_keys
  end

  # Format duration in human-readable form
  #
  # @param seconds [Float, nil] Duration in seconds
  # @return [String] Formatted duration (e.g., "5m 30s")
  def format_duration(seconds)
    return "N/A" if seconds.nil?

    if seconds < 60
      "#{seconds.round}s"
    elsif seconds < 3600
      minutes = (seconds / 60).floor
      secs = (seconds % 60).round
      "#{minutes}m #{secs}s"
    else
      hours = (seconds / 3600).floor
      minutes = ((seconds % 3600) / 60).floor
      "#{hours}h #{minutes}m"
    end
  end

  # Format time relative to now (e.g., "in 2 days", "5 minutes ago")
  #
  # @param time [Time, nil] Time to format
  # @return [String] Relative time string
  def format_relative_time(time)
    return "N/A" if time.nil?

    diff = time - Time.current
    abs_diff = diff.abs

    if abs_diff < 60
      diff.positive? ? "in #{abs_diff.round}s" : "#{abs_diff.round}s ago"
    elsif abs_diff < 3600
      minutes = (abs_diff / 60).round
      diff.positive? ? "in #{minutes}m" : "#{minutes}m ago"
    elsif abs_diff < 86400
      hours = (abs_diff / 3600).round
      diff.positive? ? "in #{hours}h" : "#{hours}h ago"
    else
      days = (abs_diff / 86400).round
      diff.positive? ? "in #{days}d" : "#{days}d ago"
    end
  end

  # Get recent failed executions across all job types
  #
  # @param limit [Integer] Maximum number of failures to return (default: 10)
  # @param days [Integer] Number of days to look back (default: 7)
  # @return [Array<Hash>] Array of failed execution details
  def recent_failures(limit: 10, days: 7)
    since = days.days.ago
    failures = []

    # Collect failures from all execution tracking models
    [ ScraperExecution, PriceUpdateExecution, ImageCacheExecution ].each do |execution_class|
      failed = execution_class
        .where(status: :failure)
        .where("started_at >= ?", since)
        .order(started_at: :desc)
        .limit(limit)

      failed.each do |execution|
        failures << {
          job_class: job_class_for_execution(execution),
          execution_id: execution.id,
          started_at: execution.started_at,
          finished_at: execution.finished_at,
          duration_seconds: execution.execution_time_seconds,
          error_summary: execution.try(:error_summary),
          mode: execution.try(:mode),
          cards_attempted: execution.try(:cards_attempted),
          cards_succeeded: execution.try(:cards_succeeded),
          cards_failed: execution.try(:cards_failed),
          commanders_attempted: execution.try(:commanders_attempted),
          commanders_succeeded: execution.try(:commanders_succeeded),
          commanders_failed: execution.try(:commanders_failed)
        }
      end
    end

    # Sort by started_at descending and limit
    failures.sort_by { |f| f[:started_at] }.reverse.take(limit)
  end

  private

  # Get the execution tracking class for a job class
  #
  # @param job_class [Class] Job class
  # @return [Class, nil] Execution class or nil
  def execution_class_for_job(job_class)
    case job_class.name
    when "ScrapeEdhrecCommandersJob", "ScrapeCommanderDecklistJob"
      ScraperExecution
    when "UpdateCardPricesJob"
      PriceUpdateExecution
    when "CacheCardImageJob"
      ImageCacheExecution
    else
      nil
    end
  end

  # Get the job class name for an execution record (reverse mapping)
  #
  # @param execution [ActiveRecord::Base] Execution record
  # @return [String] Job class name
  def job_class_for_execution(execution)
    case execution.class.name
    when "ScraperExecution"
      execution.mode == "discovery" ? "ScrapeEdhrecCommandersJob" : "ScrapeCommanderDecklistJob"
    when "PriceUpdateExecution"
      "UpdateCardPricesJob"
    when "ImageCacheExecution"
      "CacheCardImageJob"
    else
      "Unknown"
    end
  end
end
