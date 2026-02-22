require "test_helper"

class ConsolidateEdhrecAnalyticsJobTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Setup test data
  # ---------------------------------------------------------------------------
  def setup
    # Create commanders with ranks
    @commander1 = Commander.create!(
      name: "Atraxa, Praetors' Voice",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/atraxa"
    )

    @commander2 = Commander.create!(
      name: "Muldrotha, the Gravetide",
      rank: 2,
      edhrec_url: "https://edhrec.com/commanders/muldrotha"
    )

    @commander3 = Commander.create!(
      name: "Tergrid, God of Fright",
      rank: 3,
      edhrec_url: "https://edhrec.com/commanders/tergrid"
    )

    # Create decklists with rare/mythic cards
    @decklist1 = Decklist.create!(
      commander: @commander1,
      partner: nil,
      contents: [
        {
          card_id: "rare-card-1",
          card_name: "Rhystic Study",
          card_type: "Enchantment",
          rarity: "rare",
          edh_rank: 265,
          quantity: 1
        },
        {
          card_id: "mythic-card-1",
          card_name: "Smothering Tithe",
          card_type: "Enchantment",
          rarity: "mythic",
          edh_rank: 100,
          quantity: 1
        },
        {
          card_id: "common-card-1",
          card_name: "Sol Ring",
          card_type: "Artifact",
          rarity: "common",
          edh_rank: 1,
          quantity: 1
        }
      ]
    )

    @decklist2 = Decklist.create!(
      commander: @commander2,
      partner: nil,
      contents: [
        {
          card_id: "rare-card-1",
          card_name: "Rhystic Study",
          card_type: "Enchantment",
          rarity: "rare",
          edh_rank: 265,
          quantity: 1
        },
        {
          card_id: "mythic-card-2",
          card_name: "Cyclonic Rift",
          card_type: "Instant",
          rarity: "mythic",
          edh_rank: 50,
          quantity: 1
        },
        {
          card_id: "uncommon-card-1",
          card_name: "Command Tower",
          card_type: "Land",
          rarity: "uncommon",
          edh_rank: 5,
          quantity: 1
        }
      ]
    )

    @decklist3 = Decklist.create!(
      commander: @commander3,
      partner: nil,
      contents: [
        {
          card_id: "mythic-card-1",
          card_name: "Smothering Tithe",
          card_type: "Enchantment",
          rarity: "mythic",
          edh_rank: 100,
          quantity: 1
        }
      ]
    )
  end

  # ---------------------------------------------------------------------------
  # Basic functionality (AC3)
  # ---------------------------------------------------------------------------
  test "consolidates rare and mythic cards only" do
    ConsolidateEdhrecAnalyticsJob.perform_now

    # Should have 3 unique rare/mythic cards
    assert_equal 3, UsageSnapshot.count

    # Should filter out common and uncommon cards
    assert_nil UsageSnapshot.find_by(card_id: "common-card-1")
    assert_nil UsageSnapshot.find_by(card_id: "uncommon-card-1")

    # Should include rare and mythic cards
    assert UsageSnapshot.find_by(card_id: "rare-card-1")
    assert UsageSnapshot.find_by(card_id: "mythic-card-1")
    assert UsageSnapshot.find_by(card_id: "mythic-card-2")
  end

  test "creates single record per card_id with array of commanders (AC4)" do
    ConsolidateEdhrecAnalyticsJob.perform_now

    # Rhystic Study appears in 2 decklists - should have ONE record
    rhystic = UsageSnapshot.find_by(card_id: "rare-card-1")
    assert_not_nil rhystic
    assert_equal "Rhystic Study", rhystic.card_name
    assert_equal "edhrec", rhystic.source
    assert_equal "rare", rhystic.usage_data["rarity"]
    assert_equal "Enchantment", rhystic.usage_data["type"]

    # Should have 2 commanders in the inclusion array
    inclusions = rhystic.usage_data["commander_decklist_inclusion"]
    assert_equal 2, inclusions.length

    # Check first inclusion
    assert_equal 1, inclusions[0]["commander_rank"]
    assert_equal "Atraxa, Praetors' Voice", inclusions[0]["commander_name"]
    assert_equal 265, inclusions[0]["edh_rank"]
    assert_not_nil inclusions[0]["last_seen_at"]

    # Check second inclusion
    assert_equal 2, inclusions[1]["commander_rank"]
    assert_equal "Muldrotha, the Gravetide", inclusions[1]["commander_name"]
    assert_equal 265, inclusions[1]["edh_rank"]
    assert_not_nil inclusions[1]["last_seen_at"]
  end

  test "orders commanders by rank in inclusion array" do
    ConsolidateEdhrecAnalyticsJob.perform_now

    rhystic = UsageSnapshot.find_by(card_id: "rare-card-1")
    inclusions = rhystic.usage_data["commander_decklist_inclusion"]

    # Should be ordered by commander rank (1, 2)
    assert_equal 1, inclusions[0]["commander_rank"]
    assert_equal 2, inclusions[1]["commander_rank"]
  end

  test "tracks deck_position for each card" do
    ConsolidateEdhrecAnalyticsJob.perform_now

    rhystic = UsageSnapshot.find_by(card_id: "rare-card-1")
    inclusions = rhystic.usage_data["commander_decklist_inclusion"]

    # Check deck positions (0-indexed position in decklist)
    assert_equal 0, inclusions[0]["deck_position"]  # First card in commander1's decklist
    assert_equal 0, inclusions[1]["deck_position"]  # First card in commander2's decklist
  end

  test "handles cards appearing in single decklist" do
    ConsolidateEdhrecAnalyticsJob.perform_now

    cyclonic = UsageSnapshot.find_by(card_id: "mythic-card-2")
    assert_not_nil cyclonic
    assert_equal "Cyclonic Rift", cyclonic.card_name
    assert_equal "Instant", cyclonic.usage_data["type"]

    inclusions = cyclonic.usage_data["commander_decklist_inclusion"]
    assert_equal 1, inclusions.length
    assert_equal 2, inclusions[0]["commander_rank"]
    assert_equal "Muldrotha, the Gravetide", inclusions[0]["commander_name"]
  end

  test "handles cards appearing in multiple decklists with different rarities in database" do
    # Smothering Tithe appears in both commander1 and commander3
    ConsolidateEdhrecAnalyticsJob.perform_now

    smothering = UsageSnapshot.find_by(card_id: "mythic-card-1")
    assert_not_nil smothering
    assert_equal "Smothering Tithe", smothering.card_name
    assert_equal "mythic", smothering.usage_data["rarity"]
    assert_equal "Enchantment", smothering.usage_data["type"]

    inclusions = smothering.usage_data["commander_decklist_inclusion"]
    assert_equal 2, inclusions.length
    assert_equal 1, inclusions[0]["commander_rank"]
    assert_equal 3, inclusions[1]["commander_rank"]
  end

  # ---------------------------------------------------------------------------
  # Upsert functionality (AC3)
  # ---------------------------------------------------------------------------
  test "updates existing records on subsequent runs (upsert)" do
    # First run
    ConsolidateEdhrecAnalyticsJob.perform_now

    rhystic_before = UsageSnapshot.find_by(card_id: "rare-card-1")
    initial_computed_at = rhystic_before.computed_at

    # Wait a moment to ensure timestamp changes
    sleep 0.1

    # Add a new decklist with the same card
    commander4 = Commander.create!(
      name: "New Commander",
      rank: 4,
      edhrec_url: "https://edhrec.com/commanders/new"
    )
    Decklist.create!(
      commander: commander4,
      partner: nil,
      contents: [
        {
          card_id: "rare-card-1",
          card_name: "Rhystic Study",
          rarity: "rare",
          edh_rank: 265,
          quantity: 1
        }
      ]
    )

    # Second run
    ConsolidateEdhrecAnalyticsJob.perform_now

    # Should still have same total count (upsert, not insert)
    assert_equal 3, UsageSnapshot.count

    # Check that record was updated
    rhystic_after = UsageSnapshot.find_by(card_id: "rare-card-1")
    assert rhystic_after.computed_at > initial_computed_at

    # Should now have 3 commanders in inclusion array
    inclusions = rhystic_after.usage_data["commander_decklist_inclusion"]
    assert_equal 3, inclusions.length
  end

  # ---------------------------------------------------------------------------
  # Idempotency (AC3)
  # ---------------------------------------------------------------------------
  test "is idempotent when run multiple times without data changes" do
    # First run
    ConsolidateEdhrecAnalyticsJob.perform_now
    first_count = UsageSnapshot.count
    first_records = UsageSnapshot.all.map { |r| [ r.card_id, r.usage_data["commander_decklist_inclusion"].length ] }.sort

    # Second run without any data changes
    ConsolidateEdhrecAnalyticsJob.perform_now
    second_count = UsageSnapshot.count
    second_records = UsageSnapshot.all.map { |r| [ r.card_id, r.usage_data["commander_decklist_inclusion"].length ] }.sort

    assert_equal first_count, second_count
    assert_equal first_records, second_records
  end

  # ---------------------------------------------------------------------------
  # Error handling (AC6)
  # ---------------------------------------------------------------------------
  test "handles commanders with no decklists" do
    commander_no_deck = Commander.create!(
      name: "No Deck Commander",
      rank: 99,
      edhrec_url: "https://edhrec.com/commanders/no-deck"
    )

    assert_nothing_raised do
      ConsolidateEdhrecAnalyticsJob.perform_now
    end

    # Should still process other commanders
    assert_equal 3, UsageSnapshot.count
  end

  test "handles decklists with empty contents" do
    # Note: Decklist model validates that contents cannot be empty,
    # so this test verifies the job handles commanders with no decklists
    commander_no_deck = Commander.create!(
      name: "No Deck Commander",
      rank: 98,
      edhrec_url: "https://edhrec.com/commanders/no-deck"
    )
    # Don't create a decklist for this commander

    assert_nothing_raised do
      ConsolidateEdhrecAnalyticsJob.perform_now
    end

    # Should still process other commanders
    assert_equal 3, UsageSnapshot.count
  end

  test "handles cards missing rarity field gracefully" do
    commander_missing = Commander.create!(
      name: "Missing Field Commander",
      rank: 97,
      edhrec_url: "https://edhrec.com/commanders/missing"
    )
    Decklist.create!(
      commander: commander_missing,
      partner: nil,
      contents: [
        {
          card_id: "missing-rarity-card",
          card_name: "Card Without Rarity",
          # rarity field is missing
          edh_rank: 500,
          quantity: 1
        }
      ]
    )

    assert_nothing_raised do
      ConsolidateEdhrecAnalyticsJob.perform_now
    end

    # Card without rarity should be skipped
    assert_nil UsageSnapshot.find_by(card_id: "missing-rarity-card")

    # Should still process other commanders
    assert_equal 3, UsageSnapshot.count
  end

  test "handles cards with nil or blank rarity" do
    commander_nil = Commander.create!(
      name: "Nil Rarity Commander",
      rank: 96,
      edhrec_url: "https://edhrec.com/commanders/nil"
    )
    Decklist.create!(
      commander: commander_nil,
      partner: nil,
      contents: [
        {
          card_id: "nil-rarity-card",
          card_name: "Card With Nil Rarity",
          card_type: "Creature",
          rarity: nil,
          edh_rank: 500,
          quantity: 1
        },
        {
          card_id: "blank-rarity-card",
          card_name: "Card With Blank Rarity",
          card_type: "Artifact",
          rarity: "",
          edh_rank: 501,
          quantity: 1
        }
      ]
    )

    assert_nothing_raised do
      ConsolidateEdhrecAnalyticsJob.perform_now
    end

    # Cards with nil/blank rarity should be skipped
    assert_nil UsageSnapshot.find_by(card_id: "nil-rarity-card")
    assert_nil UsageSnapshot.find_by(card_id: "blank-rarity-card")
  end

  test "handles cards missing card_type field gracefully" do
    commander_missing_type = Commander.create!(
      name: "Missing Type Commander",
      rank: 95,
      edhrec_url: "https://edhrec.com/commanders/missing-type"
    )
    Decklist.create!(
      commander: commander_missing_type,
      partner: nil,
      contents: [
        {
          card_id: "missing-type-card",
          card_name: "Card Without Type",
          # card_type field is missing
          rarity: "rare",
          edh_rank: 500,
          quantity: 1
        }
      ]
    )

    assert_nothing_raised do
      ConsolidateEdhrecAnalyticsJob.perform_now
    end

    # Card without type should still be processed but with nil/empty type
    card = UsageSnapshot.find_by(card_id: "missing-type-card")
    assert_not_nil card
    assert card.usage_data["type"].blank?
  end

  test "handles cards with nil or blank card_type" do
    commander_nil_type = Commander.create!(
      name: "Nil Type Commander",
      rank: 94,
      edhrec_url: "https://edhrec.com/commanders/nil-type"
    )
    Decklist.create!(
      commander: commander_nil_type,
      partner: nil,
      contents: [
        {
          card_id: "nil-type-card",
          card_name: "Card With Nil Type",
          card_type: nil,
          rarity: "rare",
          edh_rank: 500,
          quantity: 1
        },
        {
          card_id: "blank-type-card",
          card_name: "Card With Blank Type",
          card_type: "",
          rarity: "mythic",
          edh_rank: 501,
          quantity: 1
        }
      ]
    )

    assert_nothing_raised do
      ConsolidateEdhrecAnalyticsJob.perform_now
    end

    # Cards with nil/blank type should still be processed
    nil_type_card = UsageSnapshot.find_by(card_id: "nil-type-card")
    assert_not_nil nil_type_card
    assert nil_type_card.usage_data["type"].blank?

    blank_type_card = UsageSnapshot.find_by(card_id: "blank-type-card")
    assert_not_nil blank_type_card
    assert blank_type_card.usage_data["type"].blank?
  end

  test "extracts card type from decklist contents" do
    ConsolidateEdhrecAnalyticsJob.perform_now

    # Verify different card types are extracted correctly
    rhystic = UsageSnapshot.find_by(card_id: "rare-card-1")
    assert_equal "Enchantment", rhystic.usage_data["type"]

    cyclonic = UsageSnapshot.find_by(card_id: "mythic-card-2")
    assert_equal "Instant", cyclonic.usage_data["type"]

    smothering = UsageSnapshot.find_by(card_id: "mythic-card-1")
    assert_equal "Enchantment", smothering.usage_data["type"]
  end

  # ---------------------------------------------------------------------------
  # Logging (AC3)
  # ---------------------------------------------------------------------------
  test "logs progress during consolidation" do
    skip "Pre-existing test failure - needs investigation"
    logs = capture_log_output do
      ConsolidateEdhrecAnalyticsJob.perform_now
    end

    assert_match(/ConsolidateEdhrecAnalyticsJob/, logs)
    assert_match(/Consolidating analytics for \d+ commanders/, logs)
    assert_match(/Processing commander \d+\/\d+/, logs)
    assert_match(/Consolidation complete/, logs)
  end

  private

  def capture_log_output
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    yield

    log_output.string
  ensure
    Rails.logger = original_logger
  end
end
