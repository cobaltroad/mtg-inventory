class WishlistController < ApplicationController
  include CollectionItemActions

  before_action :validate_card_with_sdk, only: [ :create ]

  # Override index to include card details from Scryfall
  def index
    items = collection_items
    preload_prices(items)
    items_with_details = enrich_with_card_details(items)
    sorted_items = sort_by_card_name(items_with_details)
    render json: sorted_items
  end

  private

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

  # Serializes a wishlist item with card details and price data.
  # Excludes acquired_date and acquired_price_cents as wishlist items don't have these.
  def serialize_item_with_details(item, card_details)
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
      image_url: card_details[:image_url],
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

  def collection_type
    "wishlist"
  end
end
