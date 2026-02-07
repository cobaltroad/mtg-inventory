# frozen_string_literal: true

namespace :jobs do
  desc "Run all scheduled jobs manually (for testing/maintenance)"
  task all: :environment do
    puts "Running all scheduled jobs..."
    Rake::Task["jobs:scrape_commanders"].invoke
    Rake::Task["jobs:update_prices"].invoke
    Rake::Task["jobs:clear_finished"].invoke
    puts "\nAll jobs completed!"
  end

  namespace :scrape do
    desc "Scrape EDHREC top commanders and their decklists"
    task commanders: :environment do
      puts "=" * 80
      puts "SCRAPING EDHREC COMMANDERS"
      puts "=" * 80
      puts "Schedule: Every Saturday at 8am (development) / Sunday at 8am (production)"
      puts "Started at: #{Time.current}"
      puts "-" * 80

      # Configure logger to also output to STDOUT for interactive progress
      console_logger = Logger.new($stdout)
      console_logger.level = Logger::INFO
      console_logger.formatter = proc do |severity, datetime, progname, msg|
        # Clean output without timestamp prefix for better readability
        "#{msg}\n"
      end

      # Broadcast logs to both file and console
      Rails.logger.broadcast_to(console_logger)

      begin
        ScrapeEdhrecCommandersJob.perform_now
      ensure
        # Stop broadcasting to console
        Rails.logger.stop_broadcasting_to(console_logger)
      end

      puts "-" * 80
      puts "Completed at: #{Time.current}"
      puts "=" * 80
    end
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
    task :update_card, [:card_id] => :environment do |_t, args|
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
    task :image, [:collection_item_id, :image_url] => :environment do |_t, args|
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

    desc "Show job queue statistics"
    task stats: :environment do
      puts "=" * 80
      puts "SOLID QUEUE JOB STATISTICS"
      puts "=" * 80
      puts "Pending jobs:    #{SolidQueue::Job.pending.count}"
      puts "Running jobs:    #{SolidQueue::Job.running.count}"
      puts "Finished jobs:   #{SolidQueue::Job.finished.count}"
      puts "Failed jobs:     #{SolidQueue::Job.failed.count}"
      puts "-" * 80

      # Show recurring tasks
      puts "\nRECURRING TASKS:"
      SolidQueue::RecurringTask.all.each do |task|
        puts "  #{task.key.ljust(30)} - #{task.schedule}"
      end
      puts "=" * 80
    end
  end

  # Convenience aliases
  task scrape_commanders: "scrape:commanders"
  task update_prices: "prices:update"
  task clear_finished: "maintenance:clear_finished"
  task stats: "maintenance:stats"
end
