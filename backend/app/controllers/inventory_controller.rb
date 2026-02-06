class InventoryController < ApplicationController
  include CollectionItemActions

  before_action :validate_card_with_sdk, only: [ :create ]

  # Override create to enqueue image caching job after successful save
  def create
    super
    enqueue_image_cache_job if response.successful?
  end

  # Override index to include card details from Scryfall
  def index
    items = collection_items
    items_with_details = enrich_with_card_details(items)
    sorted_items = sort_by_card_name(items_with_details)
    render json: sorted_items
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
  # Uses treatment-based pricing (foil, etched, normal) and excludes cards without price data.
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

    # Get price data
    latest_price = item.latest_price
    unit_price = item.unit_price_cents
    total_price = item.total_price_cents
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
      treatment: item.treatment,
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

  # Sorts items alphabetically by card name
  def sort_by_card_name(items)
    items.sort_by { |item| item[:card_name]&.downcase || "" }
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
end
