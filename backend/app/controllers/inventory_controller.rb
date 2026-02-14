class InventoryController < ApplicationController
  include CollectionItemActions
  include Pagy::Backend

  before_action :validate_card_with_sdk, only: [ :create ]

  # Override create to enqueue image caching job after successful save
  def create
    super
    enqueue_image_cache_job if response.successful?
  end

  # Override index to include card details from Scryfall with pagination.
  # Backend pagination implemented per Spike #156 findings.
  # Global sorting implemented per Issue #163 - sorts entire collection before pagination.
  #
  # Query Parameters:
  #   page - Page number (default: 1)
  #   per_page - Items per page (default: 20, max: 100)
  #   sort - Sort order (default: name-asc)
  #          Options: name-asc, name-desc, set-asc, set-desc,
  #                   release-newest, release-oldest, value-high, value-low,
  #                   date-newest, date-oldest
  #
  # Returns JSON with:
  #   items: array of inventory items with card details
  #   page: current page number
  #   per_page: items per page
  #   total_count: total number of items
  #   total_pages: total number of pages
  #   sort: current sort option
  #   stats: inventory statistics (most_valuable_card, total_value_cents, total_sets, most_collected_set)
  def index
    # Get base collection scoped to current user and inventory type
    base_items = collection_items.includes(cached_image_attachment: :blob)

    # Normalize and validate sort parameter
    sort_option = normalize_sort_param(params[:sort])

    # Pagination parameters
    requested_per_page = params[:per_page].to_i
    per_page = if requested_per_page > 0
                 [ requested_per_page, 100 ].min
               else
                 20
               end
    page = (params[:page] || 1).to_i

    # OPTION A: Enrich ALL items, sort globally, then paginate
    # This ensures accurate global sorting across all pages
    preload_prices(base_items)
    all_items_enriched = enrich_with_card_details(base_items)
    sorted_items = apply_sort(all_items_enriched, sort_option)

    # Paginate the sorted array using Pagy::Array
    pagy, paginated_items = pagy_array(sorted_items, page: page, limit: per_page)

    # Handle case where requested page is beyond available pages (e.g., after deletions)
    # When page > total_pages, return empty items array to signal frontend
    # that this page doesn't exist anymore
    if page > pagy.pages && pagy.pages > 0
      paginated_items = []
    end

    # Calculate stats for entire inventory using SQL aggregates
    stats = if base_items.any?
              calculate_inventory_stats_from_enriched(base_items)
            else
              {
                most_valuable_card: nil,
                total_value_cents: 0,
                cards_over_ten_dollars: 0,
                total_sets: 0,
                most_collected_set: nil
              }
            end

    # Correct total_pages for empty inventory
    # Pagy returns 1 page for empty collections, but we want 0 pages
    actual_total_pages = pagy.count == 0 ? 0 : pagy.pages

    render json: {
      items: paginated_items,
      page: pagy.page,
      per_page: pagy.limit,
      total_count: pagy.count,
      total_pages: actual_total_pages,
      sort: sort_option,
      stats: stats
    }
  end

  # Override update to return enriched item with card details
  def update
    item = find_item!(params[:id])
    return unless item # find_item! already rendered 404

    if item.update(quantity: quantity_param)
      card_details = fetch_card_details(item.card_id)
      if card_details
        enriched_item = serialize_item_with_details(item, card_details)
        render json: enriched_item
      else
        # Fallback if card details unavailable
        render json: item
      end
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # Calculates the total current market value of the user's inventory.
  # Uses finish-based pricing (foil, etched, nonfoil) and excludes cards without price data.
  # Results are cached for 1 hour and invalidated on inventory/price updates.
  #
  # Returns JSON with:
  # - total_value_cents: sum of (quantity × market_price) for all cards
  # - total_cards: total count of all cards in inventory
  # - valued_cards: count of cards with price data
  # - excluded_cards: count of cards without price data
  # - last_updated: timestamp of most recent price update
  def value
    cache_key = "inventory_value_user_#{current_user.id}"

    result = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      InventoryValueCalculator.new(current_user).calculate
    end

    render json: result
  end

  # Returns inventory value timeline data showing how total inventory value
  # has changed over time.
  #
  # Query Parameters:
  #   time_period - Optional. One of: 7, 30, 90. Defaults to 30.
  #
  # Returns JSON with:
  # - time_period: selected time period
  # - timeline: array of {date, value_cents} objects
  # - summary: {start_value_cents, end_value_cents, change_cents, percentage_change}
  def value_timeline
    time_period = normalize_time_period(params[:time_period])

    # Calculate inventory value timeline
    service = InventoryValueTimelineService.new(
      user: current_user,
      time_period: time_period
    )
    result = service.call

    render json: {
      time_period: time_period.to_s,
      timeline: serialize_timeline(result[:timeline]),
      summary: result[:summary]
    }
  end

  # Transfers a card from the user's wishlist to their inventory.
  # If an inventory row already exists for the card, its quantity is
  # incremented by the wishlist quantity.  The entire operation runs in a
  # single transaction so a failure after the wishlist deletion cannot
  # leave orphaned state.
  def move_from_wishlist
    card_id = params[:card_id]
    wishlist_item = current_user.collection_items.find_by(card_id: card_id, collection_type: "wishlist")

    unless wishlist_item
      render json: { error: "Not found in wishlist" }, status: :not_found
      return
    end

    inventory_item = CollectionItem.transaction do
      qty = wishlist_item.quantity
      wishlist_item.destroy!

      existing = current_user.collection_items.find_by(card_id: card_id, collection_type: "inventory")

      if existing
        existing.update!(quantity: existing.quantity + qty)
        existing
      else
        current_user.collection_items.create!(
          card_id: card_id,
          collection_type: "inventory",
          quantity: qty
        )
      end
    end

    render json: inventory_item, status: :created
  end

  private

  # Calculates inventory statistics for the entire collection.
  # Preloads prices and enriches all items to get accurate stats.
  def calculate_inventory_stats(base_items)
    # Preload prices for all items
    preload_prices(base_items)

    # Enrich all items with card details
    all_items_with_details = enrich_with_card_details(base_items)

    calculate_inventory_stats_from_enriched(all_items_with_details)
  end

  # Calculates inventory statistics using SQL aggregates for performance.
  # This method uses database queries instead of loading all items into memory.
  #
  # @param base_items [ActiveRecord::Relation] Scoped collection_items relation
  # @return [Hash] Stats hash with inventory metrics
  def calculate_inventory_stats_from_enriched(base_items)
    # Extract user_id and collection_type from the base relation for clean queries
    # Create fresh queries to avoid any inherited scope issues
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

    # Find most valuable card using SQL MAX aggregate
    most_valuable_query = base_query
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
        collection_items.card_name,
        (collection_items.quantity *
          CASE
            WHEN collection_items.finish = 'foil' THEN COALESCE(latest_price.usd_foil_cents, 0)
            WHEN collection_items.finish = 'etched' THEN COALESCE(latest_price.usd_etched_cents, 0)
            ELSE COALESCE(latest_price.usd_cents, 0)
          END
        ) AS total_price
      ")
      .order("total_price DESC")
      .limit(1)
      .take

    most_valuable_card = if most_valuable_query && most_valuable_query.total_price.to_i > 0
                          most_valuable_query.card_name
                        else
                          nil
                        end

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

    # Find most collected set using GROUP BY and COUNT
    most_collected_query = base_query
      .select("set_name, COUNT(*) as card_count")
      .group(:set_name)
      .order("card_count DESC")
      .limit(1)
      .take

    most_collected_set = most_collected_query&.set_name

    {
      most_valuable_card: most_valuable_card,
      total_value_cents: total_value_cents,
      cards_over_ten_dollars: cards_over_ten_dollars,
      total_sets: total_sets,
      most_collected_set: most_collected_set
    }
  end

  # Preloads CardPrice records for all items to prevent N+1 queries.
  # Fetches the latest price for each unique card_id in a single query
  # and caches them in memory for the request lifecycle.
  def preload_prices(items)
    return if items.empty?

    card_ids = items.map(&:card_id).uniq

    # Fetch the latest price for each card_id in a single query
    # Group by card_id to get the most recent price for each card
    latest_prices = CardPrice
      .where(card_id: card_ids)
      .group_by(&:card_id)
      .transform_values { |prices| prices.max_by(&:fetched_at) }

    # Memoize the prices in an instance variable for the request lifecycle
    @preloaded_prices = latest_prices
  end

  # Enriches collection items with card details from Scryfall API.
  # Uses CardDetailsService which implements caching to minimize API calls.
  # Filters out items where card details could not be retrieved.
  def enrich_with_card_details(items)
    items.map do |item|
      card_details = fetch_card_details(item.card_id)
      next if card_details.nil?

      serialize_item_with_details(item, card_details)
    end.compact
  end

  # Fetches card details from Scryfall with caching.
  # Returns nil if card not found or service encounters an error.
  def fetch_card_details(card_id)
    CardDetailsService.new(card_id: card_id).call
  rescue CardDetailsService::NetworkError, CardDetailsService::TimeoutError => e
    Rails.logger.warn("Failed to fetch card details for #{card_id}: #{e.message}")
    nil
  rescue CardDetailsService::RateLimitError => e
    Rails.logger.error("Scryfall rate limit exceeded: #{e.message}")
    nil
  end

  # Serializes a collection item with its card details and price data
  def serialize_item_with_details(item, card_details)
    # Use cached image URL if available, otherwise fall back to Scryfall
    image_url, image_cached = resolve_image_url(item, card_details[:image_url])

    # Get price data from preloaded cache if available, otherwise fetch from DB
    latest_price = @preloaded_prices&.dig(item.card_id) || item.latest_price
    unit_price = latest_price&.price_for_finish(item.finish)
    total_price = unit_price ? unit_price * item.quantity : nil
    price_updated_at = latest_price&.fetched_at

    {
      id: item.id,
      card_id: item.card_id,
      quantity: item.quantity,
      card_name: card_details[:name],
      set: card_details[:set],
      set_name: card_details[:set_name],
      collector_number: card_details[:collector_number],
      released_at: card_details[:released_at],
      image_url: image_url,
      image_cached: image_cached,
      acquired_date: item.acquired_date,
      acquired_price_cents: item.acquired_price_cents,
      finish: item.finish,
      language: item.language,
      unit_price_cents: unit_price,
      total_price_cents: total_price,
      price_updated_at: price_updated_at,
      created_at: item.created_at,
      updated_at: item.updated_at,
      user_id: item.user_id,
      collection_type: item.collection_type
    }
  end

  # Resolves the image URL for a collection item.
  # Returns [url, cached_flag] tuple.
  # If image is cached locally, returns Active Storage URL.
  # Otherwise returns Scryfall URL as fallback.
  def resolve_image_url(item, scryfall_url)
    if item.cached_image.attached?
      cached_url = rails_blob_url(item.cached_image, only_path: true)
      puts "Cached image: #{cached_url}"
      [ cached_url, true ]
    else
      puts "Scryfall image: #{scryfall_url}"
      [ scryfall_url, false ]
    end
  end

  # Verify the card exists in Scryfall before we persist anything.
  # When card_id is blank we let the model validation surface that error
  # instead of hitting Scryfall with an empty string.
  def validate_card_with_sdk
    return if card_id_param.blank?

    CardValidatorService.new(card_id_param).validate!
  rescue CardValidatorService::CardNotFoundError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # Enqueues background job to cache card image from Scryfall.
  # Fetches card details to get image URL, then enqueues CacheCardImageJob.
  # Failures are logged but don't block the inventory operation.
  def enqueue_image_cache_job
    card_details = fetch_card_details(card_id_param)
    return unless card_details && card_details[:image_url]

    # Find the collection item that was just created/updated
    item = current_user.collection_items.find_by(
      card_id: card_id_param,
      collection_type: "inventory"
    )
    return unless item

    CacheCardImageJob.perform_later(item.id, card_details[:image_url])
  rescue StandardError => e
    Rails.logger.error("Failed to enqueue image cache job: #{e.message}")
    # Don't raise - image caching is a performance optimization, not critical
  end

  def collection_type
    "inventory"
  end

  # Valid time period options for timeline queries
  VALID_TIME_PERIODS = [ 7, 30, 90 ].freeze
  DEFAULT_TIME_PERIOD = 30

  # Normalizes and validates the time_period parameter for value_timeline
  def normalize_time_period(period)
    normalized = period.to_i

    if VALID_TIME_PERIODS.include?(normalized)
      normalized
    else
      DEFAULT_TIME_PERIOD
    end
  end

  # Serializes timeline data points to JSON-friendly format
  def serialize_timeline(timeline)
    timeline.map do |point|
      {
        date: point[:date].iso8601,
        value_cents: point[:value_cents]
      }
    end
  end

  # Valid sort options for inventory
  VALID_SORT_OPTIONS = [
    "name-asc", "name-desc",
    "set-asc", "set-desc",
    "release-newest", "release-oldest",
    "value-high", "value-low",
    "date-newest", "date-oldest"
  ].freeze

  DEFAULT_SORT = "name-asc"

  # Normalizes and validates the sort parameter.
  # Returns a valid sort option or the default if invalid.
  def normalize_sort_param(sort)
    return DEFAULT_SORT if sort.blank?

    normalized = sort.to_s.strip.downcase

    if VALID_SORT_OPTIONS.include?(normalized)
      normalized
    else
      DEFAULT_SORT
    end
  end

  # Applies sorting to enriched inventory items based on sort option.
  # Items must already be enriched with card details and price data.
  def apply_sort(items, sort_option)
    case sort_option
    when "name-asc"
      items.sort_by { |item| item[:card_name]&.downcase || "" }
    when "name-desc"
      items.sort_by { |item| item[:card_name]&.downcase || "" }.reverse
    when "set-asc"
      items.sort_by { |item| item[:set_name]&.downcase || "" }
    when "set-desc"
      items.sort_by { |item| item[:set_name]&.downcase || "" }.reverse
    when "release-newest"
      items.sort_by { |item| item[:released_at] || "1900-01-01" }.reverse
    when "release-oldest"
      items.sort_by { |item| item[:released_at] || "9999-12-31" }
    when "value-high"
      items.sort_by { |item| item[:total_price_cents] || 0 }.reverse
    when "value-low"
      items.sort_by { |item| item[:total_price_cents] || 0 }
    when "date-newest"
      items.sort_by { |item| item[:created_at] }.reverse
    when "date-oldest"
      items.sort_by { |item| item[:created_at] }
    else
      # Fallback to default
      items.sort_by { |item| item[:card_name]&.downcase || "" }
    end
  end
end
