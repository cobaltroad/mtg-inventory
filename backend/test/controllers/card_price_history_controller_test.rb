require "test_helper"

class CardPriceHistoryControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # RED Phase: Test price history endpoint
  # ---------------------------------------------------------------------------

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  setup do
    @card_id = "test-card-uuid-123"

    # Create price history data spanning 1 year
    @price_1_year_ago = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 1000,
      usd_foil_cents: 2000,
      usd_etched_cents: 2500,
      fetched_at: 365.days.ago
    )

    @price_90_days_ago = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 1200,
      usd_foil_cents: 2200,
      usd_etched_cents: 2700,
      fetched_at: 90.days.ago
    )

    @price_30_days_ago = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 1500,
      usd_foil_cents: 2500,
      usd_etched_cents: 3000,
      fetched_at: 30.days.ago
    )

    @price_7_days_ago = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 1800,
      usd_foil_cents: 2800,
      usd_etched_cents: 3300,
      fetched_at: 7.days.ago
    )

    @price_today = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 2000,
      usd_foil_cents: 3000,
      usd_etched_cents: 3500,
      fetched_at: Time.current
    )

    # Create data for a different card to ensure filtering works
    @other_card_id = "other-card-uuid-456"
    @other_price = CardPrice.create!(
      card_id: @other_card_id,
      usd_cents: 5000,
      fetched_at: 1.day.ago
    )
  end

  # ---------------------------------------------------------------------------
  # Basic endpoint functionality
  # ---------------------------------------------------------------------------

  test "should get price history for card" do
    get api_path("/cards/#{@card_id}/price_history")

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
  end

  test "should return JSON with expected structure" do
    get api_path("/cards/#{@card_id}/price_history")

    json_response = JSON.parse(response.body)

    assert_not_nil json_response["card_id"]
    assert_not_nil json_response["time_period"]
    assert_not_nil json_response["prices"]
    assert_not_nil json_response["summary"]
  end

  # ---------------------------------------------------------------------------
  # Time period filtering tests
  # ---------------------------------------------------------------------------

  test "should return 7 days of history when time_period is 7" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # Should include prices from 7 days ago and today
    assert_equal 2, prices.length
    assert_equal "7", json_response["time_period"]
  end

  test "should return 30 days of history when time_period is 30" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: 30 }

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # Should include 30 days ago, 7 days ago, and today
    assert_equal 3, prices.length
    assert_equal "30", json_response["time_period"]
  end

  test "should return 90 days of history when time_period is 90" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: 90 }

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # Should include 90 days ago, 30 days ago, 7 days ago, and today
    assert_equal 4, prices.length
    assert_equal "90", json_response["time_period"]
  end

  test "should return 365 days of history when time_period is 365" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: 365 }

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # Should include all 5 price records
    assert_equal 5, prices.length
    assert_equal "365", json_response["time_period"]
  end

  test "should return all history when time_period is all" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: "all" }

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # Should include all 5 price records
    assert_equal 5, prices.length
    assert_equal "all", json_response["time_period"]
  end

  test "should default to 30 days when time_period not specified" do
    get api_path("/cards/#{@card_id}/price_history")

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # Should include 30 days ago, 7 days ago, and today
    assert_equal 3, prices.length
    assert_equal "30", json_response["time_period"]
  end

  # ---------------------------------------------------------------------------
  # Data ordering tests
  # ---------------------------------------------------------------------------

  test "should return prices ordered by fetched_at ASC for chart display" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: "all" }

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # First entry should be oldest
    assert_equal @price_1_year_ago.fetched_at.iso8601(3), prices.first["fetched_at"]

    # Last entry should be most recent
    assert_equal @price_today.fetched_at.iso8601(3), prices.last["fetched_at"]

    # Verify ascending order
    fetched_times = prices.map { |p| Time.parse(p["fetched_at"]) }
    assert_equal fetched_times, fetched_times.sort
  end

  # ---------------------------------------------------------------------------
  # Treatment data tests
  # ---------------------------------------------------------------------------

  test "should include all treatment prices in each record" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: 7 }

    json_response = JSON.parse(response.body)
    price_record = json_response["prices"].first

    assert_not_nil price_record["usd_cents"]
    assert_not_nil price_record["usd_foil_cents"]
    assert_not_nil price_record["usd_etched_cents"]
    assert_not_nil price_record["fetched_at"]
  end

  test "should handle nil treatment prices gracefully" do
    # Create a price with only normal treatment
    card_id_sparse = "sparse-card-uuid"
    CardPrice.create!(
      card_id: card_id_sparse,
      usd_cents: 1000,
      usd_foil_cents: nil,
      usd_etched_cents: nil,
      fetched_at: 1.day.ago
    )

    get api_path("/cards/#{card_id_sparse}/price_history")

    json_response = JSON.parse(response.body)
    price_record = json_response["prices"].first

    assert_equal 1000, price_record["usd_cents"]
    assert_nil price_record["usd_foil_cents"]
    assert_nil price_record["usd_etched_cents"]
  end

  # ---------------------------------------------------------------------------
  # Percentage change and summary tests
  # ---------------------------------------------------------------------------

  test "should calculate percentage change for normal treatment" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: "all" }

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    # From 1000 cents to 2000 cents = 100% increase
    assert_equal 100.0, summary["normal"]["percentage_change"]
    assert_equal "up", summary["normal"]["direction"]
    assert_equal 1000, summary["normal"]["start_price_cents"]
    assert_equal 2000, summary["normal"]["end_price_cents"]
  end

  test "should calculate percentage change for foil treatment" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: "all" }

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    # From 2000 cents to 3000 cents = 50% increase
    assert_equal 50.0, summary["foil"]["percentage_change"]
    assert_equal "up", summary["foil"]["direction"]
    assert_equal 2000, summary["foil"]["start_price_cents"]
    assert_equal 3000, summary["foil"]["end_price_cents"]
  end

  test "should calculate percentage change for etched treatment" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: "all" }

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    # From 2500 cents to 3500 cents = 40% increase
    assert_equal 40.0, summary["etched"]["percentage_change"]
    assert_equal "up", summary["etched"]["direction"]
    assert_equal 2500, summary["etched"]["start_price_cents"]
    assert_equal 3500, summary["etched"]["end_price_cents"]
  end

  test "should detect price decrease" do
    # Create a card with decreasing prices
    decreasing_card = "decreasing-card-uuid"
    CardPrice.create!(card_id: decreasing_card, usd_cents: 3000, fetched_at: 7.days.ago)
    CardPrice.create!(card_id: decreasing_card, usd_cents: 2000, fetched_at: Time.current)

    get api_path("/cards/#{decreasing_card}/price_history")

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    # From 3000 to 2000 = -33.33% decrease
    assert_in_delta(-33.33, summary["normal"]["percentage_change"], 0.01)
    assert_equal "down", summary["normal"]["direction"]
  end

  test "should detect no change in price" do
    # Create a card with stable prices
    stable_card = "stable-card-uuid"
    CardPrice.create!(card_id: stable_card, usd_cents: 2000, fetched_at: 7.days.ago)
    CardPrice.create!(card_id: stable_card, usd_cents: 2000, fetched_at: Time.current)

    get api_path("/cards/#{stable_card}/price_history")

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    assert_equal 0.0, summary["normal"]["percentage_change"]
    assert_equal "stable", summary["normal"]["direction"]
  end

  test "should handle treatment with no data in summary" do
    # Create a card with only normal prices
    normal_only_card = "normal-only-uuid"
    CardPrice.create!(
      card_id: normal_only_card,
      usd_cents: 1000,
      usd_foil_cents: nil,
      fetched_at: 7.days.ago
    )
    CardPrice.create!(
      card_id: normal_only_card,
      usd_cents: 1500,
      usd_foil_cents: nil,
      fetched_at: Time.current
    )

    get api_path("/cards/#{normal_only_card}/price_history")

    json_response = JSON.parse(response.body)
    summary = json_response["summary"]

    assert_not_nil summary["normal"]
    assert_nil summary["foil"]
    assert_nil summary["etched"]
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  test "should handle card with no price history" do
    nonexistent_card = "no-prices-uuid"

    get api_path("/cards/#{nonexistent_card}/price_history")

    assert_response :success
    json_response = JSON.parse(response.body)

    assert_equal nonexistent_card, json_response["card_id"]
    assert_empty json_response["prices"]
    assert_equal({}, json_response["summary"])
  end

  test "should handle card with single price record" do
    single_price_card = "single-price-uuid"
    CardPrice.create!(
      card_id: single_price_card,
      usd_cents: 1000,
      fetched_at: Time.current
    )

    get api_path("/cards/#{single_price_card}/price_history")

    json_response = JSON.parse(response.body)

    assert_equal 1, json_response["prices"].length
    # With single record, no change can be calculated
    assert_equal 0.0, json_response["summary"]["normal"]["percentage_change"]
    assert_equal "stable", json_response["summary"]["normal"]["direction"]
  end

  test "should handle sparse data with gaps" do
    sparse_card = "sparse-card-uuid"
    # Create prices with gaps (only 2 records in 90 days)
    CardPrice.create!(card_id: sparse_card, usd_cents: 1000, fetched_at: 90.days.ago)
    CardPrice.create!(card_id: sparse_card, usd_cents: 1500, fetched_at: Time.current)

    get api_path("/cards/#{sparse_card}/price_history"), params: { time_period: 90 }

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # Should only return the 2 actual records, no interpolation
    assert_equal 2, prices.length
  end

  test "should filter by card_id correctly" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: "all" }

    json_response = JSON.parse(response.body)
    prices = json_response["prices"]

    # Should only include prices for the requested card
    assert_equal 5, prices.length
    # Should not include the other card's price
    prices.each do |price|
      # All prices should be for our test card
      assert_includes [ 1000, 1200, 1500, 1800, 2000 ], price["usd_cents"]
    end
  end

  test "should handle invalid time_period parameter gracefully" do
    get api_path("/cards/#{@card_id}/price_history"), params: { time_period: "invalid" }

    # Should default to 30 days
    json_response = JSON.parse(response.body)
    assert_equal "30", json_response["time_period"]
  end

  # ---------------------------------------------------------------------------
  # Performance tests
  # ---------------------------------------------------------------------------

  test "should respond in under 200ms for large dataset" do
    # Create 100 price records
    large_card_id = "performance-test-card"
    100.times do |i|
      CardPrice.create!(
        card_id: large_card_id,
        usd_cents: 1000 + (i * 10),
        fetched_at: (100 - i).days.ago
      )
    end

    start_time = Time.current
    get api_path("/cards/#{large_card_id}/price_history"), params: { time_period: "all" }
    elapsed_time = Time.current - start_time

    assert_response :success
    # Should complete in under 200ms (0.2 seconds)
    assert_operator elapsed_time, :<, 0.2, "Response took #{elapsed_time * 1000}ms, expected < 200ms"
  end
end
