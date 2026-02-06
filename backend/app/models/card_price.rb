# Stores historical pricing data for Magic: The Gathering cards.
# Prices are fetched from Scryfall API and stored in cents to avoid
# floating-point precision issues.
#
# Each record represents a price snapshot at a specific point in time,
# allowing for price history tracking and valuation calculations.
class CardPrice < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  validates :card_id, presence: true
  validates :fetched_at, presence: true

  validates :usd_cents,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      allow_nil: true
    }

  validates :usd_foil_cents,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      allow_nil: true
    }

  validates :usd_etched_cents,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      allow_nil: true
    }

  # ---------------------------------------------------------------------------
  # Scopes and Class Methods
  # ---------------------------------------------------------------------------

  # Returns the most recent price record for a given card_id.
  # Uses the composite index (card_id, fetched_at DESC) for efficient lookup.
  #
  # @param card_id [String] The Scryfall card UUID
  # @return [CardPrice, nil] The latest price record, or nil if none exist
  def self.latest_for(card_id)
    where(card_id: card_id)
      .order(fetched_at: :desc)
      .first
  end

  # Returns price records for a card within a specified date range.
  # Uses the composite index (card_id, fetched_at DESC) for efficient lookup.
  # Results are ordered by fetched_at DESC (most recent first).
  #
  # @param card_id [String] The Scryfall card UUID
  # @param start_date [Time, Date] Start of date range (inclusive)
  # @param end_date [Time, Date] End of date range (inclusive)
  # @return [ActiveRecord::Relation] Price records within the date range
  def self.for_date_range(card_id, start_date, end_date)
    where(card_id: card_id)
      .where(fetched_at: start_date..end_date)
      .order(fetched_at: :desc)
  end

  # ---------------------------------------------------------------------------
  # Instance Methods
  # ---------------------------------------------------------------------------

  # Returns the appropriate price in cents based on treatment type.
  # Selects the correct price field based on treatment and falls back appropriately:
  # - Foil treatment: uses usd_foil_cents, falls back to usd_cents
  # - Etched treatment: uses usd_etched_cents, falls back to usd_cents
  # - Normal/nil treatment: uses usd_cents
  #
  # @param treatment [String, nil] The treatment type (e.g., "Foil", "Etched", "Normal")
  # @return [Integer, nil] Price in cents, or nil if no price data available
  def price_for_treatment(treatment)
    case treatment&.downcase
    when "foil"
      usd_foil_cents || usd_cents
    when "etched"
      usd_etched_cents || usd_cents
    else
      usd_cents
    end
  end
end
