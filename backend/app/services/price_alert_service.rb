# Service for detecting significant price changes and creating alerts.
# Compares latest prices with prices from 24 hours ago and creates
# PriceAlert records for users with affected cards in their inventory.
class PriceAlertService
  # Thresholds for triggering alerts
  INCREASE_THRESHOLD = 20.0  # 20% or more price increase
  DECREASE_THRESHOLD = -30.0  # 30% or more price decrease

  # Minimum price threshold for increase alerts (in cents)
  # Price increase alerts require both percentage threshold AND this minimum old price
  MINIMUM_PRICE_FOR_INCREASE_ALERTS = 500  # $5.00

  # Time window for comparing prices
  PRICE_COMPARISON_WINDOW = 24.hours

  # Time window to prevent duplicate alerts
  DUPLICATE_PREVENTION_WINDOW = 24.hours

  # Detects price changes for all inventory items and creates alerts.
  # Only creates alerts for cards in user inventories (not wishlists).
  #
  # @return [Array<PriceAlert>] Array of created price alerts
  def detect_price_changes
    alerts = []

    # Get all unique card_ids from inventory items
    inventory_cards = CollectionItem.where(collection_type: "inventory")
                                    .select(:card_id, :user_id, :finish)
                                    .distinct

    inventory_cards.each do |item|
      alert = check_card_price_change(item)
      alerts << alert if alert
    end

    alerts
  end

  private

  # Checks if a specific card has a significant price change.
  #
  # @param item [CollectionItem] The inventory item to check
  # @return [PriceAlert, nil] Created alert or nil if no alert needed
  def check_card_price_change(item)
    # Get the two most recent price records
    latest_price, previous_price = get_price_comparison(item.card_id)

    return nil unless latest_price && previous_price

    # Get the appropriate price based on finish
    old_price = price_for_finish(previous_price, item.finish)
    new_price = price_for_finish(latest_price, item.finish)

    return nil unless old_price && new_price && old_price > 0

    # Calculate percentage change
    percentage_change = ((new_price - old_price).to_f / old_price * 100).round(2)

    # Check if change meets threshold
    return nil unless meets_threshold?(percentage_change)

    # Determine alert type
    alert_type = percentage_change > 0 ? "price_increase" : "price_decrease"

    # For price increases, also check minimum price threshold
    return nil if alert_type == "price_increase" && old_price < MINIMUM_PRICE_FOR_INCREASE_ALERTS

    # Check for duplicate alerts
    return nil if duplicate_alert_exists?(item.user, item.card_id)

    # Create the alert
    PriceAlert.create!(
      user: item.user,
      card_id: item.card_id,
      alert_type: alert_type,
      old_price_cents: old_price,
      new_price_cents: new_price,
      percentage_change: percentage_change,
      finish: normalize_finish(item.finish)
    )
  end

  # Retrieves the latest and previous price records for a card.
  #
  # @param card_id [String] The Scryfall card UUID
  # @return [Array<CardPrice, CardPrice>] Latest and previous prices
  def get_price_comparison(card_id)
    prices = CardPrice.where(card_id: card_id)
                     .order(fetched_at: :desc)
                     .limit(2)

    return nil unless prices.count >= 2

    [prices[0], prices[1]]
  end

  # Gets the appropriate price cents value based on card finish.
  #
  # @param price [CardPrice] The price record
  # @param finish [String, nil] The card finish
  # @return [Integer, nil] Price in cents or nil
  def price_for_finish(price, finish)
    case finish&.downcase
    when "foil"
      price.usd_foil_cents || price.usd_cents
    when "etched"
      price.usd_etched_cents || price.usd_cents
    else
      price.usd_cents
    end
  end

  # Checks if the percentage change meets alert thresholds.
  #
  # @param percentage_change [Float] The calculated percentage change
  # @return [Boolean] True if threshold is met
  def meets_threshold?(percentage_change)
    percentage_change >= INCREASE_THRESHOLD || percentage_change <= DECREASE_THRESHOLD
  end

  # Checks if a duplicate alert exists for this user and card.
  # Prevents spam by not creating alerts for the same card within 24 hours.
  #
  # @param user [User] The user
  # @param card_id [String] The card UUID
  # @return [Boolean] True if duplicate exists
  def duplicate_alert_exists?(user, card_id)
    PriceAlert.exists?(
      user: user,
      card_id: card_id,
      created_at: DUPLICATE_PREVENTION_WINDOW.ago..Time.current
    )
  end

  # Normalizes finish string to lowercase.
  #
  # @param finish [String, nil] The finish value
  # @return [String, nil] Normalized finish or nil
  def normalize_finish(finish)
    finish&.downcase
  end
end
