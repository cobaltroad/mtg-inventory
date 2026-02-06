# Provides historical pricing data for individual Magic: The Gathering cards.
#
# This controller serves price history data for visualization and analysis,
# allowing users to track price trends over time for different card treatments
# (normal, foil, etched).
class CardPriceHistoryController < ApplicationController
  # GET /api/cards/:card_id/price_history
  #
  # Returns historical price data for a specific card with support for:
  # - Time period filtering (7, 30, 90, 365 days, or all)
  # - Multiple treatment types (normal, foil, etched)
  # - Percentage change calculations with direction indicators
  #
  # Query Parameters:
  #   time_period - Optional. One of: 7, 30, 90, 365, "all". Defaults to 30.
  #
  # Response Format:
  # {
  #   "card_id": "uuid",
  #   "time_period": "30",
  #   "prices": [
  #     {
  #       "fetched_at": "2024-01-15T12:00:00.000Z",
  #       "usd_cents": 1000,
  #       "usd_foil_cents": 2000,
  #       "usd_etched_cents": null
  #     }
  #   ],
  #   "summary": {
  #     "normal": {
  #       "start_price_cents": 1000,
  #       "end_price_cents": 1500,
  #       "percentage_change": 50.0,
  #       "direction": "up"
  #     }
  #   }
  # }
  def show
    card_id = params[:card_id]
    time_period = normalize_time_period(params[:time_period])

    # Fetch price history based on time period
    prices = fetch_price_history(card_id, time_period)

    # Calculate summary statistics
    summary = calculate_summary(prices)

    render json: {
      card_id: card_id,
      time_period: time_period.to_s,
      prices: serialize_prices(prices),
      summary: summary
    }
  end

  private

  # Normalizes and validates the time_period parameter
  # Returns a valid time period value or defaults to 30
  def normalize_time_period(period)
    valid_periods = [ 7, 30, 90, 365, "all" ]
    normalized = period.to_s

    if normalized == "all"
      "all"
    elsif valid_periods.include?(normalized.to_i)
      normalized.to_i
    else
      30 # default
    end
  end

  # Fetches price history for a card based on the time period
  # Returns prices ordered by fetched_at ASC (oldest to newest) for chart display
  def fetch_price_history(card_id, time_period)
    query = CardPrice.where(card_id: card_id)

    unless time_period == "all"
      start_date = time_period.days.ago.beginning_of_day
      query = query.where("fetched_at >= ?", start_date)
    end

    # Order ASC for chart display (left to right: old to new)
    query.order(fetched_at: :asc)
  end

  # Serializes price records to JSON-friendly format
  def serialize_prices(prices)
    prices.map do |price|
      {
        fetched_at: price.fetched_at.iso8601(3),
        usd_cents: price.usd_cents,
        usd_foil_cents: price.usd_foil_cents,
        usd_etched_cents: price.usd_etched_cents
      }
    end
  end

  # Calculates summary statistics for each treatment type
  # Returns percentage change and direction for the time period
  def calculate_summary(prices)
    return {} if prices.empty?

    summary = {}

    # Calculate for each treatment type
    treatments = {
      "normal" => :usd_cents,
      "foil" => :usd_foil_cents,
      "etched" => :usd_etched_cents
    }

    treatments.each do |treatment_name, price_field|
      treatment_summary = calculate_treatment_summary(prices, price_field)
      summary[treatment_name] = treatment_summary if treatment_summary
    end

    summary
  end

  # Calculates summary for a specific treatment type
  def calculate_treatment_summary(prices, price_field)
    # Filter to records that have this treatment price
    prices_with_treatment = prices.select { |p| p.send(price_field).present? }

    return nil if prices_with_treatment.empty?

    start_price = prices_with_treatment.first.send(price_field)
    end_price = prices_with_treatment.last.send(price_field)

    # Calculate percentage change
    percentage_change = if start_price.zero?
      0.0
    else
      ((end_price - start_price).to_f / start_price * 100).round(2)
    end

    # Determine direction
    direction = if percentage_change > 0
      "up"
    elsif percentage_change < 0
      "down"
    else
      "stable"
    end

    {
      start_price_cents: start_price,
      end_price_cents: end_price,
      percentage_change: percentage_change,
      direction: direction
    }
  end
end
