require "test_helper"

class UsageSnapshotTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Presence validations (AC2)
  # ---------------------------------------------------------------------------
  test "is valid with all required attributes" do
    analytic = UsageSnapshot.new(
      card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      card_name: "Rhystic Study",
      source: "edhrec",
      usage_data: {
        "rarity" => "rare",
        "type" => "Enchantment",
        "commander_decklist_inclusion" => [
          {
            "commander_rank" => 1,
            "commander_name" => "Atraxa, Praetors' Voice",
            "edh_rank" => 265,
            "deck_position" => 3,
            "last_seen_at" => "2026-02-15T10:30:00Z"
          }
        ]
      },
      computed_at: Time.current
    )
    assert analytic.valid?, analytic.errors.full_messages.inspect
  end

  test "is invalid without card_id" do
    analytic = UsageSnapshot.new(
      card_id: nil,
      card_name: "Test Card",
      source: "edhrec",
      usage_data: { "rarity" => "rare", "type" => "Creature", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:card_id], "can't be blank"
  end

  test "is invalid without card_name" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: nil,
      source: "edhrec",
      usage_data: { "rarity" => "rare", "type" => "Land", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:card_name], "can't be blank"
  end

  test "is invalid without source" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: nil,
      usage_data: { "rarity" => "rare", "type" => "Sorcery", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:source], "can't be blank"
  end

  # ---------------------------------------------------------------------------
  # Source allowlist validation (AC2)
  # ---------------------------------------------------------------------------
  test "is valid with source 'edhrec'" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      usage_data: { "rarity" => "rare", "type" => "Instant", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert analytic.valid?, analytic.errors.full_messages.inspect
  end

  test "is invalid with source not in allowlist" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "invalid_source",
      usage_data: { "rarity" => "rare", "type" => "Artifact", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:source], "is not included in the list"
  end

  # ---------------------------------------------------------------------------
  # usage_data structure validation (AC2)
  # ---------------------------------------------------------------------------
  test "is invalid without usage_data" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      usage_data: nil,
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:usage_data], "can't be blank"
  end

  test "is invalid when usage_data is not a hash" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      usage_data: "invalid",
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:usage_data], "must be a hash"
  end

  test "is invalid when usage_data lacks commander_decklist_inclusion" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      usage_data: { "rarity" => "rare", "type" => "Land" },
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:usage_data], "must contain commander_decklist_inclusion array"
  end

  test "is invalid when commander_decklist_inclusion is not an array" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      usage_data: {
        "rarity" => "rare",
        "type" => "Creature",
        "commander_decklist_inclusion" => "not_an_array"
      },
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:usage_data], "commander_decklist_inclusion must be an array"
  end

  test "is invalid when usage_data lacks rarity" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      usage_data: { "type" => "Planeswalker", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:usage_data], "must contain rarity"
  end

  test "is invalid when usage_data lacks type" do
    analytic = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      usage_data: { "rarity" => "rare", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert analytic.invalid?
    assert_includes analytic.errors[:usage_data], "must contain type"
  end

  # ---------------------------------------------------------------------------
  # Uniqueness constraint (AC1, AC4)
  # ---------------------------------------------------------------------------
  test "is invalid when another analytic exists with same card_id and strategy" do
    UsageSnapshot.create!(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      strategy: "test_strategy",
      usage_data: { "rarity" => "rare", "type" => "Artifact", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )

    duplicate = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card Updated",
      source: "edhrec",
      strategy: "test_strategy",
      usage_data: { "rarity" => "mythic", "type" => "Creature", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert duplicate.invalid?
    assert_includes duplicate.errors[:card_id], "has already been taken"
  end

  test "allows two analytics with same card_id but different strategy" do
    UsageSnapshot.create!(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      strategy: "strategy_one",
      usage_data: { "rarity" => "rare", "type" => "Enchantment", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )

    second = UsageSnapshot.new(
      card_id: "test-id",
      card_name: "Test Card",
      source: "edhrec",
      strategy: "strategy_two",
      usage_data: { "rarity" => "mythic", "type" => "Enchantment", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )
    assert second.valid?, second.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # Scopes (AC2)
  # ---------------------------------------------------------------------------
  test "for_source scope returns analytics for given source" do
    edhrec_analytic = UsageSnapshot.create!(
      card_id: "edhrec-card",
      card_name: "EDHREC Card",
      source: "edhrec",
      usage_data: { "rarity" => "rare", "type" => "Sorcery", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )

    results = UsageSnapshot.for_source("edhrec")
    assert_includes results, edhrec_analytic
  end

  test "by_strategy scope returns analytics for given strategy" do
    strategy_analytic = UsageSnapshot.create!(
      card_id: "strategy-card",
      card_name: "Strategy Card",
      source: "edhrec",
      strategy: "test_strategy",
      usage_data: { "rarity" => "rare", "type" => "Instant", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )

    results = UsageSnapshot.by_strategy("test_strategy")
    assert_includes results, strategy_analytic
  end

  test "with_tag scope returns analytics containing given tag" do
    tagged_analytic = UsageSnapshot.create!(
      card_id: "tagged-card",
      card_name: "Tagged Card",
      source: "edhrec",
      tags: [ "staple", "removal" ],
      usage_data: { "rarity" => "rare", "type" => "Instant", "commander_decklist_inclusion" => [] },
      computed_at: Time.current
    )

    results = UsageSnapshot.with_tag("staple")
    assert_includes results, tagged_analytic

    results = UsageSnapshot.with_tag("removal")
    assert_includes results, tagged_analytic

    results = UsageSnapshot.with_tag("nonexistent")
    assert_not_includes results, tagged_analytic
  end

  # ---------------------------------------------------------------------------
  # Helper methods (AC2)
  # ---------------------------------------------------------------------------
  test "usage_metric returns specific metric from usage_data" do
    analytic = UsageSnapshot.create!(
      card_id: "metric-card",
      card_name: "Metric Card",
      source: "edhrec",
      usage_data: {
        "rarity" => "mythic",
        "type" => "Planeswalker",
        "commander_decklist_inclusion" => [
          { "commander_rank" => 5, "edh_rank" => 100 }
        ]
      },
      computed_at: Time.current
    )

    assert_equal "mythic", analytic.usage_metric("rarity")
    assert_equal "Planeswalker", analytic.usage_metric("type")
    assert_equal [{ "commander_rank" => 5, "edh_rank" => 100 }],
                 analytic.usage_metric("commander_decklist_inclusion")
    assert_nil analytic.usage_metric("nonexistent_key")
  end

  test "all_rarities returns unique rarities from commander_decklist_inclusion" do
    analytic = UsageSnapshot.create!(
      card_id: "rarity-card",
      card_name: "Rarity Card",
      source: "edhrec",
      usage_data: {
        "rarity" => "rare",
        "type" => "Artifact",
        "commander_decklist_inclusion" => []
      },
      computed_at: Time.current
    )

    # Single rarity
    assert_equal [ "rare" ], analytic.all_rarities
  end

  test "card_type returns type from usage_data" do
    analytic = UsageSnapshot.create!(
      card_id: "type-card",
      card_name: "Type Card",
      source: "edhrec",
      usage_data: {
        "rarity" => "mythic",
        "type" => "Planeswalker",
        "commander_decklist_inclusion" => []
      },
      computed_at: Time.current
    )

    assert_equal "Planeswalker", analytic.card_type
  end

  test "card_type returns nil when type is not present" do
    # Create analytic without type for testing
    analytic = UsageSnapshot.new(
      card_id: "no-type-card",
      card_name: "No Type Card",
      source: "edhrec",
      usage_data: {
        "rarity" => "rare",
        "commander_decklist_inclusion" => []
      },
      computed_at: Time.current
    )

    # Skip validation to test the helper method directly
    analytic.save(validate: false)

    assert_nil analytic.card_type
  end

  # ---------------------------------------------------------------------------
  # Array-based records (AC4)
  # ---------------------------------------------------------------------------
  test "supports multiple commanders in commander_decklist_inclusion array" do
    analytic = UsageSnapshot.create!(
      card_id: "multi-commander-card",
      card_name: "Multi Commander Card",
      source: "edhrec",
      usage_data: {
        "rarity" => "mythic",
        "type" => "Creature",
        "commander_decklist_inclusion" => [
          {
            "commander_rank" => 1,
            "commander_name" => "Commander A",
            "edh_rank" => 100,
            "deck_position" => 5,
            "last_seen_at" => "2026-02-15T10:00:00Z"
          },
          {
            "commander_rank" => 2,
            "commander_name" => "Commander B",
            "edh_rank" => 150,
            "deck_position" => 10,
            "last_seen_at" => "2026-02-15T11:00:00Z"
          }
        ]
      },
      computed_at: Time.current
    )

    inclusions = analytic.usage_metric("commander_decklist_inclusion")
    assert_equal 2, inclusions.length
    assert_equal "Commander A", inclusions[0]["commander_name"]
    assert_equal "Commander B", inclusions[1]["commander_name"]
  end
end
