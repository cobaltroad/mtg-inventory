class ScrapeCommanderDecklistJob < ApplicationJob
  include StructuredLogging

  queue_as :default

  # ---------------------------------------------------------------------------
  # Scrapes and saves decklist for a single commander
  #
  # This job is designed to be scheduled individually for each commander,
  # allowing distributed scraping with proper spacing to respect rate limits.
  #
  # Arguments:
  #   commander_id (Integer) - The ID of the commander to scrape
  #   execution_id (Integer, optional) - Parent execution record to update
  #
  # Raises:
  #   ActiveRecord::RecordNotFound - If commander doesn't exist
  #   EdhrecScraper::FetchError - Network errors (will trigger Solid Queue retry)
  #   EdhrecScraper::ParseError - Parsing errors (will trigger Solid Queue retry)
  #   EdhrecScraper::RateLimitError - Rate limit errors (will trigger Solid Queue retry)
  # ---------------------------------------------------------------------------
  def perform(commander_id, execution_id = nil)
    commander = Commander.find(commander_id)
    @execution = execution_id ? ScraperExecution.find(execution_id) : nil

    # Log structured start event
    log_event(
      level: :info,
      event: "decklist_scrape_started",
      commander_id: commander.id,
      commander_name: commander.name,
      edhrec_url: commander.edhrec_url
    )

    log_job_start(commander)

    # Fetch decklist from EDHREC
    Rails.logger.info("  └─ Fetching decklist from EDHREC...")
    deck_cards = EdhrecScraper.fetch_commander_decklist(commander.edhrec_url)
    Rails.logger.debug("  └─ Retrieved #{deck_cards.length} cards from decklist")

    # Save decklist in transaction
    cards_count = 0
    Commander.transaction do
      # Update last_scraped_at timestamp
      commander.update!(last_scraped_at: Time.current)
      Rails.logger.debug("  └─ Updated last_scraped_at timestamp")

      # Save decklist
      cards_count = save_decklist_for_commander(commander, deck_cards)
      Rails.logger.debug("  └─ Decklist saved with #{cards_count} cards")

      # Update execution record if provided
      if @execution
        @execution.increment!(:total_cards_processed, cards_count)
      end
    end

    log_job_success(commander, cards_count)

    # Log structured completion event
    log_event(
      level: :info,
      event: "decklist_scrape_completed",
      commander_id: commander.id,
      commander_name: commander.name,
      cards_count: cards_count
    )
  rescue EdhrecScraper::FetchError, EdhrecScraper::ParseError, EdhrecScraper::RateLimitError => e
    # Log structured error
    log_error(
      error: e,
      commander_id: commander.id,
      commander_name: commander.name,
      edhrec_url: commander.edhrec_url
    )

    # Re-raise scraper errors so Solid Queue can retry the job
    log_job_error(commander, e)
    raise
  end

  private

  # ---------------------------------------------------------------------------
  # Save or update decklist for a commander
  # ---------------------------------------------------------------------------
  def save_decklist_for_commander(commander, deck_cards)
    decklist_contents = build_decklist_contents(deck_cards)

    # For solo commanders (no partner), use partner_id: nil
    decklist = commander.decklists.find_or_initialize_by(partner_id: nil)
    decklist.contents = decklist_contents
    decklist.save! # TSVECTOR updated automatically via callback

    decklist_contents.length
  end

  # ---------------------------------------------------------------------------
  # Build JSONB decklist contents from raw card data
  # ---------------------------------------------------------------------------
  def build_decklist_contents(deck_cards)
    deck_cards.map do |card|
      {
        card_id: card[:scryfall_id],
        card_name: card[:name],
        card_url: card[:scryfall_uri],
        quantity: 1,
        is_commander: card[:is_commander]
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Log job start
  # ---------------------------------------------------------------------------
  def log_job_start(commander)
    Rails.logger.info("┌─ ScrapeCommanderDecklistJob: Processing '#{commander.name}' (Rank ##{commander.rank})")
  end

  # ---------------------------------------------------------------------------
  # Log job success
  # ---------------------------------------------------------------------------
  def log_job_success(commander, cards_count)
    Rails.logger.info("└─ ✓ SUCCESS: #{commander.name} - #{cards_count} cards saved")
  end

  # ---------------------------------------------------------------------------
  # Log job error
  # ---------------------------------------------------------------------------
  def log_job_error(commander, error)
    Rails.logger.error("└─ ✗ FAILED: #{commander.name} - #{error.class}: #{error.message}")
  end
end
