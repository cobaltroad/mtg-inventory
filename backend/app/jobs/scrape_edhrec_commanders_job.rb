class ScrapeEdhrecCommandersJob < ApplicationJob
  queue_as :default

  # Hourly spacing between individual commander decklist scrapes
  DECKLIST_SCRAPE_INTERVAL_HOURS = 1

  FATAL_ERROR_TYPES = [
    ActiveRecord::ConnectionNotEstablished,
    ActiveRecord::StatementInvalid,
    PG::Error,
    EdhrecScraper::RateLimitError  # Stop job if rate limited - entire job should be retried later
  ].freeze

  # ---------------------------------------------------------------------------
  # Fetches top commanders from EDHREC and schedules individual decklist scrapes
  #
  # This job performs "discovery only" - it fetches the list of top commanders
  # and creates/updates their database records WITHOUT fetching decklists.
  #
  # Individual decklist scraping is scheduled separately via ScrapeCommanderDecklistJob,
  # with jobs spaced 1 hour apart to distribute load over ~20 hours.
  # ---------------------------------------------------------------------------
  def perform
    log_job_start
    start_time = Time.current

    # Fetch commanders list (discovery only - no decklists)
    Rails.logger.info("ScrapeEdhrecCommandersJob: Fetching top commanders from EDHREC...")
    commanders_data = EdhrecScraper.fetch_top_commanders
    total_commanders = commanders_data.length
    Rails.logger.info("ScrapeEdhrecCommandersJob: Found #{total_commanders} commanders")

    # Create/update commander records without fetching decklists
    commanders = create_or_update_commanders(commanders_data)

    # Schedule individual decklist scraping jobs with hourly spacing
    schedule_decklist_scraping_jobs(commanders)

    log_summary(commanders, start_time)
  end

  private

  # ---------------------------------------------------------------------------
  # Creates or updates commander records from EDHREC data
  # ---------------------------------------------------------------------------
  def create_or_update_commanders(commanders_data)
    commanders_data.map do |commander_data|
      Commander.transaction do
        commander = Commander.find_or_initialize_by(name: commander_data[:name])
        commander.assign_attributes(
          rank: commander_data[:rank],
          edhrec_url: commander_data[:url]
          # Note: last_scraped_at is NOT updated here - only when decklist is scraped
        )
        commander.save!
        Rails.logger.info("  └─ Saved commander: #{commander.name} (Rank ##{commander.rank})")
        commander
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Schedules individual decklist scraping jobs with hourly spacing
  #
  # Jobs are scheduled at: now + 0h, now + 1h, now + 2h, ..., now + 19h
  # This distributes the load over ~20 hours to minimize peak request rates.
  # ---------------------------------------------------------------------------
  def schedule_decklist_scraping_jobs(commanders)
    Rails.logger.info("-" * 80)
    Rails.logger.info("Scheduling #{commanders.length} decklist scraping jobs...")

    commanders.each_with_index do |commander, index|
      # Calculate wait time (0, 1, 2, ... hours)
      wait_hours = index * DECKLIST_SCRAPE_INTERVAL_HOURS

      # Schedule the job
      ScrapeCommanderDecklistJob.set(wait: wait_hours.hours).perform_later(commander.id)

      Rails.logger.info(
        "  └─ Scheduled '#{commander.name}' for #{wait_hours}h from now " \
        "(#{(Time.current + wait_hours.hours).strftime('%Y-%m-%d %H:%M %Z')})"
      )
    end

    Rails.logger.info("-" * 80)
  end

  # ---------------------------------------------------------------------------
  # Log job start banner
  # ---------------------------------------------------------------------------
  def log_job_start
    Rails.logger.info("=" * 80)
    Rails.logger.info("ScrapeEdhrecCommandersJob: COMMANDER DISCOVERY")
    Rails.logger.info("Started at: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    Rails.logger.info("=" * 80)
  end

  # ---------------------------------------------------------------------------
  # Log comprehensive summary of job execution
  # ---------------------------------------------------------------------------
  def log_summary(commanders, start_time)
    execution_time = (Time.current - start_time).round(2)

    Rails.logger.info("=" * 80)
    Rails.logger.info("ScrapeEdhrecCommandersJob: DISCOVERY COMPLETED")
    Rails.logger.info("=" * 80)
    Rails.logger.info("Finished at:              #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    Rails.logger.info("Execution time:           #{execution_time}s")
    Rails.logger.info("-" * 80)
    Rails.logger.info("Commanders discovered:    #{commanders.length}")
    Rails.logger.info("Decklist jobs scheduled:  #{commanders.length}")
    Rails.logger.info("Jobs will complete over:  ~#{commanders.length * DECKLIST_SCRAPE_INTERVAL_HOURS} hours")
    Rails.logger.info("=" * 80)
  end
end
