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

  # Serializes a collection item with its card details
  def serialize_item_with_details(item, card_details)
    # Use cached image URL if available, otherwise fall back to Scryfall
    image_url, image_cached = resolve_image_url(item, card_details[:image_url])

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
end
