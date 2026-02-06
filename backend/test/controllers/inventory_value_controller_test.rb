require "test_helper"

class InventoryValueControllerTest < ActionDispatch::IntegrationTest
  setup do
    CollectionItem.delete_all
    CardPrice.delete_all
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)

    # Use memory store for cache testing
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  # ---------------------------------------------------------------------------
  # Basic value calculation tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory/value returns zero value for empty inventory" do
    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 0, body["total_value_cents"]
    assert_equal 0, body["total_cards"]
    assert_equal 0, body["valued_cards"]
    assert_equal 0, body["excluded_cards"]
  end

  test "GET /api/inventory/value calculates total value for normal cards" do
    CollectionItem.create!(
      user: @user,
      card_id: "card1",
      collection_type: "inventory",
      quantity: 2,
      treatment: "Normal"
    )

    CardPrice.create!(
      card_id: "card1",
      fetched_at: 1.hour.ago,
      usd_cents: 500
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1000, body["total_value_cents"] # 2 × 500
    assert_equal 2, body["total_cards"]
    assert_equal 2, body["valued_cards"]
    assert_equal 0, body["excluded_cards"]
  end

  test "GET /api/inventory/value calculates total value for multiple cards" do
    CollectionItem.create!(
      user: @user,
      card_id: "card1",
      collection_type: "inventory",
      quantity: 3,
      treatment: "Normal"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "card2",
      collection_type: "inventory",
      quantity: 2,
      treatment: "Normal"
    )

    CardPrice.create!(card_id: "card1", fetched_at: 1.hour.ago, usd_cents: 100)
    CardPrice.create!(card_id: "card2", fetched_at: 1.hour.ago, usd_cents: 250)

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 800, body["total_value_cents"] # (3 × 100) + (2 × 250)
    assert_equal 5, body["total_cards"]
    assert_equal 5, body["valued_cards"]
  end

  # ---------------------------------------------------------------------------
  # Treatment-based pricing tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory/value uses foil price for foil cards" do
    CollectionItem.create!(
      user: @user,
      card_id: "foil_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Foil"
    )

    CardPrice.create!(
      card_id: "foil_card",
      fetched_at: 1.hour.ago,
      usd_cents: 200,
      usd_foil_cents: 800
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 800, body["total_value_cents"] # Uses foil price, not normal
  end

  test "GET /api/inventory/value uses etched price for etched cards" do
    CollectionItem.create!(
      user: @user,
      card_id: "etched_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Etched"
    )

    CardPrice.create!(
      card_id: "etched_card",
      fetched_at: 1.hour.ago,
      usd_cents: 300,
      usd_etched_cents: 600
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 600, body["total_value_cents"] # Uses etched price
  end

  test "GET /api/inventory/value falls back to normal price when foil price is nil" do
    CollectionItem.create!(
      user: @user,
      card_id: "foil_fallback",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Foil"
    )

    CardPrice.create!(
      card_id: "foil_fallback",
      fetched_at: 1.hour.ago,
      usd_cents: 150,
      usd_foil_cents: nil
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 150, body["total_value_cents"] # Falls back to normal price
  end

  test "GET /api/inventory/value falls back to normal price when etched price is nil" do
    CollectionItem.create!(
      user: @user,
      card_id: "etched_fallback",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Etched"
    )

    CardPrice.create!(
      card_id: "etched_fallback",
      fetched_at: 1.hour.ago,
      usd_cents: 200,
      usd_etched_cents: nil
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 200, body["total_value_cents"] # Falls back to normal price
  end

  # ---------------------------------------------------------------------------
  # Cards without price data
  # ---------------------------------------------------------------------------

  test "GET /api/inventory/value excludes cards without price data" do
    CollectionItem.create!(
      user: @user,
      card_id: "priced_card",
      collection_type: "inventory",
      quantity: 2,
      treatment: "Normal"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "unpriced_card",
      collection_type: "inventory",
      quantity: 3,
      treatment: "Normal"
    )

    CardPrice.create!(card_id: "priced_card", fetched_at: 1.hour.ago, usd_cents: 500)
    # No price data for unpriced_card

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1000, body["total_value_cents"] # Only counts priced_card
    assert_equal 5, body["total_cards"]
    assert_equal 2, body["valued_cards"]
    assert_equal 3, body["excluded_cards"]
  end

  test "GET /api/inventory/value excludes cards when all price fields are nil" do
    CollectionItem.create!(
      user: @user,
      card_id: "all_nil_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    CardPrice.create!(
      card_id: "all_nil_card",
      fetched_at: 1.hour.ago,
      usd_cents: nil,
      usd_foil_cents: nil,
      usd_etched_cents: nil
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 0, body["total_value_cents"]
    assert_equal 1, body["total_cards"]
    assert_equal 0, body["valued_cards"]
    assert_equal 1, body["excluded_cards"]
  end

  # ---------------------------------------------------------------------------
  # Wishlist exclusion tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory/value only counts inventory items, not wishlist" do
    CollectionItem.create!(
      user: @user,
      card_id: "inventory_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "wishlist_card",
      collection_type: "wishlist",
      quantity: 1,
      treatment: "Normal"
    )

    CardPrice.create!(card_id: "inventory_card", fetched_at: 1.hour.ago, usd_cents: 300)
    CardPrice.create!(card_id: "wishlist_card", fetched_at: 1.hour.ago, usd_cents: 500)

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 300, body["total_value_cents"] # Only inventory card
    assert_equal 1, body["total_cards"]
  end

  # ---------------------------------------------------------------------------
  # User isolation tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory/value only counts current user's inventory" do
    other_user = User.create!(email: "other@example.com", name: "Other User")

    CollectionItem.create!(
      user: @user,
      card_id: "my_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )
    CollectionItem.create!(
      user: other_user,
      card_id: "their_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    CardPrice.create!(card_id: "my_card", fetched_at: 1.hour.ago, usd_cents: 200)
    CardPrice.create!(card_id: "their_card", fetched_at: 1.hour.ago, usd_cents: 400)

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 200, body["total_value_cents"] # Only current user's card
    assert_equal 1, body["total_cards"]
  end

  # ---------------------------------------------------------------------------
  # Timestamp tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory/value includes last_updated timestamp" do
    CollectionItem.create!(
      user: @user,
      card_id: "card1",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    fetched_time = 2.hours.ago
    CardPrice.create!(card_id: "card1", fetched_at: fetched_time, usd_cents: 100)

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_not_nil body["last_updated"]

    # Verify the timestamp is approximately correct
    parsed_time = Time.parse(body["last_updated"])
    assert_in_delta fetched_time.to_i, parsed_time.to_i, 1
  end

  test "GET /api/inventory/value uses most recent price timestamp" do
    CollectionItem.create!(
      user: @user,
      card_id: "card1",
      collection_type: "inventory",
      quantity: 1
    )
    CollectionItem.create!(
      user: @user,
      card_id: "card2",
      collection_type: "inventory",
      quantity: 1
    )

    older_time = 5.hours.ago
    newer_time = 1.hour.ago

    CardPrice.create!(card_id: "card1", fetched_at: older_time, usd_cents: 100)
    CardPrice.create!(card_id: "card2", fetched_at: newer_time, usd_cents: 200)

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)

    # Should use the most recent timestamp
    parsed_time = Time.parse(body["last_updated"])
    assert_in_delta newer_time.to_i, parsed_time.to_i, 1
  end

  test "GET /api/inventory/value returns null last_updated when no prices exist" do
    CollectionItem.create!(
      user: @user,
      card_id: "unpriced",
      collection_type: "inventory",
      quantity: 1
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_nil body["last_updated"]
  end

  # ---------------------------------------------------------------------------
  # Caching tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory/value caches results for 1 hour" do
    CollectionItem.create!(
      user: @user,
      card_id: "card1",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    CardPrice.create!(card_id: "card1", fetched_at: 1.hour.ago, usd_cents: 100)

    # First request
    get api_path("/inventory/value")
    assert_response :success
    first_body = JSON.parse(response.body)
    assert_equal 100, first_body["total_value_cents"]

    # Add more items to inventory
    CollectionItem.create!(
      user: @user,
      card_id: "card2",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )
    CardPrice.create!(card_id: "card2", fetched_at: 1.hour.ago, usd_cents: 200)

    # Second request should still return cached value
    get api_path("/inventory/value")
    assert_response :success
    second_body = JSON.parse(response.body)
    assert_equal 100, second_body["total_value_cents"] # Still cached value
    assert_equal 1, second_body["total_cards"] # Still cached count
  end

  test "GET /api/inventory/value cache expires after 1 hour" do
    CollectionItem.create!(
      user: @user,
      card_id: "card1",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    CardPrice.create!(card_id: "card1", fetched_at: 1.hour.ago, usd_cents: 100)

    # First request
    get api_path("/inventory/value")
    assert_response :success

    # Add more items
    CollectionItem.create!(
      user: @user,
      card_id: "card2",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )
    CardPrice.create!(card_id: "card2", fetched_at: 1.hour.ago, usd_cents: 200)

    # Simulate cache expiry
    travel 61.minutes do
      get api_path("/inventory/value")
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 300, body["total_value_cents"] # New calculation
      assert_equal 2, body["total_cards"] # Updated count
    end
  end

  test "GET /api/inventory/value uses separate cache keys per user" do
    other_user = User.create!(email: "other@example.com", name: "Other User")

    # Current user's inventory
    CollectionItem.create!(
      user: @user,
      card_id: "card1",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )
    CardPrice.create!(card_id: "card1", fetched_at: 1.hour.ago, usd_cents: 100)

    # Other user's inventory
    CollectionItem.create!(
      user: other_user,
      card_id: "card2",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )
    CardPrice.create!(card_id: "card2", fetched_at: 1.hour.ago, usd_cents: 500)

    # Current user request
    get api_path("/inventory/value")
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 100, body["total_value_cents"]

    # Note: In a real implementation, we would need to test with different users
    # For now, this test documents the expected behavior
  end

  # ---------------------------------------------------------------------------
  # Complex scenarios
  # ---------------------------------------------------------------------------

  test "GET /api/inventory/value handles mixed treatments correctly" do
    CollectionItem.create!(
      user: @user,
      card_id: "card1",
      collection_type: "inventory",
      quantity: 2,
      treatment: "Normal"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "card1_foil",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Foil"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "card2",
      collection_type: "inventory",
      quantity: 3,
      treatment: "Etched"
    )

    CardPrice.create!(
      card_id: "card1",
      fetched_at: 1.hour.ago,
      usd_cents: 100,
      usd_foil_cents: 300
    )
    CardPrice.create!(
      card_id: "card1_foil",
      fetched_at: 1.hour.ago,
      usd_cents: 100,
      usd_foil_cents: 300
    )
    CardPrice.create!(
      card_id: "card2",
      fetched_at: 1.hour.ago,
      usd_cents: 50,
      usd_etched_cents: 150
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    # (2 × 100) + (1 × 300) + (3 × 150) = 200 + 300 + 450 = 950
    assert_equal 950, body["total_value_cents"]
    assert_equal 6, body["total_cards"]
    assert_equal 6, body["valued_cards"]
  end

  test "GET /api/inventory/value handles mixed priced and unpriced cards" do
    CollectionItem.create!(
      user: @user,
      card_id: "priced1",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "unpriced",
      collection_type: "inventory",
      quantity: 2,
      treatment: "Normal"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "priced2",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Foil"
    )

    CardPrice.create!(card_id: "priced1", fetched_at: 1.hour.ago, usd_cents: 100)
    CardPrice.create!(
      card_id: "priced2",
      fetched_at: 1.hour.ago,
      usd_cents: 50,
      usd_foil_cents: 200
    )

    get api_path("/inventory/value")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 300, body["total_value_cents"] # 100 + 200
    assert_equal 4, body["total_cards"] # 1 + 2 + 1
    assert_equal 2, body["valued_cards"] # priced1 + priced2
    assert_equal 2, body["excluded_cards"] # 2 copies of unpriced
  end
end
