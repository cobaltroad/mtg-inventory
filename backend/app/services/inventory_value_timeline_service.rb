# Service class that calculates inventory value snapshots over time.
# Creates daily data points showing how inventory value has changed
# over a specified time period.
#
# Usage:
#   service = InventoryValueTimelineService.new(user: current_user, time_period: 30)
#   result = service.call
#   # => {
#   #   timeline: [
#   #     { date: Date, value_cents: Integer },
#   #     ...
#   #   ],
#   #   summary: {
#   #     start_value_cents: Integer,
#   #     end_value_cents: Integer,
#   #     change_cents: Integer,
#   #     percentage_change: Float
#   #   }
#   # }
class InventoryValueTimelineService
  attr_reader :user, :time_period

  # Valid time period options (in days)
  VALID_TIME_PERIODS = [ 7, 30, 90 ].freeze
  DEFAULT_TIME_PERIOD = 30

  def initialize(user:, time_period: DEFAULT_TIME_PERIOD)
    @user = user
    @time_period = normalize_time_period(time_period)
  end

  # Calculates the inventory value timeline for the user.
  # Returns timeline data points and summary statistics.
  #
  # @return [Hash] Timeline data and summary
  def call
    # Get all inventory items for the user
    inventory_items = user.collection_items.where(collection_type: "inventory")

    # NEW: Get date range and preload ALL relevant prices in 1 query
    start_date = time_period.days.ago.to_date
    end_date = Date.today
    card_ids = inventory_items.pluck(:card_id).uniq

    @all_prices = CardPrice
      .where(card_id: card_ids)
      .where("fetched_at BETWEEN ? AND ?", start_date.beginning_of_day, end_date.end_of_day)
      .order(:card_id, :fetched_at)
      .group_by(&:card_id)  # { card_id => [prices sorted by fetched_at] }

    # Calculate value for each day in the time period
    timeline = calculate_timeline(inventory_items)

    # Calculate summary statistics
    summary = calculate_summary(timeline)

    {
      timeline: timeline,
      summary: summary
    }
  end

  private

  # Normalizes and validates the time_period parameter
  def normalize_time_period(period)
    normalized = period.to_i

    if VALID_TIME_PERIODS.include?(normalized)
      normalized
    else
      DEFAULT_TIME_PERIOD
    end
  end

  # Calculates value for each day in the time period
  def calculate_timeline(inventory_items)
    timeline = []
    start_date = time_period.days.ago.to_date
    end_date = Date.today

    # Create a data point for each day
    (start_date..end_date).each do |date|
      value_cents = calculate_value_for_date(inventory_items, date)

      timeline << {
        date: date,
        value_cents: value_cents
      }
    end

    timeline
  end

  # Calculates the total inventory value for a specific date
  def calculate_value_for_date(inventory_items, date)
    total_value = 0

    # Calculate value for each inventory item
    inventory_items.each do |item|
      prices = @all_prices[item.card_id] || []
      # Find the most recent price on or before the given date
      # Since prices are sorted by fetched_at ASC, we need to reverse to get latest
      latest_price = prices.reverse.find { |p| p.fetched_at <= date.end_of_day }
      next unless latest_price

      unit_price = latest_price.price_for_finish(item.finish)
      next unless unit_price

      total_value += unit_price * item.quantity
    end

    total_value
  end

  # Calculates summary statistics for the timeline
  def calculate_summary(timeline)
    return default_summary if timeline.empty?

    start_value = timeline.first[:value_cents]
    end_value = timeline.last[:value_cents]
    change = end_value - start_value

    # Calculate percentage change
    percentage_change = if start_value.zero?
      0.0
    else
      ((change.to_f / start_value) * 100).round(2)
    end

    {
      start_value_cents: start_value,
      end_value_cents: end_value,
      change_cents: change,
      percentage_change: percentage_change
    }
  end

  # Returns default summary when no data is available
  def default_summary
    {
      start_value_cents: 0,
      end_value_cents: 0,
      change_cents: 0,
      percentage_change: 0.0
    }
  end
end
