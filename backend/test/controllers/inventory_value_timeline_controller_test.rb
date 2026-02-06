require "test_helper"

class InventoryValueTimelineControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # RED Phase: Test inventory value timeline endpoint
  # ---------------------------------------------------------------------------

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  setup do
    CollectionItem.delete_all
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
    @card_id = "test-card-uuid-123"

    # Create inventory items
    @item1 = CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 2,
      treatment: "Normal"
    )

    # Create price history data spanning 90 days
    @price_90_days_ago = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 1000,
      fetched_at: 90.days.ago
    )

    @price_30_days_ago = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 1500,
      fetched_at: 30.days.ago
    )

    @price_7_days_ago = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 1800,
      fetched_at: 7.days.ago
    )

    @price_today = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 2000,
      fetched_at: Time.current
    )
  end

  # ---------------------------------------------------------------------------
  # Basic endpoint functionality
  # ---------------------------------------------------------------------------

  test "should get inventory value timeline" do
    get api_path("/inventory/value_timeline")

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
  end

  test "should return JSON with expected structure" do
    get api_path("/inventory/value_timeline")

    json_response = JSON.parse(response.body)

    assert_not_nil json_response["time_period"]
    assert_not_nil json_response["timeline"]
    assert_not_nil json_response["summary"]
  end

  test "should return timeline as array of date-value pairs" do
    get api_path("/inventory/value_timeline")

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    assert_kind_of Array, timeline
    assert_operator timeline.length, :>, 0

    # Check first data point structure
    first_point = timeline.first
    assert_not_nil first_point["date"]
    assert_not_nil first_point["value_cents"]
    assert_kind_of Integer, first_point["value_cents"]
  end

  # ---------------------------------------------------------------------------
  # Time period filtering tests
  # ---------------------------------------------------------------------------

  test "should return 7 days of timeline when time_period is 7" do
    get api_path("/inventory/value_timeline"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    assert_equal 8, timeline.length, "Should have 8 data points (day 0 to 7)"
    assert_equal "7", json_response["time_period"]
  end

  test "should return 30 days of timeline when time_period is 30" do
    get api_path("/inventory/value_timeline"), params: { time_period: 30 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    assert_equal 31, timeline.length, "Should have 31 data points (day 0 to 30)"
    assert_equal "30", json_response["time_period"]
  end

  test "should return 90 days of timeline when time_period is 90" do
    get api_path("/inventory/value_timeline"), params: { time_period: 90 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    assert_equal 91, timeline.length, "Should have 91 data points (day 0 to 90)"
    assert_equal "90", json_response["time_period"]
  end

  test "should default to 30 days when time_period not specified" do
    get api_path("/inventory/value_timeline")

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    assert_equal 31, timeline.length
    assert_equal "30", json_response["time_period"]
  end

  test "should handle invalid time_period parameter gracefully" do
    get api_path("/inventory/value_timeline"), params: { time_period: "invalid" }

    # Should default to 30 days
    json_response = JSON.parse(response.body)
    assert_equal "30", json_response["time_period"]
  end

  # ---------------------------------------------------------------------------
  # Data accuracy tests
  # ---------------------------------------------------------------------------

  test "should calculate correct inventory value based on current prices" do
    get api_path("/inventory/value_timeline"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    # Most recent value should reflect quantity * current price
    last_point = timeline.last
    expected_value = 2 * 2000 # 2 items at 2000 cents each

    assert_equal expected_value, last_point["value_cents"]
  end

  test "should return zero value for empty inventory" do
    # Remove all inventory items for the default user
    @user.collection_items.destroy_all

    get api_path("/inventory/value_timeline"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    timeline.each do |point|
      assert_equal 0, point["value_cents"]
    end
  end

  test "should only include inventory items, not wishlist" do
    # Add a wishlist item
    wishlist_card_id = "wishlist-card-uuid"
    CollectionItem.create!(
      user: @user,
      card_id: wishlist_card_id,
      collection_type: "wishlist",
      quantity: 100,
      treatment: "Normal"
    )

    CardPrice.create!(
      card_id: wishlist_card_id,
      usd_cents: 10000,
      fetched_at: Time.current
    )

    get api_path("/inventory/value_timeline"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    # Should not include wishlist value (100 * 10000)
    # Should only include inventory value (2 * 2000)
    last_point = timeline.last
    assert_equal 4000, last_point["value_cents"]
  end

  # ---------------------------------------------------------------------------
  # Summary statistics tests
  # ---------------------------------------------------------------------------

  test "should return summary with value change statistics" do
    get api_path("/inventory/value_timeline"), params: { time_period: 30 }

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    assert_not_nil summary["start_value_cents"]
    assert_not_nil summary["end_value_cents"]
    assert_not_nil summary["change_cents"]
    assert_not_nil summary["percentage_change"]
  end

  test "should calculate percentage change correctly" do
    # With our setup:
    # 30 days ago: 1500 cents * 2 = 3000 cents
    # Today: 2000 cents * 2 = 4000 cents
    # Change: (4000 - 3000) / 3000 * 100 = 33.33%

    get api_path("/inventory/value_timeline"), params: { time_period: 30 }

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    assert_equal 3000, summary["start_value_cents"]
    assert_equal 4000, summary["end_value_cents"]
    assert_equal 1000, summary["change_cents"]
    assert_in_delta 33.33, summary["percentage_change"], 0.01
  end

  test "should handle zero start value in percentage calculation" do
    # Clear existing items and add inventory with only recent prices
    @user.collection_items.destroy_all
    new_card_id = "new-card-uuid"

    # Add inventory item
    CollectionItem.create!(
      user: @user,
      card_id: new_card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    # Only add price for today (no historical prices)
    CardPrice.create!(
      card_id: new_card_id,
      usd_cents: 1000,
      fetched_at: Time.current
    )

    get api_path("/inventory/value_timeline"), params: { time_period: 30 }

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    # Should handle gracefully (not crash with division by zero)
    assert_not_nil summary["percentage_change"]
    assert_equal 0, summary["start_value_cents"]
    assert_equal 1000, summary["end_value_cents"]
  end

  # ---------------------------------------------------------------------------
  # Treatment types test
  # ---------------------------------------------------------------------------

  test "should handle different card treatments correctly" do
    foil_card_id = "foil-card-uuid"

    CollectionItem.create!(
      user: @user,
      card_id: foil_card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Foil"
    )

    CardPrice.create!(
      card_id: foil_card_id,
      usd_cents: 1000,
      usd_foil_cents: 3000,
      fetched_at: Time.current
    )

    get api_path("/inventory/value_timeline"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]
    last_point = timeline.last

    # Should include foil price (3000) + normal card value (2 * 2000)
    expected_value = 3000 + 4000
    assert_equal expected_value, last_point["value_cents"]
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  test "should handle missing price data gracefully" do
    # Create item with a card that has no price data
    no_price_card_id = "no-price-card-uuid"

    CollectionItem.create!(
      user: @user,
      card_id: no_price_card_id,
      collection_type: "inventory",
      quantity: 5,
      treatment: "Normal"
    )

    get api_path("/inventory/value_timeline"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)

    # Should still return data (items without prices contribute 0 value)
    assert_response :success
    assert_not_nil json_response["timeline"]
  end

  test "should handle increased quantity of same card" do
    # Update the existing item to increase quantity
    @item1.update!(quantity: 5)

    get api_path("/inventory/value_timeline"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]
    last_point = timeline.last

    # Total quantity should be 5
    expected_value = 5 * 2000
    assert_equal expected_value, last_point["value_cents"]
  end

  # ---------------------------------------------------------------------------
  # Data ordering tests
  # ---------------------------------------------------------------------------

  test "should return timeline ordered by date ASC" do
    get api_path("/inventory/value_timeline"), params: { time_period: 30 }

    json_response = JSON.parse(response.body)
    timeline = json_response["timeline"]

    # Verify ascending order
    dates = timeline.map { |p| Date.parse(p["date"]) }
    assert_equal dates, dates.sort
  end

  # ---------------------------------------------------------------------------
  # Performance tests
  # ---------------------------------------------------------------------------

  test "should respond in under 2 seconds for user with large inventory" do
    # Create 50 different inventory items
    50.times do |i|
      card_id = "performance-card-#{i}"

      CollectionItem.create!(
        user: @user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: rand(1..10),
        treatment: "Normal"
      )

      # Add some price history
      CardPrice.create!(
        card_id: card_id,
        usd_cents: 1000 + (i * 100),
        fetched_at: Time.current
      )
    end

    start_time = Time.current
    get api_path("/inventory/value_timeline"), params: { time_period: 30 }
    elapsed_time = Time.current - start_time

    assert_response :success
    # Should complete in under 2 seconds (can be optimized later)
    assert_operator elapsed_time, :<, 2.0, "Response took #{elapsed_time * 1000}ms, expected < 2000ms"
  end
end
