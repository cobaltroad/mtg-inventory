require "test_helper"

class InventoryValueTimelineServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com", name: "Test User")
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Test calculating inventory value snapshots over time
  # ---------------------------------------------------------------------------

  test "calculates daily inventory value snapshots for the last 30 days" do
    # Create a collection item
    card_id = "test-card-uuid"
    collection_item = CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 2,
      treatment: "Normal"
    )

    # Create price history for the last 30 days
    30.downto(0) do |days_ago|
      date = days_ago.days.ago
      price_cents = 1000 + (days_ago * 10) # Price increasing over time

      CardPrice.create!(
        card_id: card_id,
        usd_cents: price_cents,
        fetched_at: date
      )
    end

    service = InventoryValueTimelineService.new(user: @user, time_period: 30)
    result = service.call

    assert_equal 31, result[:timeline].length, "Should have 31 data points (day 0 to 30)"

    # Verify first data point (30 days ago)
    first_point = result[:timeline].first
    assert_kind_of Date, first_point[:date]
    assert_equal 1300 * 2, first_point[:value_cents], "Should be (1000 + 30*10) * 2 quantity = 2600"

    # Verify last data point (today)
    last_point = result[:timeline].last
    assert_equal 1000 * 2, last_point[:value_cents], "Should be 1000 * 2 quantity = 2000"
  end

  test "handles empty inventory" do
    service = InventoryValueTimelineService.new(user: @user, time_period: 30)
    result = service.call

    assert_equal 31, result[:timeline].length
    result[:timeline].each do |point|
      assert_equal 0, point[:value_cents], "Empty inventory should have zero value"
    end
  end

  test "handles missing price data by using most recent available price" do
    card_id = "test-card-uuid"
    CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    # Only create price data for 15 days ago
    CardPrice.create!(
      card_id: card_id,
      usd_cents: 500,
      fetched_at: 15.days.ago
    )

    service = InventoryValueTimelineService.new(user: @user, time_period: 30)
    result = service.call

    # Days 30-16 should have no price data (0 value)
    result[:timeline][0..14].each do |point|
      assert_equal 0, point[:value_cents], "Should be 0 when no price data available"
    end

    # Days 15-0 should use the price from 15 days ago
    result[:timeline][15..30].each do |point|
      assert_equal 500, point[:value_cents], "Should use most recent available price"
    end
  end

  test "aggregates multiple collection items correctly" do
    # Create multiple cards
    card1_id = "test-card-1"
    card2_id = "test-card-2"

    CollectionItem.create!(
      user: @user,
      card_id: card1_id,
      collection_type: "inventory",
      quantity: 2,
      treatment: "Normal"
    )

    CollectionItem.create!(
      user: @user,
      card_id: card2_id,
      collection_type: "inventory",
      quantity: 3,
      treatment: "Foil"
    )

    # Create price data
    CardPrice.create!(
      card_id: card1_id,
      usd_cents: 1000,
      fetched_at: Time.current
    )

    CardPrice.create!(
      card_id: card2_id,
      usd_foil_cents: 2000,
      fetched_at: Time.current
    )

    service = InventoryValueTimelineService.new(user: @user, time_period: 7)
    result = service.call

    # Total value should be (2 * 1000) + (3 * 2000) = 8000 cents
    last_point = result[:timeline].last
    assert_equal 8000, last_point[:value_cents]
  end

  test "handles different treatment types correctly" do
    # Create items with different treatments using different cards
    normal_card_id = "test-card-normal"
    foil_card_id = "test-card-foil"
    etched_card_id = "test-card-etched"

    CollectionItem.create!(
      user: @user,
      card_id: normal_card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    CollectionItem.create!(
      user: @user,
      card_id: foil_card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Foil"
    )

    CollectionItem.create!(
      user: @user,
      card_id: etched_card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Etched"
    )

    # Create price data for each card
    CardPrice.create!(
      card_id: normal_card_id,
      usd_cents: 1000,
      fetched_at: Time.current
    )

    CardPrice.create!(
      card_id: foil_card_id,
      usd_foil_cents: 2000,
      fetched_at: Time.current
    )

    CardPrice.create!(
      card_id: etched_card_id,
      usd_etched_cents: 3000,
      fetched_at: Time.current
    )

    service = InventoryValueTimelineService.new(user: @user, time_period: 7)
    result = service.call

    # Total should be 1000 + 2000 + 3000 = 6000 cents
    last_point = result[:timeline].last
    assert_equal 6000, last_point[:value_cents]
  end

  test "only includes inventory items, not wishlist items" do
    card_id = "test-card-uuid"

    # Create inventory item
    CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    # Create wishlist item (should be excluded)
    CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "wishlist",
      quantity: 10,
      treatment: "Normal"
    )

    CardPrice.create!(
      card_id: card_id,
      usd_cents: 1000,
      fetched_at: Time.current
    )

    service = InventoryValueTimelineService.new(user: @user, time_period: 7)
    result = service.call

    # Should only count inventory item (1 * 1000), not wishlist (10 * 1000)
    last_point = result[:timeline].last
    assert_equal 1000, last_point[:value_cents]
  end

  test "returns summary statistics" do
    card_id = "test-card-uuid"
    CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    # Create price data showing value increase
    CardPrice.create!(
      card_id: card_id,
      usd_cents: 1000,
      fetched_at: 30.days.ago
    )

    CardPrice.create!(
      card_id: card_id,
      usd_cents: 1500,
      fetched_at: Time.current
    )

    service = InventoryValueTimelineService.new(user: @user, time_period: 30)
    result = service.call

    assert_not_nil result[:summary]
    assert_not_nil result[:summary][:start_value_cents]
    assert_not_nil result[:summary][:end_value_cents]
    assert_not_nil result[:summary][:change_cents]
    assert_not_nil result[:summary][:percentage_change]

    assert_equal 1000, result[:summary][:start_value_cents]
    assert_equal 1500, result[:summary][:end_value_cents]
    assert_equal 500, result[:summary][:change_cents]
    assert_equal 50.0, result[:summary][:percentage_change]
  end

  test "handles 7 day time period" do
    card_id = "test-card-uuid"
    CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    CardPrice.create!(
      card_id: card_id,
      usd_cents: 1000,
      fetched_at: Time.current
    )

    service = InventoryValueTimelineService.new(user: @user, time_period: 7)
    result = service.call

    assert_equal 8, result[:timeline].length, "Should have 8 data points (day 0 to 7)"
  end

  test "handles 90 day time period" do
    card_id = "test-card-uuid"
    CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    CardPrice.create!(
      card_id: card_id,
      usd_cents: 1000,
      fetched_at: Time.current
    )

    service = InventoryValueTimelineService.new(user: @user, time_period: 90)
    result = service.call

    assert_equal 91, result[:timeline].length, "Should have 91 data points (day 0 to 90)"
  end

  test "handles zero percentage change when start value is zero" do
    card_id = "test-card-uuid"
    CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    # No price data initially, then add price
    CardPrice.create!(
      card_id: card_id,
      usd_cents: 1000,
      fetched_at: Time.current
    )

    service = InventoryValueTimelineService.new(user: @user, time_period: 30)
    result = service.call

    # When start value is 0, percentage change should be 0 (or infinity handled gracefully)
    assert_not_nil result[:summary][:percentage_change]
  end
end
