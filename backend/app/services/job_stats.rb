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
      cards_succeeded: last_execution.try(:cards_succeeded)
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
end
