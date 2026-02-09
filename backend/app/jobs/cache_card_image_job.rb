# Background job to asynchronously cache card images from Scryfall.
# Triggered when cards are added to inventory to improve future page load performance.
class CacheCardImageJob < ApplicationJob
  include StructuredLogging

  queue_as :default

  # Caches a card image for the given collection item.
  # Failures are logged but do not raise exceptions to avoid blocking inventory operations.
  #
  # @param collection_item_id [Integer] The ID of the CollectionItem
  # @param image_url [String] The Scryfall image URL to cache
  def perform(collection_item_id, image_url)
    execution = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: collection_item_id,
      card_id: "unknown" # Will be updated if item is found
    )

    begin
      collection_item = find_collection_item(collection_item_id, execution)
      return unless collection_item

      cache_image(collection_item, image_url, execution)

      execution.update!(finished_at: Time.current)

      log_event(
        level: :info,
        event: "cache_completed",
        execution_id: execution.id,
        status: execution.status,
        downloaded: execution.downloaded,
        cache_hit: execution.cache_hit,
        duration_seconds: execution.execution_time_seconds
      )
    rescue StandardError => e
      execution.update!(
        finished_at: Time.current,
        status: :failure,
        error_message: e.message
      )

      log_error(
        error: e,
        execution_id: execution.id,
        collection_item_id: collection_item_id
      )

      # Don't raise - maintain non-blocking behavior
    end
  end

  private

  # Finds collection item by ID, returns nil if not found
  def find_collection_item(id, execution)
    item = CollectionItem.find_by(id: id)

    if item.nil?
      execution.update!(
        status: :skipped,
        finished_at: Time.current,
        error_message: "Collection item #{id} not found"
      )

      log_event(
        level: :warn,
        event: "collection_item_not_found",
        collection_item_id: id
      )

      return nil
    end

    # Update execution with actual card_id
    execution.update!(card_id: item.card_id)

    log_event(
      level: :info,
      event: "cache_started",
      execution_id: execution.id,
      collection_item_id: id,
      card_id: item.card_id
    )

    item
  rescue StandardError => e
    execution.update!(
      status: :skipped,
      finished_at: Time.current,
      error_message: "Error finding collection item: #{e.message}"
    )

    log_error(
      error: e,
      collection_item_id: id,
      context: "find_collection_item"
    )

    nil
  end

  # Caches image using CardImageCacheService and logs result
  def cache_image(collection_item, image_url, execution)
    service = CardImageCacheService.new(
      collection_item: collection_item,
      image_url: image_url
    )

    result = service.call

    log_and_update_execution(collection_item, result, execution)
  end

  # Logs the result and updates execution record
  def log_and_update_execution(collection_item, result, execution)
    if result[:success]
      if result[:downloaded]
        # Get file size from result or from attached image
        file_size = result[:file_size_bytes] || (collection_item.cached_image.byte_size rescue nil)

        execution.update!(
          status: :success,
          downloaded: true,
          cache_hit: false,
          file_size_bytes: file_size
        )

        log_event(
          level: :info,
          event: "image_downloaded",
          card_id: collection_item.card_id,
          file_size_bytes: file_size
        )
      elsif result[:cached]
        execution.update!(
          status: :success,
          downloaded: false,
          cache_hit: true
        )

        log_event(
          level: :info,
          event: "already_cached",
          card_id: collection_item.card_id,
          cache_hit: true
        )
      end
    else
      execution.update!(
        status: :failure,
        error_message: result[:error]
      )

      log_event(
        level: :warn,
        event: "cache_failed",
        card_id: collection_item.card_id,
        error_message: result[:error]
      )
    end
  end
end
