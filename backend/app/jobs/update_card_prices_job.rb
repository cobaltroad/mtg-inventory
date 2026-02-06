# Background job to fetch and store current market prices for Magic: The Gathering cards.
# Uses CardPriceService to retrieve prices from Scryfall API and creates CardPrice records.
#
# When called without arguments, processes all unique cards across all user collections
# in batches of 50 with rate limiting. When called with a card_id argument, processes
# a single card (legacy behavior for backward compatibility).
#
# Scheduled to run daily at 2 AM UTC using Solid Queue for historical price tracking.
class UpdateCardPricesJob < ApplicationJob
  queue_as :default

  # Batch processing configuration
  BATCH_SIZE = 50
  BATCH_DELAY = 0.1 # 100ms delay between batches
  PROGRESS_LOG_INTERVAL = 100 # Log progress every N cards

  # Retry on rate limit errors with exponential backoff
  retry_on CardPriceService::RateLimitError,
    wait: :exponentially_longer,
    attempts: 5

  # Retry on network errors with exponential backoff
  retry_on CardPriceService::NetworkError,
    wait: :exponentially_longer,
    attempts: 3

  # ---------------------------------------------------------------------------
  # Fetches current prices and stores them in the database.
  #
  # @param card_id [String, nil] Optional. If provided, processes single card.
  #   If nil, processes all cards across all user collections in batches.
  # @raise [ArgumentError] if card_id is provided but invalid
  # ---------------------------------------------------------------------------
  def perform(card_id = nil)
    if card_id.nil?
      # Batch mode: process all cards across all collections
      process_all_cards
    else
      # Single card mode: process specific card (legacy behavior)
      process_single_card(card_id)
    end
  end

  private

  # Process all unique cards across all user collections
  def process_all_cards
    start_time = Time.current

    # Get all unique card_ids from all collection items
    all_card_ids = CollectionItem.distinct.pluck(:card_id)

    if all_card_ids.empty?
      Rails.logger.info("No cards found to update")
      return
    end

    Rails.logger.info("Starting batch price update for #{all_card_ids.count} unique cards")

    # Filter out cards already processed today for idempotency
    card_ids_to_process = filter_unprocessed_cards(all_card_ids)

    if card_ids_to_process.empty?
      Rails.logger.info("All cards already processed today")
      return
    end

    Rails.logger.info("Processing #{card_ids_to_process.count} cards (#{all_card_ids.count - card_ids_to_process.count} already processed today)")

    # Process cards in batches
    total_processed = 0
    total_successful = 0

    card_ids_to_process.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
      batch.each do |card_id|
        begin
          fetch_and_store_price(card_id)
          total_successful += 1
        rescue CardPriceService::NetworkError, CardPriceService::RateLimitError => e
          # Re-raise to trigger retry - idempotency ensures we resume correctly
          Rails.logger.error("Failed batch processing at card #{card_id}: #{e.message}")
          raise
        rescue StandardError => e
          # Log but continue processing other cards
          Rails.logger.error("Error processing card #{card_id}: #{e.message}")
        end

        total_processed += 1

        # Log progress periodically
        if (total_processed % PROGRESS_LOG_INTERVAL).zero?
          Rails.logger.info("Processed #{total_processed} cards...")
        end
      end

      # Add delay between batches (except after last batch)
      unless batch_index == (card_ids_to_process.length / BATCH_SIZE.to_f).ceil - 1
        sleep_between_batches
      end
    end

    execution_time = (Time.current - start_time).round(2)
    Rails.logger.info("Completed price update job in #{execution_time} seconds")
    Rails.logger.info("Updated prices for #{total_successful} cards")

    # Detect price changes and create alerts
    detect_price_changes
  end

  # Process a single card (legacy single-card mode)
  def process_single_card(card_id)
    validate_card_id!(card_id)

    Rails.logger.info("Updating prices for card: #{card_id}")

    begin
      fetch_and_store_price(card_id)
      Rails.logger.info("Successfully updated prices for card: #{card_id}")
    rescue CardPriceService::RateLimitError => e
      Rails.logger.error("Failed to update prices for card #{card_id}: #{e.message}")
      raise # Re-raise to trigger retry
    rescue CardPriceService::NetworkError => e
      Rails.logger.error("Failed to update prices for card #{card_id}: #{e.message}")
      raise # Re-raise to trigger retry
    rescue StandardError => e
      Rails.logger.error("Unexpected error updating prices for card #{card_id}: #{e.message}")
      raise
    end
  end

  # Fetch price data and store in database
  def fetch_and_store_price(card_id)
    # Fetch prices using service
    price_data = CardPriceService.new(card_id: card_id).call

    # If card not found (404), don't create a record
    if price_data.nil?
      Rails.logger.info("Card #{card_id} not found in Scryfall API")
      return
    end

    # Create price record
    CardPrice.create!(
      card_id: price_data[:card_id],
      usd_cents: price_data[:usd_cents],
      usd_foil_cents: price_data[:usd_foil_cents],
      usd_etched_cents: price_data[:usd_etched_cents],
      fetched_at: price_data[:fetched_at]
    )
  end

  # Filter out cards that already have a price record from today
  # This provides idempotency for retry scenarios
  def filter_unprocessed_cards(card_ids)
    today_start = Time.current.beginning_of_day

    # Get card_ids that already have a price record from today
    processed_today = CardPrice
      .where(card_id: card_ids)
      .where("fetched_at >= ?", today_start)
      .distinct
      .pluck(:card_id)

    # Return cards that haven't been processed today
    card_ids - processed_today
  end

  # Validates that card_id is present
  def validate_card_id!(card_id)
    if card_id.nil? || card_id.to_s.strip.empty?
      Rails.logger.error("UpdateCardPricesJob: card_id is required")
      raise ArgumentError, "card_id is required"
    end
  end

  # Sleep between batches for rate limiting
  # Extracted as method to allow stubbing in tests
  def sleep_between_batches
    sleep(BATCH_DELAY)
  end

  # Detect significant price changes and create alerts for users
  def detect_price_changes
    Rails.logger.info("Detecting price changes for alerts...")
    start_time = Time.current

    begin
      service = PriceAlertService.new
      alerts = service.detect_price_changes

      execution_time = (Time.current - start_time).round(2)
      Rails.logger.info("Created #{alerts.count} price alerts in #{execution_time} seconds")
    rescue StandardError => e
      Rails.logger.error("Error detecting price changes: #{e.message}")
      # Don't raise - we don't want to fail the whole job if alert detection fails
    end
  end
end
