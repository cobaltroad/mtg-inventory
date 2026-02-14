class CollectionItem < ApplicationRecord
  COLLECTION_TYPES = %w[inventory wishlist].freeze

  # Scryfall-aligned finish types for pricing consistency
  FINISH_TYPES = %w[nonfoil foil etched].freeze

  LANGUAGE_OPTIONS = [
    "English", "Japanese", "German", "French", "Spanish",
    "Italian", "Portuguese", "Russian", "Korean",
    "Chinese Simplified", "Chinese Traditional"
  ].freeze

  belongs_to :user

  # Active Storage attachment for cached card images
  has_one_attached :cached_image

  # Callbacks to populate denormalized card metadata
  before_save :sync_card_metadata, if: :should_sync_metadata?

  # Required field validations
  validates :card_id, presence: true
  validates :card_id, uniqueness: { scope: [ :user_id, :collection_type ], message: "has already been taken" }
  validates :collection_type, presence: true, inclusion: { in: COLLECTION_TYPES }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 999 }

  # Prevent test/debug card IDs in non-test environments
  validate :card_id_must_not_contain_test_keywords, unless: -> { Rails.env.test? }

  # Enhanced tracking field validations (optional fields)
  validates :acquired_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :finish, inclusion: { in: FINISH_TYPES }, allow_nil: true
  validates :language, inclusion: { in: LANGUAGE_OPTIONS }, allow_nil: true

  validate :acquired_date_cannot_be_in_future

  # ---------------------------------------------------------------------------
  # Price enrichment methods
  # ---------------------------------------------------------------------------

  # Returns the most recent CardPrice record for this item's card_id.
  # Used to fetch current market pricing data for valuation.
  #
  # @return [CardPrice, nil] The latest price record, or nil if none exist
  def latest_price
    CardPrice.latest_for(card_id)
  end

  # Returns the unit price in cents based on the item's finish.
  # Delegates to CardPrice#price_for_finish to select the appropriate price field.
  #
  # @return [Integer, nil] Price in cents, or nil if no price data available
  def unit_price_cents
    price = latest_price
    return nil if price.nil?

    price.price_for_finish(finish)
  end

  # Returns the total price for all copies of this item (unit price × quantity).
  #
  # @return [Integer, nil] Total price in cents, or nil if no price data available
  def total_price_cents
    unit_price = unit_price_cents
    return nil if unit_price.nil?

    unit_price * quantity
  end

  private

  # ---------------------------------------------------------------------------
  # Denormalized field synchronization
  # ---------------------------------------------------------------------------

  # Determines if card metadata should be synced from Scryfall.
  # Syncs when:
  # - card_id has changed (new card or card swap)
  # - Any denormalized field is nil (backfill scenario)
  def should_sync_metadata?
    card_id_changed? || card_name.nil? || set_name.nil? || released_at.nil?
  end

  # Populates denormalized card fields from Scryfall API.
  # Handles errors gracefully - failures won't prevent record save.
  def sync_card_metadata
    return if card_id.blank?

    card_details = fetch_card_details_for_sync
    return unless card_details

    self.card_name = card_details[:name]
    self.set_name = card_details[:set_name]
    self.released_at = Date.parse(card_details[:released_at]) if card_details[:released_at]
  rescue StandardError => e
    Rails.logger.warn("Failed to sync card metadata for #{card_id}: #{e.message}")
    # Don't raise - allow save to proceed even if metadata sync fails
  end

  # Fetches card details from CardDetailsService with error handling
  def fetch_card_details_for_sync
    CardDetailsService.new(card_id: card_id).call
  rescue CardDetailsService::NetworkError, CardDetailsService::TimeoutError => e
    Rails.logger.warn("Network error fetching card details for #{card_id}: #{e.message}")
    nil
  rescue CardDetailsService::RateLimitError => e
    Rails.logger.error("Scryfall rate limit exceeded: #{e.message}")
    nil
  end

  def acquired_date_cannot_be_in_future
    return if acquired_date.blank?

    errors.add(:acquired_date, "cannot be in the future") if acquired_date > Date.today
  end

  def card_id_must_not_contain_test_keywords
    return if card_id.blank?

    test_keywords = %w[test debug mock fixture sample dummy]
    card_id_lower = card_id.downcase

    if test_keywords.any? { |keyword| card_id_lower.include?(keyword) }
      errors.add(:card_id, "cannot contain test-related keywords (test, debug, mock, fixture, sample, dummy)")
    end
  end
end
