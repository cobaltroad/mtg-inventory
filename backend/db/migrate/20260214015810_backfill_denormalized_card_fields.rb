class BackfillDenormalizedCardFields < ActiveRecord::Migration[8.1]
  # Backfill denormalized card fields for existing collection_items.
  # Uses batching and rate limiting to respect Scryfall API limits.
  #
  # This is a data migration that:
  # 1. Finds all collection_items with nil denormalized fields
  # 2. Fetches card details from Scryfall (with caching)
  # 3. Updates records in batches of 100
  # 4. Adds small delay between batches to respect rate limits
  #
  # Safe to run multiple times (idempotent) - skips already-backfilled records.

  def up
    puts "\n=== Backfilling denormalized card fields ==="

    # Find items needing backfill
    items_to_backfill = CollectionItem
      .where("card_name IS NULL OR set_name IS NULL OR released_at IS NULL")
      .order(:id)

    total_count = items_to_backfill.count
    puts "Found #{total_count} items needing backfill"

    return if total_count.zero?

    # Process in batches to avoid memory issues
    batch_size = 100
    processed = 0
    failed = 0
    batch_num = 0

    items_to_backfill.find_in_batches(batch_size: batch_size) do |batch|
      batch_num += 1
      puts "\nProcessing batch #{batch_num} (#{batch.size} items)..."

      batch.each do |item|
        begin
          # Fetch card details from Scryfall (uses cache if available)
          card_details = CardDetailsService.new(card_id: item.card_id).call

          if card_details
            item.update_columns(
              card_name: card_details[:name],
              set_name: card_details[:set_name],
              released_at: card_details[:released_at] ? Date.parse(card_details[:released_at]) : nil
            )
            processed += 1
            print "."
          else
            puts "\nWarning: No card details found for #{item.card_id}"
            failed += 1
          end
        rescue StandardError => e
          puts "\nError processing item #{item.id} (card_id: #{item.card_id}): #{e.message}"
          failed += 1
        end
      end

      # Rate limiting: small delay between batches
      # Scryfall allows ~10 requests/second, cache should handle most
      if batch_num < (total_count.to_f / batch_size).ceil
        sleep 0.5  # 500ms delay between batches
      end
    end

    puts "\n\n=== Backfill complete ==="
    puts "Successfully processed: #{processed}"
    puts "Failed: #{failed}"
    puts "Total: #{total_count}"
  end

  def down
    # Reversing this migration would null out the denormalized fields
    # Since the data can be regenerated via the model callback, we don't
    # need to implement down migration. If needed, columns will be removed
    # by reversing the AddDenormalizedCardFieldsToCollectionItems migration.
    puts "Note: This data migration cannot be reversed. Denormalized fields will remain populated."
  end
end
