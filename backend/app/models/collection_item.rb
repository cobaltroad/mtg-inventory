class CollectionItem < ApplicationRecord
  COLLECTION_TYPES = %w[inventory wishlist].freeze

  TREATMENT_OPTIONS = [
    "Normal", "Foil", "Etched", "Showcase", "Extended Art",
    "Borderless", "Full Art", "Retro Frame", "Textured Foil"
  ].freeze

  LANGUAGE_OPTIONS = [
    "English", "Japanese", "German", "French", "Spanish",
    "Italian", "Portuguese", "Russian", "Korean",
    "Chinese Simplified", "Chinese Traditional"
  ].freeze

  belongs_to :user

  # Active Storage attachment for cached card images
  has_one_attached :cached_image

  # Required field validations
  validates :card_id, presence: true
  validates :card_id, uniqueness: { scope: [ :user_id, :collection_type ], message: "has already been taken" }
  validates :collection_type, presence: true, inclusion: { in: COLLECTION_TYPES }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 999 }

  # Enhanced tracking field validations (optional fields)
  validates :acquired_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :treatment, inclusion: { in: TREATMENT_OPTIONS }, allow_nil: true
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

  # Returns the unit price in cents based on the item's treatment.
  # Selects the appropriate price field from CardPrice:
  # - Foil treatment: uses usd_foil_cents, falls back to usd_cents
  # - Etched treatment: uses usd_etched_cents, falls back to usd_cents
  # - Normal/nil treatment: uses usd_cents
  #
  # @return [Integer, nil] Price in cents, or nil if no price data available
  def unit_price_cents
    price = latest_price
    return nil if price.nil?

    case treatment&.downcase
    when "foil"
      price.usd_foil_cents || price.usd_cents
    when "etched"
      price.usd_etched_cents || price.usd_cents
    else
      price.usd_cents
    end
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

  def acquired_date_cannot_be_in_future
    return if acquired_date.blank?

    errors.add(:acquired_date, "cannot be in the future") if acquired_date > Date.today
  end
end
