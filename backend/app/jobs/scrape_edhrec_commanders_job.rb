class ScrapeEdhrecCommandersJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 3

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

      # Fetch decklist from EDHREC
      deck_cards = EdhrecScraper.fetch_commander_decklist(commander_data[:url])

      # Build JSONB contents array
      decklist_contents = deck_cards.map do |card|
        {
          card_id: card[:scryfall_id],
          card_name: card[:name],
          quantity: 1,
          is_commander: card[:is_commander]
        }
      end

      cards_count = decklist_contents.length

      # Update or create decklist with JSONB contents
      # For solo commanders (no partner), use partner_id: nil
      decklist = commander.decklists.find_or_initialize_by(partner_id: nil)
      decklist.contents = decklist_contents
      decklist.save! # TSVECTOR updated automatically via callback
    end

    cards_count
  end

  # ---------------------------------------------------------------------------
  # Determine if an error is fatal (should propagate to Solid Queue)
  # ---------------------------------------------------------------------------
  def fatal_error?(error)
    error.is_a?(ActiveRecord::ConnectionNotEstablished) ||
      error.is_a?(ActiveRecord::StatementInvalid) ||
      error.is_a?(PG::Error)
  end

  # ---------------------------------------------------------------------------
  # Log comprehensive summary of job execution
  # ---------------------------------------------------------------------------
  def log_summary(results, start_time)
    execution_time = Time.current - start_time

    successful = results.count { |r| r[:success] }
    failed = results.count { |r| !r[:success] }
    total_cards = results.sum { |r| r[:cards_count] || 0 }

    failed_names = results
      .select { |r| !r[:success] }
      .map { |r| r[:name] }

    summary = [
      "ScrapeEdhrecCommandersJob completed",
      "Total commanders attempted: #{results.length}",
      "Successfully scraped: #{successful}",
      "Failed: #{failed}",
      ("Failed commanders: #{failed_names.join(', ')}" if failed > 0),
      "Execution time: #{execution_time.round(2)}s",
      "Total cards inserted/updated: #{total_cards}"
    ].compact.join(" | ")

    Rails.logger.info(summary)
  end
end
