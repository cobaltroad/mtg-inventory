class ReportsController < ApplicationController
  # Returns consolidated inventory statistics for the reports page.
  # Aggregates key metrics across the user's entire collection.
  #
  # Returns JSON with:
  # - total_value_cents: Total market value of all cards
  # - cards_over_ten_dollars: Count of cards valued at $10+ each
  # - total_sets: Count of unique sets in collection
  def inventory_stats
    user_id = current_user.id
    collection_type = "inventory"

    base_query = CollectionItem.where(user_id: user_id, collection_type: collection_type)

    # Calculate total value using SQL aggregate with JOIN to card_prices
    # SUM(quantity * price) where price depends on finish type
    total_value_query = base_query
      .joins("LEFT JOIN LATERAL (
        SELECT card_id,
               usd_cents,
               usd_foil_cents,
               usd_etched_cents
        FROM card_prices
        WHERE card_prices.card_id = collection_items.card_id
        ORDER BY fetched_at DESC
        LIMIT 1
      ) AS latest_price ON true")
      .select("
        SUM(
          collection_items.quantity *
          CASE
            WHEN collection_items.finish = 'foil' THEN COALESCE(latest_price.usd_foil_cents, 0)
            WHEN collection_items.finish = 'etched' THEN COALESCE(latest_price.usd_etched_cents, 0)
            ELSE COALESCE(latest_price.usd_cents, 0)
          END
        ) AS total_value
      ")

    total_value_cents = total_value_query.limit(1).take&.total_value&.to_i || 0

    # Count cards valued over $10 (1000 cents)
    cards_over_ten_dollars = base_query
      .joins("LEFT JOIN LATERAL (
        SELECT card_id,
               usd_cents,
               usd_foil_cents,
               usd_etched_cents
        FROM card_prices
        WHERE card_prices.card_id = collection_items.card_id
        ORDER BY fetched_at DESC
        LIMIT 1
      ) AS latest_price ON true")
      .where("
        (collection_items.quantity *
          CASE
            WHEN collection_items.finish = 'foil' THEN COALESCE(latest_price.usd_foil_cents, 0)
            WHEN collection_items.finish = 'etched' THEN COALESCE(latest_price.usd_etched_cents, 0)
            ELSE COALESCE(latest_price.usd_cents, 0)
          END
        ) >= 1000
      ")
      .count

    # Count unique sets using DISTINCT on denormalized set_name
    # Use pluck to avoid GROUP BY issues with ActiveRecord's count
    total_sets = base_query.distinct.pluck(:set_name).compact.count

    render json: {
      total_value_cents: total_value_cents,
      cards_over_ten_dollars: cards_over_ten_dollars,
      total_sets: total_sets
    }
  end
end
