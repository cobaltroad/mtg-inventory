class ScrapeEdhrecCommandersJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 3
  FATAL_ERROR_TYPES = [
    ActiveRecord::ConnectionNotEstablished,
    ActiveRecord::StatementInvalid,
    PG::Error,
    EdhrecScraper::RateLimitError  # Stop job if rate limited - entire job should be retried later
  ].freeze

  def perform
    log_job_start
    start_time = Time.current

    # Fetch commanders list
    Rails.logger.info("ScrapeEdhrecCommandersJob: Fetching top commanders from EDHREC...")
    commanders_data = EdhrecScraper.fetch_top_commanders
    total_commanders = commanders_data.length
    Rails.logger.info("ScrapeEdhrecCommandersJob: Found #{total_commanders} commanders to process")

    # Process each commander with progress tracking
    results = commanders_data.each_with_index.map do |commander_data, index|
      log_commander_start(commander_data, index + 1, total_commanders)
      result = process_commander_with_retry(commander_data)
      log_commander_result(result, index + 1, total_commanders)
      result
    end

    log_summary(results, start_time)
  end

  private

  # ---------------------------------------------------------------------------
  # Process a single commander with retry logic for transient errors
  # ---------------------------------------------------------------------------
  def process_commander_with_retry(commander_data)
    retries = 0

    begin
      cards_count = process_commander(commander_data)
      { success: true, name: commander_data[:name], cards_count: cards_count }
    rescue EdhrecScraper::FetchError, EdhrecScraper::ParseError => e
      # Transient errors - retry up to MAX_RETRIES
      retries += 1
      if retries <= MAX_RETRIES
        Rails.logger.warn(
          "ScrapeEdhrecCommandersJob: Retry #{retries}/#{MAX_RETRIES} for '#{commander_data[:name]}' - #{e.message}"
        )
        retry
      else
        Rails.logger.error(
          "ScrapeEdhrecCommandersJob: Max retries exceeded for '#{commander_data[:name]}' - #{e.message}"
        )
        { success: false, name: commander_data[:name], error: e.message }
      end
    rescue StandardError => e
      # Unexpected errors - log and continue (unless fatal)
      if fatal_error?(e)
        # Fatal errors should propagate to Solid Queue
        raise
      else
        Rails.logger.error(
          "ScrapeEdhrecCommandersJob: Failed to process '#{commander_data[:name]}' - #{e.class}: #{e.message}"
        )
        { success: false, name: commander_data[:name], error: e.message }
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Process a single commander (create/update commander and decklist)
  # ---------------------------------------------------------------------------
  def process_commander(commander_data)
    cards_count = 0

    Commander.transaction do
      # Upsert commander
      commander = Commander.find_or_initialize_by(name: commander_data[:name])
      commander.assign_attributes(
        rank: commander_data[:rank],
        edhrec_url: commander_data[:url],
        last_scraped_at: Time.current
      )
      commander.save!
      Rails.logger.debug("  └─ Commander record saved")

      # Fetch and save decklist from EDHREC
      Rails.logger.debug("  └─ Fetching decklist from EDHREC...")
      deck_cards = EdhrecScraper.fetch_commander_decklist(commander_data[:url])
      Rails.logger.debug("  └─ Retrieved #{deck_cards.length} cards from decklist")

      cards_count = save_decklist_for_commander(commander, deck_cards)
      Rails.logger.debug("  └─ Decklist saved with #{cards_count} cards")
    end

    cards_count
  end

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
        quantity: 1,
        is_commander: card[:is_commander]
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Determine if an error is fatal (should propagate to Solid Queue)
  # ---------------------------------------------------------------------------
  def fatal_error?(error)
    FATAL_ERROR_TYPES.any? { |type| error.is_a?(type) }
  end

  # ---------------------------------------------------------------------------
  # Log job start banner
  # ---------------------------------------------------------------------------
  def log_job_start
    Rails.logger.info("=" * 80)
    Rails.logger.info("ScrapeEdhrecCommandersJob: STARTING")
    Rails.logger.info("Started at: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    Rails.logger.info("=" * 80)
  end

  # ---------------------------------------------------------------------------
  # Log commander processing start
  # ---------------------------------------------------------------------------
  def log_commander_start(commander_data, current, total)
    progress_pct = ((current.to_f / total) * 100).round(1)
    Rails.logger.info("┌─ [#{current}/#{total}] (#{progress_pct}%) Processing: #{commander_data[:name]} (Rank ##{commander_data[:rank]})")
  end

  # ---------------------------------------------------------------------------
  # Log commander processing result
  # ---------------------------------------------------------------------------
  def log_commander_result(result, current, total)
    if result[:success]
      Rails.logger.info("└─ ✓ SUCCESS: #{result[:name]} - #{result[:cards_count]} cards saved")
    else
      Rails.logger.error("└─ ✗ FAILED: #{result[:name]} - #{result[:error]}")
    end
    Rails.logger.info("") # Blank line for readability
  end

  # ---------------------------------------------------------------------------
  # Log comprehensive summary of job execution
  # ---------------------------------------------------------------------------
  def log_summary(results, start_time)
    execution_time = (Time.current - start_time).round(2)
    summary_data = build_summary_data(results, execution_time)

    Rails.logger.info("=" * 80)
    Rails.logger.info("ScrapeEdhrecCommandersJob: COMPLETED")
    Rails.logger.info("=" * 80)
    Rails.logger.info("Finished at:              #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    Rails.logger.info("Execution time:           #{summary_data[:execution_time]}s")
    Rails.logger.info("-" * 80)
    Rails.logger.info("Total commanders:         #{summary_data[:total_attempted]}")
    Rails.logger.info("Successfully scraped:     #{summary_data[:successful_count]} (#{percentage(summary_data[:successful_count], summary_data[:total_attempted])}%)")
    Rails.logger.info("Failed:                   #{summary_data[:failed_count]} (#{percentage(summary_data[:failed_count], summary_data[:total_attempted])}%)")

    if summary_data[:failed_count] > 0
      Rails.logger.info("-" * 80)
      Rails.logger.info("Failed commanders:")
      summary_data[:failed_names].each do |name|
        Rails.logger.info("  • #{name}")
      end
    end

    Rails.logger.info("-" * 80)
    Rails.logger.info("Total cards processed:    #{summary_data[:total_cards]}")
    Rails.logger.info("Average cards/commander:  #{average_cards(summary_data)}")
    Rails.logger.info("=" * 80)
  end

  # ---------------------------------------------------------------------------
  # Build summary data hash from results
  # ---------------------------------------------------------------------------
  def build_summary_data(results, execution_time)
    successful_results = results.select { |r| r[:success] }
    failed_results = results.reject { |r| r[:success] }

    {
      total_attempted: results.length,
      successful_count: successful_results.length,
      failed_count: failed_results.length,
      failed_names: failed_results.map { |r| r[:name] },
      total_cards: successful_results.sum { |r| r[:cards_count] || 0 },
      execution_time: execution_time
    }
  end

  # ---------------------------------------------------------------------------
  # Calculate percentage for display
  # ---------------------------------------------------------------------------
  def percentage(part, total)
    return 0 if total.zero?
    ((part.to_f / total) * 100).round(1)
  end

  # ---------------------------------------------------------------------------
  # Calculate average cards per commander
  # ---------------------------------------------------------------------------
  def average_cards(data)
    return 0 if data[:successful_count].zero?
    (data[:total_cards].to_f / data[:successful_count]).round(1)
  end
end
