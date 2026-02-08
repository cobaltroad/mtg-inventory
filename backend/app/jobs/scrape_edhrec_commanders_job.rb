class ScrapeEdhrecCommandersJob < ApplicationJob
  include StructuredLogging

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
    # Create execution record
    @execution = ScraperExecution.create!(started_at: Time.current)

    # Log structured start event
    log_event(
      level: :info,
      event: "scrape_started",
      execution_id: @execution.id
    )

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

    # Update execution record with success
    @execution.update!(
      finished_at: Time.current,
      status: :success,
      commanders_attempted: commanders.length,
      commanders_succeeded: commanders.length,
      commanders_failed: 0
    )

    log_summary(commanders, start_time)

    # Log structured completion event
    log_event(
      level: :info,
      event: "scrape_completed",
      execution_id: @execution.id,
      status: @execution.status,
      commanders_attempted: @execution.commanders_attempted,
      commanders_succeeded: @execution.commanders_succeeded,
      duration_seconds: @execution.execution_time_seconds
    )
  rescue EdhrecScraper::RateLimitError => e
    # Log rate limit warning
    retry_after = e.respond_to?(:retry_after) ? e.retry_after : nil
    log_rate_limit(service: "EDHREC", retry_after: retry_after)

    # Update execution with failure
    update_execution_failure(e)

    # Re-raise for Solid Queue to retry
    raise
  rescue StandardError => e
    # Log error with full context
    log_error(error: e)

    # Update execution with failure
    update_execution_failure(e)

    # Re-raise for Solid Queue to retry
    raise
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

        # Log structured event for each commander
        log_event(
          level: :info,
          event: "commander_processed",
          commander_name: commander.name,
          commander_id: commander.id,
          rank: commander.rank,
          edhrec_url: commander.edhrec_url
        )

        commander
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Update execution record with failure information
  # ---------------------------------------------------------------------------
  def update_execution_failure(error)
    return unless @execution

    @execution.update!(
      finished_at: Time.current,
      status: :failure,
      error_summary: "#{error.class}: #{error.message}\n#{error.backtrace&.first(3)&.join("\n")}"
    )
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
