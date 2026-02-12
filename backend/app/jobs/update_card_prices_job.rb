# Background job to fetch and store current market prices for Magic: The Gathering cards.
# Uses CardPriceService to retrieve prices from Scryfall API and creates CardPrice records.
#
# When called without arguments, processes all unique cards across all user collections
# in batches of 50 with rate limiting. When called with a card_id argument, processes
# a single card (legacy behavior for backward compatibility).
#
# Scheduled to run daily at 2 AM UTC using Solid Queue for historical price tracking.
class UpdateCardPricesJob < ApplicationJob
  include StructuredLogging
  include DuplicatePrevention

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
    mode = card_id.nil? ? "batch" : "single_card"
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: mode
    )

    log_event(
      level: :info,
      event: "price_update_started",
      execution_id: execution.id,
      mode: mode,
      card_id: card_id
    )

    begin
      if card_id.nil?
        # Batch mode: process all cards across all collections
        process_all_cards(execution)
      else
        # Single card mode: process specific card (legacy behavior)
        process_single_card(card_id, execution)
      end

      # Determine final status
      final_status = determine_final_status(execution)
      execution.update!(
        finished_at: Time.current,
        status: final_status
      )

      log_event(
        level: :info,
        event: "price_update_completed",
        execution_id: execution.id,
        status: final_status,
        mode: mode,
        cards_attempted: execution.cards_attempted,
        cards_succeeded: execution.cards_succeeded,
        cards_failed: execution.cards_failed,
        cards_skipped: execution.cards_skipped,
        price_alerts_created: execution.price_alerts_created,
        duration_seconds: execution.execution_time_seconds
      )
    rescue StandardError => e
      execution.update!(
        finished_at: Time.current,
        status: :failure,
        error_summary: "#{e.class.name}: #{e.message}"
      )

      log_error(
        error: e,
        execution_id: execution.id,
        mode: mode,
        card_id: card_id
      )

      raise
    end
  end

  private

  # Process all unique cards across all user collections
  def process_all_cards(execution)
    # Get all unique card_ids from all collection items
    all_card_ids = CollectionItem.distinct.pluck(:card_id)

    if all_card_ids.empty?
      log_event(level: :info, event: "no_cards_to_process")
      return
    end

    # Filter out cards already processed today for idempotency
    card_ids_to_process = filter_unprocessed_cards(all_card_ids)
    cards_skipped = all_card_ids.count - card_ids_to_process.count

    if card_ids_to_process.empty?
      execution.update!(cards_skipped: cards_skipped)
      log_event(level: :info, event: "all_cards_already_processed", cards_skipped: cards_skipped)
      return
    end

    # Initialize counters
    total_processed = 0
    total_successful = 0
    total_failed = 0

    # Process cards in batches
    card_ids_to_process.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
      log_event(
        level: :info,
        event: "batch_started",
        batch_number: batch_index + 1,
        batch_size: batch.size
      )

      batch.each do |card_id|
        begin
          fetch_and_store_price(card_id)
          total_successful += 1

          log_event(
            level: :info,
            event: "card_processed",
            card_id: card_id,
            success: true
          )
        rescue CardPriceService::RateLimitError => e
          # Log rate limit and re-raise to trigger retry
          log_rate_limit(service: "Scryfall", retry_after: e.try(:retry_after))
          raise
        rescue CardPriceService::NetworkError, CardPriceService::RateLimitError => e
          # Re-raise to trigger retry - idempotency ensures we resume correctly
          log_error(error: e, card_id: card_id, context: "batch_processing")
          raise
        rescue StandardError => e
          # Log but continue processing other cards
          total_failed += 1
          log_event(
            level: :warn,
            event: "card_processed",
            card_id: card_id,
            success: false,
            error_message: e.message
          )
        end

        total_processed += 1

        # Log progress periodically
        if (total_processed % PROGRESS_LOG_INTERVAL).zero?
          log_event(
            level: :info,
            event: "progress_update",
            cards_processed: total_processed,
            cards_succeeded: total_successful,
            cards_failed: total_failed
          )
        end
      end

      log_event(
        level: :info,
        event: "batch_completed",
        batch_number: batch_index + 1,
        success_count: total_successful,
        failure_count: total_failed
      )

      # Add delay between batches (except after last batch)
      unless batch_index == (card_ids_to_process.length / BATCH_SIZE.to_f).ceil - 1
        sleep_between_batches
      end
    end

    # Detect price changes and create alerts
    alerts_count = detect_price_changes

    # Update execution record with final counts
    execution.update!(
      cards_attempted: total_processed,
      cards_succeeded: total_successful,
      cards_failed: total_failed,
      cards_skipped: cards_skipped,
      price_alerts_created: alerts_count
    )
  end

  # Process a single card (legacy single-card mode)
  def process_single_card(card_id, execution)
    validate_card_id!(card_id)

    log_event(level: :info, event: "single_card_started", card_id: card_id)

    begin
      fetch_and_store_price(card_id)

      execution.update!(
        cards_attempted: 1,
        cards_succeeded: 1,
        cards_failed: 0
      )

      log_event(level: :info, event: "card_processed", card_id: card_id, success: true)
    rescue CardPriceService::RateLimitError => e
      execution.update!(cards_attempted: 1, cards_failed: 1)
      log_rate_limit(service: "Scryfall", retry_after: e.try(:retry_after))
      raise # Re-raise to trigger retry
    rescue CardPriceService::NetworkError => e
      execution.update!(cards_attempted: 1, cards_failed: 1)
      log_error(error: e, card_id: card_id)
      raise # Re-raise to trigger retry
    rescue StandardError => e
      execution.update!(cards_attempted: 1, cards_failed: 1)
      log_error(error: e, card_id: card_id)
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
    log_event(level: :info, event: "detecting_price_changes")

    begin
      service = PriceAlertService.new
      alerts = service.detect_price_changes

      log_event(
        level: :info,
        event: "price_alerts_detected",
        count: alerts.count
      )

      alerts.count
    rescue StandardError => e
      log_error(error: e, context: "price_change_detection")
      # Don't raise - we don't want to fail the whole job if alert detection fails
      0
    end
  end

  # Determine final execution status based on results
  def determine_final_status(execution)
    if execution.cards_failed.zero?
      :success
    elsif execution.cards_succeeded.positive?
      :partial_success
    else
      :failure
    end
  end
end
