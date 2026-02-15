class ConsolidateEdhrecAnalyticsJob < ApplicationJob
  queue_as :default

  # ---------------------------------------------------------------------------
  # Consolidates rare/mythic cards from EDHREC commander decklists into
  # the card_analytics table for ML/analytics workflows.
  #
  # This is Phase 1 (Filtering) of the analytics pipeline:
  # - Fetches all commanders ordered by rank
  # - Extracts rare/mythic cards only from each decklist
  # - Aggregates cards by card_id into single records
  # - Stores commander_decklist_inclusion as an array (one element per commander)
  # - Uses upsert to merge data on subsequent runs
  # - Idempotent operation
  #
  # Arguments: None
  #
  # AC Requirements:
  # - AC1: Database table with proper schema
  # - AC2: CardAnalytic model with validations
  # - AC3: Job implementation with filtering, aggregation, upsert
  # - AC4: Array-based records (one record per card_id)
  # - AC6: Error handling for missing data
  # ---------------------------------------------------------------------------
  def perform
    Rails.logger.info("┌─ ConsolidateEdhrecAnalyticsJob: Starting analytics consolidation")

    commanders = Commander.order(:rank).includes(:decklists)
    Rails.logger.info("└─ Consolidating analytics for #{commanders.count} commanders")

    # Aggregate card data across all commanders
    card_aggregations = aggregate_cards_from_commanders(commanders)

    # Upsert consolidated records
    upsert_card_analytics(card_aggregations)

    Rails.logger.info("└─ ✓ Consolidation complete: #{card_aggregations.keys.count} unique rare/mythic cards processed")
  end

  private

  # ---------------------------------------------------------------------------
  # Aggregate cards from all commanders into a hash keyed by card_id
  # ---------------------------------------------------------------------------
  def aggregate_cards_from_commanders(commanders)
    card_aggregations = {}

    commanders.each_with_index do |commander, index|
      Rails.logger.info("  └─ Processing commander #{index + 1}/#{commanders.count}: #{commander.name} (Rank ##{commander.rank})")

      # Handle commanders with no decklists (AC6)
      next if commander.decklists.empty?

      commander.decklists.each do |decklist|
        # Handle empty contents (AC6)
        next if decklist.contents.blank?

        extract_rare_mythic_cards(decklist, commander, card_aggregations)
      end
    end

    card_aggregations
  end

  # ---------------------------------------------------------------------------
  # Extract rare/mythic cards from a decklist and add to aggregations
  # ---------------------------------------------------------------------------
  def extract_rare_mythic_cards(decklist, commander, card_aggregations)
    decklist.contents.each_with_index do |card, position|
      # Skip cards without rarity field (AC6)
      rarity = card["rarity"] || card[:rarity]
      next if rarity.blank?

      # Filter: only rare and mythic cards (AC3)
      next unless [ "rare", "mythic" ].include?(rarity.to_s.downcase)

      card_id = card["card_id"] || card[:card_id]
      card_name = card["card_name"] || card[:card_name]
      edh_rank = card["edh_rank"] || card[:edh_rank]

      # Skip cards without required fields (AC6)
      next if card_id.blank? || card_name.blank?

      # Initialize aggregation for this card if not present
      card_aggregations[card_id] ||= {
        card_id: card_id,
        card_name: card_name,
        rarity: rarity,
        inclusions: []
      }

      # Add commander inclusion to array (AC4)
      card_aggregations[card_id][:inclusions] << {
        commander_rank: commander.rank,
        commander_name: commander.name,
        edh_rank: edh_rank,
        deck_position: position,
        last_seen_at: Time.current.iso8601
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Upsert card analytics records
  # ---------------------------------------------------------------------------
  def upsert_card_analytics(card_aggregations)
    card_aggregations.each do |card_id, data|
      # Build usage_data structure (AC3)
      usage_data = {
        rarity: data[:rarity],
        commander_decklist_inclusion: data[:inclusions]
      }

      # Upsert record (AC3)
      # Note: Using empty string for strategy instead of nil because PostgreSQL
      # NULL values are not considered equal in unique constraints
      CardAnalytic.upsert(
        {
          card_id: card_id,
          card_name: data[:card_name],
          source: "edhrec",
          usage_data: usage_data,
          strategy: "", # Phase 1 uses empty string (nil won't work with unique constraint)
          computed_at: Time.current
        },
        unique_by: [ :card_id, :strategy ]
      )
    end
  end
end
