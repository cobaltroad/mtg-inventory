# Service class that calculates the total market value of a user's inventory.
# Handles treatment-based pricing (foil, etched, normal) and tracks cards
# without price data separately.
#
# Usage:
#   calculator = InventoryValueCalculator.new(user)
#   result = calculator.calculate
#   # => {
#   #   total_value_cents: 15000,
#   #   total_cards: 100,
#   #   valued_cards: 95,
#   #   excluded_cards: 5,
#   #   last_updated: <Time>
#   # }
class InventoryValueCalculator
  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Calculates the total inventory value for the user.
  # Returns a hash with total value, card counts, and last updated timestamp.
  #
  # @return [Hash] Value calculation results
  def calculate
    items = user.collection_items.where(collection_type: "inventory")

    total_value_cents = 0
    total_cards = 0
    valued_cards = 0
    excluded_cards = 0
    most_recent_price_time = nil

    items.each do |item|
      total_cards += item.quantity

      unit_price = item.unit_price_cents
      if unit_price.nil?
        excluded_cards += item.quantity
      else
        valued_cards += item.quantity
        total_value_cents += item.total_price_cents

        # Track most recent price update
        price = item.latest_price
        if price && (most_recent_price_time.nil? || price.fetched_at > most_recent_price_time)
          most_recent_price_time = price.fetched_at
        end
      end
    end

    {
      total_value_cents: total_value_cents,
      total_cards: total_cards,
      valued_cards: valued_cards,
      excluded_cards: excluded_cards,
      last_updated: most_recent_price_time
    }
  end
end
