# Background job to fetch and store current market prices for a Magic: The Gathering card.
# Uses CardPriceService to retrieve prices from Scryfall API and creates a CardPrice record.
#
# This job can be scheduled to run periodically for cards in inventory to maintain
# up-to-date pricing information for valuation purposes.
class UpdateCardPricesJob < ApplicationJob
  queue_as :default

  # Retry on rate limit errors with exponential backoff
  retry_on CardPriceService::RateLimitError,
    wait: :exponentially_longer,
    attempts: 5

  # Retry on network errors with exponential backoff
  retry_on CardPriceService::NetworkError,
    wait: :exponentially_longer,
    attempts: 3

  # ---------------------------------------------------------------------------
  # Fetches current prices for the specified card and stores them in the database.
  #
  # @param card_id [String] The Scryfall card UUID to fetch prices for
  # @raise [ArgumentError] if card_id is nil or blank
  # ---------------------------------------------------------------------------
  def perform(card_id)
    validate_card_id!(card_id)

    Rails.logger.info("Updating prices for card: #{card_id}")

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

  private

  # Validates that card_id is present
  def validate_card_id!(card_id)
    if card_id.nil? || card_id.to_s.strip.empty?
      Rails.logger.error("UpdateCardPricesJob: card_id is required")
      raise ArgumentError, "card_id is required"
    end
  end
end
