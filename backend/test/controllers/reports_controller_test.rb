require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    CollectionItem.delete_all
    CardPrice.delete_all
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  test "inventory_stats returns aggregated statistics" do
    # Create test data
    card1 = @user.collection_items.create!(
      card_id: "test-mountain",
      collection_type: "inventory",
      quantity: 1,
      card_name: "Mountain",
      set_name: "Alpha"
    )

    card2 = @user.collection_items.create!(
      card_id: "test-island",
      collection_type: "inventory",
      quantity: 1,
      card_name: "Island",
      set_name: "Beta"
    )

    # Create price data for cards
    # Mountain: $15 each (over $10 threshold)
    CardPrice.create!(
      card_id: card1.card_id,
      usd_cents: 1500,
      fetched_at: Time.current
    )

    # Island: $5 each (under $10 threshold)
    CardPrice.create!(
      card_id: card2.card_id,
      usd_cents: 500,
      fetched_at: Time.current
    )

    get api_path("/reports/inventory_stats")

    assert_response :success

    json = JSON.parse(response.body)

    # Should have required fields
    assert json.key?("total_value_cents")
    assert json.key?("cards_over_ten_dollars")
    assert json.key?("total_sets")

    # Values should be integers
    assert json["total_value_cents"].is_a?(Integer)
    assert json["cards_over_ten_dollars"].is_a?(Integer)
    assert json["total_sets"].is_a?(Integer)

    # Total value should be $15 + $5 = $20 (2000 cents)
    assert_equal 2000, json["total_value_cents"]

    # Cards over $10 should count only Mountain
    assert_equal 1, json["cards_over_ten_dollars"]

    # Should have 2 unique sets (Alpha and Beta)
    assert_equal 2, json["total_sets"]
  end

  test "inventory_stats returns zeros for empty inventory" do
    # Start with empty inventory (cleaned in setup)
    get api_path("/reports/inventory_stats")

    assert_response :success

    json = JSON.parse(response.body)

    assert_equal 0, json["total_value_cents"]
    assert_equal 0, json["cards_over_ten_dollars"]
    assert_equal 0, json["total_sets"]
  end

  test "inventory_stats uses finish-based pricing" do
    # Create nonfoil card
    nonfoil_card = @user.collection_items.create!(
      card_id: "test-card",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil",
      card_name: "Test Card",
      set_name: "Alpha"
    )

    # Create foil version
    foil_card = @user.collection_items.create!(
      card_id: "test-card",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil",
      card_name: "Test Card",
      set_name: "Alpha"
    )

    # Create price data with different foil/nonfoil prices
    CardPrice.create!(
      card_id: "test-card",
      usd_cents: 100,           # nonfoil: $1
      usd_foil_cents: 500,      # foil: $5
      fetched_at: Time.current
    )

    get api_path("/reports/inventory_stats")

    assert_response :success

    json = JSON.parse(response.body)

    # Total value should be nonfoil ($1) + foil ($5) = $6 (600 cents)
    assert_equal 600, json["total_value_cents"]

    # Neither card is over $10
    assert_equal 0, json["cards_over_ten_dollars"]
  end

  test "inventory_stats counts unique sets correctly" do
    # Create cards from different sets
    @user.collection_items.create!(
      card_id: "test-card-1",
      collection_type: "inventory",
      quantity: 1,
      card_name: "Test Card 1",
      set_name: "Alpha"
    )

    @user.collection_items.create!(
      card_id: "test-card-2",
      collection_type: "inventory",
      quantity: 1,
      card_name: "Test Card 2",
      set_name: "Beta"
    )

    # Card from same set as card1
    @user.collection_items.create!(
      card_id: "test-card-3",
      collection_type: "inventory",
      quantity: 1,
      card_name: "Test Card 3",
      set_name: "Alpha"
    )

    get api_path("/reports/inventory_stats")

    assert_response :success

    json = JSON.parse(response.body)

    # Should count Alpha and Beta (2 unique sets)
    assert_equal 2, json["total_sets"]
  end

  test "inventory_stats excludes wishlist items" do
    # Create inventory item
    @user.collection_items.create!(
      card_id: "test-inv",
      collection_type: "inventory",
      quantity: 1,
      card_name: "Inventory Card",
      set_name: "Alpha"
    )

    # Create wishlist item (should be ignored)
    @user.collection_items.create!(
      card_id: "test-wish",
      collection_type: "wishlist",
      quantity: 1,
      card_name: "Wishlist Card",
      set_name: "Beta"
    )

    CardPrice.create!(
      card_id: "test-inv",
      usd_cents: 1000,
      fetched_at: Time.current
    )

    CardPrice.create!(
      card_id: "test-wish",
      usd_cents: 2000,
      fetched_at: Time.current
    )

    get api_path("/reports/inventory_stats")

    assert_response :success

    json = JSON.parse(response.body)

    # Should only count inventory, not wishlist
    assert_equal 1000, json["total_value_cents"]
    assert_equal 1, json["total_sets"]  # Only Alpha, not Beta
  end
end
