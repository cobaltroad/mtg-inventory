namespace :analytics do
  desc "Consolidate EDHREC commander decklist analytics (rare/mythic cards only)"
  task consolidate_edhrec: :environment do
    puts "=" * 80
    puts "Consolidating EDHREC Analytics"
    puts "=" * 80
    puts ""
    puts "This task will:"
    puts "  - Fetch all commanders ordered by rank"
    puts "  - Extract rare/mythic cards from each decklist"
    puts "  - Aggregate cards by card_id into single analytics records"
    puts "  - Store commander inclusion data in array format"
    puts "  - Use upsert to merge with existing records"
    puts ""
    puts "Starting consolidation..."
    puts ""

    # Enqueue the job
    job = ConsolidateEdhrecAnalyticsJob.perform_now

    puts ""
    puts "=" * 80
    puts "Consolidation Complete"
    puts "=" * 80
    puts ""

    # Show summary statistics
    total_cards = CardAnalytic.for_source("edhrec").count
    rare_count = CardAnalytic.for_source("edhrec").where("usage_data->>'rarity' = ?", "rare").count
    mythic_count = CardAnalytic.for_source("edhrec").where("usage_data->>'rarity' = ?", "mythic").count

    puts "Summary:"
    puts "  Total unique cards: #{total_cards}"
    puts "  Rare cards: #{rare_count}"
    puts "  Mythic cards: #{mythic_count}"
    puts ""

    # Sample output
    if total_cards > 0
      puts "Sample cards (first 5):"
      CardAnalytic.for_source("edhrec").limit(5).each do |card|
        inclusions_count = card.usage_data.dig("commander_decklist_inclusion")&.count || 0
        puts "  - #{card.card_name} (#{card.usage_metric('rarity')}) - appears in #{inclusions_count} commander decklist(s)"
      end
      puts ""
    end

    puts "✓ Done! Analytics records stored in card_analytics table."
    puts ""
  end
end
