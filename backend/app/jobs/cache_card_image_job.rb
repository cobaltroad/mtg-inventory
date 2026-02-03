# Background job to asynchronously cache card images from Scryfall.
# Triggered when cards are added to inventory to improve future page load performance.
class CacheCardImageJob < ApplicationJob
  queue_as :default

  # Caches a card image for the given collection item.
  # Failures are logged but do not raise exceptions to avoid blocking inventory operations.
  #
  # @param collection_item_id [Integer] The ID of the CollectionItem
  # @param image_url [String] The Scryfall image URL to cache
  def perform(collection_item_id, image_url)
    collection_item = find_collection_item(collection_item_id)
    return unless collection_item

    cache_image(collection_item, image_url)
  end

  private

  # Finds collection item by ID, returns nil if not found
  def find_collection_item(id)
    CollectionItem.find_by(id: id)
  rescue StandardError => e
    Rails.logger.error("CacheCardImageJob: Failed to find collection item #{id}: #{e.message}")
    nil
  end

  # Caches image using CardImageCacheService and logs result
  def cache_image(collection_item, image_url)
    service = CardImageCacheService.new(
      collection_item: collection_item,
      image_url: image_url
    )

    result = service.call

    log_result(collection_item, result)
  end

  # Logs the result of the caching operation
  def log_result(collection_item, result)
    if result[:success]
      if result[:downloaded]
        Rails.logger.info(
          "CacheCardImageJob: Successfully cached image for card #{collection_item.card_id}"
        )
      elsif result[:cached]
        Rails.logger.info(
          "CacheCardImageJob: Image already cached for card #{collection_item.card_id}"
        )
      end
    else
      Rails.logger.warn(
        "CacheCardImageJob: Failed to cache image for card #{collection_item.card_id}: #{result[:error]}"
      )
    end
  end
end
