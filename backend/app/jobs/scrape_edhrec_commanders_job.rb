class ScrapeEdhrecCommandersJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 3
  FATAL_ERROR_TYPES = [
    ActiveRecord::ConnectionNotEstablished,
    ActiveRecord::StatementInvalid,
    PG::Error
  ].freeze

  def perform
    start_time = Time.current
    commanders_data = EdhrecScraper.fetch_top_commanders

    results = commanders_data.map do |commander_data|
      process_commander_with_retry(commander_data)
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

      # Fetch and save decklist from EDHREC
      deck_cards = EdhrecScraper.fetch_commander_decklist(commander_data[:url])
      cards_count = save_decklist_for_commander(commander, deck_cards)
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
  # Log comprehensive summary of job execution
  # ---------------------------------------------------------------------------
  def log_summary(results, start_time)
    execution_time = (Time.current - start_time).round(2)

    summary_data = build_summary_data(results, execution_time)
    log_message = format_summary_message(summary_data)

    Rails.logger.info(log_message)
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
  # Format summary data into log message
  # ---------------------------------------------------------------------------
  def format_summary_message(data)
    parts = [
      "ScrapeEdhrecCommandersJob completed",
      "Total commanders attempted: #{data[:total_attempted]}",
      "Successfully scraped: #{data[:successful_count]}",
      "Failed: #{data[:failed_count]}",
      ("Failed commanders: #{data[:failed_names].join(', ')}" if data[:failed_count] > 0),
      "Execution time: #{data[:execution_time]}s",
      "Total cards inserted/updated: #{data[:total_cards]}"
    ]

    parts.compact.join(" | ")
  end
end
