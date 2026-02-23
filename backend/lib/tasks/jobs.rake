# frozen_string_literal: true

namespace :jobs do
  desc "Run all scheduled jobs manually (for testing/maintenance)"
  task all: :environment do
    puts "Running all scheduled jobs..."
    Rake::Task["jobs:update_prices"].invoke
    Rake::Task["jobs:clear_finished"].invoke
    puts "\nAll jobs completed!"
  end

  namespace :prices do
    desc "Update card prices for all cards in collections"
    task update: :environment do
      puts "=" * 80
      puts "UPDATING CARD PRICES"
      puts "=" * 80
      puts "Schedule: Every day at 7am (production only)"
      puts "Started at: #{Time.current}"
      puts "-" * 80

      # Check for duplicate execution
      if UpdateCardPricesJob.already_running?
        info = UpdateCardPricesJob.running_job_info
        puts "\n⚠️  SKIPPING: UpdateCardPricesJob is already running"
        puts "   Job ID: #{info[:id]}"
        puts "   Started: #{info[:created_at]}"
        puts "   Queue: #{info[:queue_name]}"
        puts "\nPlease wait for the current job to complete before running again."
        puts "=" * 80
        exit 0
      end

      # Configure logger to also output to STDOUT for interactive progress
      console_logger = Logger.new($stdout)
      console_logger.level = Logger::INFO
      console_logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}\n"
      end

      # Broadcast logs to both file and console
      Rails.logger.broadcast_to(console_logger)

      begin
        UpdateCardPricesJob.perform_now
      ensure
        # Stop broadcasting to console
        Rails.logger.stop_broadcasting_to(console_logger)
      end

      puts "-" * 80
      puts "Completed at: #{Time.current}"
      puts "=" * 80
    end

    desc "Update price for a single card by Scryfall ID"
    task :update_card, [ :card_id ] => :environment do |_t, args|
      if args[:card_id].blank?
        puts "ERROR: card_id is required"
        puts "Usage: rails jobs:prices:update_card[SCRYFALL_CARD_ID]"
        exit 1
      end

      puts "=" * 80
      puts "UPDATING SINGLE CARD PRICE"
      puts "=" * 80
      puts "Card ID: #{args[:card_id]}"
      puts "Started at: #{Time.current}"
      puts "-" * 80

      # Configure logger to also output to STDOUT
      console_logger = Logger.new($stdout)
      console_logger.level = Logger::INFO
      console_logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}\n"
      end

      Rails.logger.broadcast_to(console_logger)

      begin
        UpdateCardPricesJob.perform_now(args[:card_id])
      ensure
        Rails.logger.stop_broadcasting_to(console_logger)
      end

      puts "-" * 80
      puts "Completed at: #{Time.current}"
      puts "=" * 80
    end
  end

  namespace :cache do
    desc "Cache card image for a collection item"
    task :image, [ :collection_item_id, :image_url ] => :environment do |_t, args|
      if args[:collection_item_id].blank? || args[:image_url].blank?
        puts "ERROR: collection_item_id and image_url are required"
        puts "Usage: rails jobs:cache:image[ITEM_ID,IMAGE_URL]"
        exit 1
      end

      puts "=" * 80
      puts "CACHING CARD IMAGE"
      puts "=" * 80
      puts "Collection Item ID: #{args[:collection_item_id]}"
      puts "Image URL: #{args[:image_url]}"
      puts "Note: This job is normally triggered automatically when adding cards"
      puts "Started at: #{Time.current}"
      puts "-" * 80

      CacheCardImageJob.perform_now(args[:collection_item_id], args[:image_url])

      puts "-" * 80
      puts "Completed at: #{Time.current}"
      puts "=" * 80
    end
  end

  namespace :maintenance do
    desc "Clear finished Solid Queue jobs (older than 1 day)"
    task clear_finished: :environment do
      puts "=" * 80
      puts "CLEARING FINISHED JOBS"
      puts "=" * 80
      puts "Schedule: Every hour at minute 12 (production only)"
      puts "Started at: #{Time.current}"
      puts "-" * 80

      before_count = SolidQueue::Job.finished.count
      SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)
      after_count = SolidQueue::Job.finished.count
      deleted_count = before_count - after_count

      puts "Deleted #{deleted_count} finished jobs"
      puts "-" * 80
      puts "Completed at: #{Time.current}"
      puts "=" * 80
    end

    namespace :cleanup do
      desc "Remove test/debug/mock card data from database"
      task test_data: :environment do
        puts "=" * 80
        puts "CLEANING UP TEST DATA"
        puts "=" * 80
        puts "Started at: #{Time.current}"
        puts "-" * 80

        # Define test-related keywords to search for
        test_keywords = %w[test debug mock fixture sample dummy]

        # Build SQL pattern for case-insensitive matching
        # PostgreSQL uses ILIKE for case-insensitive pattern matching
        conditions = test_keywords.map { |keyword| "card_id ILIKE '%#{keyword}%'" }.join(" OR ")

        # Count records before cleanup
        items_before = CollectionItem.where(conditions).count
        prices_before = CardPrice.where(conditions).count

        puts "Found #{items_before} collection items with test card IDs"
        puts "Found #{prices_before} card prices with test card IDs"
        puts ""

        if items_before.zero? && prices_before.zero?
          puts "No test data found. Database is clean!"
        else
          puts "Removing test data..."

          # Delete collection items with test card IDs
          if items_before > 0
            deleted_items = CollectionItem.where(conditions).delete_all
            puts "Deleted #{deleted_items} collection items"
          end

          # Delete card prices with test card IDs
          if prices_before > 0
            deleted_prices = CardPrice.where(conditions).delete_all
            puts "Deleted #{deleted_prices} card prices"
          end

          puts ""
          puts "Cleanup completed successfully!"
        end

        puts "-" * 80
        puts "Completed at: #{Time.current}"
        puts "=" * 80
      end
    end

    desc "Show job queue statistics"
    task stats: :environment do
      stats_service = JobStats.new

      puts "=" * 80
      puts "SOLID QUEUE JOB STATISTICS"
      puts "=" * 80
      puts "Pending jobs:    #{SolidQueue::ReadyExecution.count}"
      puts "Running jobs:    #{SolidQueue::ClaimedExecution.count}"
      puts "Finished jobs:   #{SolidQueue::Job.where.not(finished_at: nil).count}"
      puts "Failed jobs:     #{SolidQueue::FailedExecution.count}"
      puts "-" * 80

      # Check for missing recurring tasks and warn
      missing_tasks = stats_service.missing_recurring_tasks
      if missing_tasks.any?
        puts "\n⚠️  WARNING: Missing Recurring Tasks"
        puts "-" * 80
        puts "The following tasks are configured in recurring.yml but not registered"
        puts "in the SolidQueue::RecurringTask table. This may indicate:"
        puts "  - Solid Queue process needs to be restarted"
        puts "  - Configuration file syntax errors"
        puts "  - Database initialization issues"
        puts ""
        puts "Missing tasks:"
        missing_tasks.each do |task_key|
          puts "  - #{task_key}"
        end
        puts "-" * 80
        puts ""
      end

      # Show recurring tasks with enhanced information
      puts "\nRECURRING TASKS:"
      puts "-" * 80

      stats_service.all_recurring_tasks.each do |task|
        puts "\n#{task[:key]}"
        puts "  Schedule:     #{task[:schedule]}"
        puts "  Job Class:    #{task[:class_name]}"
        puts "  Queue:        #{task[:queue_name]}"

        if task[:next_run]
          puts "  Next Run:     #{task[:next_run].strftime('%Y-%m-%d %H:%M %Z')} (#{stats_service.format_relative_time(task[:next_run])})"
        else
          puts "  Next Run:     Unable to calculate"
        end

        # Get job class to show execution stats
        begin
          job_class = task[:class_name].constantize
          last_exec = stats_service.last_execution_status(job_class)

          if last_exec
            puts "  Last Run:     #{last_exec[:started_at]&.strftime('%Y-%m-%d %H:%M %Z')} - #{last_exec[:status].to_s.upcase}"
            puts "  Duration:     #{stats_service.format_duration(last_exec[:duration_seconds])}"
            if last_exec[:error_summary].present?
              puts "  Error:        #{last_exec[:error_summary]}"
            end
          else
            puts "  Last Run:     No executions found"
          end

          # Show execution counts
          count_7d = stats_service.execution_count(job_class, days: 7)
          count_30d = stats_service.execution_count(job_class, days: 30)
          puts "  Executions:   #{count_7d} (7d) / #{count_30d} (30d)"

          # Show average duration
          avg_duration = stats_service.average_execution_duration(job_class, days: 30)
          if avg_duration
            puts "  Avg Duration: #{stats_service.format_duration(avg_duration)} (30d average)"
          end
        rescue NameError
          # Job class not found - skip stats
        end
      end

      # Show scheduled one-time jobs if any exist
      scheduled_jobs = stats_service.scheduled_one_time_jobs
      if scheduled_jobs.any?
        puts "\n" + "-" * 80
        puts "\nSCHEDULED JOBS (One-Time):"
        puts "-" * 80

        # Group jobs by class name
        jobs_by_class = scheduled_jobs.group_by { |job| job[:class_name] }

        jobs_by_class.each do |class_name, jobs|
          puts "\n#{class_name} (#{jobs.count} scheduled):"

          # Show up to 3 jobs per class
          jobs.take(3).each do |job|
            relative_time = stats_service.format_relative_time(job[:scheduled_at])
            puts "  #{job[:scheduled_at].strftime('%Y-%m-%d %H:%M:%S %Z')} (#{relative_time}) - Queue: #{job[:queue_name]}"
          end

          # Show count of remaining jobs if more than 3
          if jobs.count > 3
            puts "  ... and #{jobs.count - 3} more"
          end
        end
      end

      puts "\n" + "=" * 80
    end

    desc "Show recent job failures with error details"
    task failures: :environment do
      stats_service = JobStats.new
      failures = stats_service.recent_failures(limit: 20, days: 7)

      puts "=" * 80
      puts "RECENT JOB FAILURES (LAST 7 DAYS)"
      puts "=" * 80

      if failures.empty?
        puts "\n✓ No failed jobs found in the last 7 days!"
        puts "\n" + "=" * 80
        next
      end

      puts "Found #{failures.count} failed #{'execution'.pluralize(failures.count)}\n"
      puts "-" * 80

      failures.each_with_index do |failure, index|
        puts "\n#{index + 1}. #{failure[:job_class]}"
        puts "   Execution ID: #{failure[:execution_id]}"
        puts "   Started:      #{failure[:started_at].strftime('%Y-%m-%d %H:%M:%S %Z')}"
        puts "   Duration:     #{stats_service.format_duration(failure[:duration_seconds])}"
        puts "   Mode:         #{failure[:mode]}" if failure[:mode]

        # Show relevant metrics based on job type
        if failure[:cards_attempted]
          puts "   Cards:        #{failure[:cards_succeeded] || 0} succeeded / #{failure[:cards_attempted] || 0} attempted"
        end

        # Show error with word wrapping for readability
        if failure[:error_summary].present?
          puts "   Error:"
          # Wrap error message at 70 characters with proper indentation
          error_lines = failure[:error_summary].scan(/.{1,70}(?:\s+|$)/)
          error_lines.each do |line|
            puts "     #{line.strip}"
          end
        end
      end

      puts "\n" + "=" * 80
      puts "TIP: Use 'docker compose exec backend bin/rails console' to query"
      puts "     PriceUpdateExecution, ScraperExecution, or ImageCacheExecution"
      puts "     for more detailed information about specific failures."
      puts "=" * 80
    end

    desc "Show stuck jobs (jobs with finished_at = NULL that are blocking new executions)"
    task show_stuck: :environment do
      puts "=" * 80
      puts "STUCK JOBS ANALYSIS"
      puts "=" * 80

      # Find all jobs with finished_at = nil
      stuck_jobs = SolidQueue::Job.where(finished_at: nil)

      if stuck_jobs.empty?
        puts "\n✓ No stuck jobs found"
        puts "\n" + "=" * 80
        next
      end

      puts "Found #{stuck_jobs.count} job(s) with finished_at = NULL"
      puts "-" * 80

      stuck_jobs.each do |job|
        puts "\nJob ID:       #{job.id}"
        puts "Class:        #{job.class_name}"
        puts "Queue:        #{job.queue_name}"
        puts "Created:      #{job.created_at}"
        puts "Finished:     #{job.finished_at || 'NULL (STUCK)'}"
        puts "Active Job ID: #{job.active_job_id}"

        # Check if it's in different execution states
        if SolidQueue::ClaimedExecution.exists?(job_id: job.id)
          puts "State:        CLAIMED (currently running)"
        elsif SolidQueue::FailedExecution.exists?(job_id: job.id)
          failed = SolidQueue::FailedExecution.find_by(job_id: job.id)
          puts "State:        FAILED"
          puts "Error:        #{failed.error}"
        elsif SolidQueue::ReadyExecution.exists?(job_id: job.id)
          puts "State:        READY (waiting to run)"
        else
          puts "State:        UNKNOWN (orphaned?)"
        end
      end

      puts "\n" + "=" * 80
      puts "TIP: Use 'rails jobs:maintenance:clear_stuck' to remove these jobs"
      puts "=" * 80
    end

    desc "Clear stuck jobs (CAUTION: removes jobs with finished_at = NULL)"
    task clear_stuck: :environment do
      puts "=" * 80
      puts "CLEARING STUCK JOBS"
      puts "=" * 80

      # Find all jobs with finished_at = nil
      stuck_jobs = SolidQueue::Job.where(finished_at: nil)

      if stuck_jobs.empty?
        puts "\n✓ No stuck jobs to clear"
        puts "\n" + "=" * 80
        next
      end

      puts "Found #{stuck_jobs.count} stuck job(s)"
      puts "-" * 80

      stuck_jobs.each do |job|
        puts "\nClearing:"
        puts "  Job ID: #{job.id}"
        puts "  Class:  #{job.class_name}"
        puts "  Created: #{job.created_at}"

        # Remove from failed executions if present
        if SolidQueue::FailedExecution.exists?(job_id: job.id)
          SolidQueue::FailedExecution.where(job_id: job.id).delete_all
          puts "  Removed from FailedExecution table"
        end

        # Remove from claimed executions if present
        if SolidQueue::ClaimedExecution.exists?(job_id: job.id)
          SolidQueue::ClaimedExecution.where(job_id: job.id).delete_all
          puts "  Removed from ClaimedExecution table"
        end

        # Remove from ready executions if present
        if SolidQueue::ReadyExecution.exists?(job_id: job.id)
          SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
          puts "  Removed from ReadyExecution table"
        end

        # Finally delete the job record itself
        job.destroy
        puts "  ✓ Job record deleted"
      end

      puts "\n" + "-" * 80
      puts "✓ Cleared #{stuck_jobs.count} stuck job(s)"
      puts "=" * 80
    end

    desc "Clean up old rotated log files"
    task clean_logs: :environment do
      puts "=" * 80
      puts "CLEANING OLD LOG FILES"
      puts "=" * 80

      log_dir = Rails.root.join("log")
      old_logs = Dir.glob(log_dir.join("*.log.*"))

      if old_logs.empty?
        puts "\n✓ No old log files to clean"
        puts "\n" + "=" * 80
        next
      end

      total_size = old_logs.sum { |f| File.size(f) }
      puts "Found #{old_logs.count} old log #{'file'.pluralize(old_logs.count)}"
      puts "Total size: #{'%.2f' % (total_size / 1024.0 / 1024.0)} MB"
      puts "-" * 80

      old_logs.each do |log_file|
        size_mb = File.size(log_file) / 1024.0 / 1024.0
        basename = File.basename(log_file)
        puts "Removing #{basename} (#{'%.2f' % size_mb} MB)"
        File.delete(log_file)
      end

      puts "-" * 80
      puts "✓ Cleaned #{old_logs.count} old log #{'file'.pluralize(old_logs.count)}"
      puts "=" * 80
    end
  end

  # Convenience aliases
  task update_prices: "prices:update"
  task clear_finished: "maintenance:clear_finished"
  task stats: "maintenance:stats"
  task failures: "maintenance:failures"
  task clean_logs: "maintenance:clean_logs"
  task show_stuck: "maintenance:show_stuck"
  task clear_stuck: "maintenance:clear_stuck"
end
