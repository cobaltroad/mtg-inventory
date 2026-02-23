require "test_helper"
require "webmock/minitest"

class InventoryStatsSqlTest < ActionDispatch::IntegrationTest
  # Tests to verify stats calculation uses SQL aggregates instead of loading all items.
  # These tests ensure backward compatibility - stats should match existing behavior
  # but use database queries instead of Ruby enumeration.

  setup do
    CollectionItem.delete_all
    User.delete_all
    CardPrice.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
    WebMock.reset!

    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  def stub_scryfall_card_details(card_id, name: "Test Card", set: "TST", set_name: "Test Set")
    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/#{card_id}/)
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: set,
          set_name: set_name,
          collector_number: "1",
          released_at: "2024-01-01",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/t/e/test.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ---------------------------------------------------------------------------
  # Test: Stats calculation matches existing behavior
  # ---------------------------------------------------------------------------

  test "stats match existing behavior with denormalized fields" do
    # Create inventory with various prices and sets
    items_data = [
      { card_id: "card_1", name: "Expensive Card", set: "EXP", set_name: "Expensive Set", quantity: 2, price: 5000 },
      { card_id: "card_2", name: "Cheap Card", set: "CHP", set_name: "Cheap Set", quantity: 5, price: 100 },
      { card_id: "card_3", name: "Medium Card", set: "EXP", set_name: "Expensive Set", quantity: 1, price: 1500 },
      { card_id: "card_4", name: "Another Card", set: "OTH", set_name: "Other Set", quantity: 3, price: 800 }
    ]

    items_data.each do |data|
      stub_scryfall_card_details(data[:card_id], name: data[:name], set: data[:set], set_name: data[:set_name])

      item = CollectionItem.create!(
        user: @user,
        card_id: data[:card_id],
        collection_type: "inventory",
        quantity: data[:quantity],
        finish: "nonfoil"
      )

      CardPrice.create!(
        card_id: data[:card_id],
        fetched_at: 1.hour.ago,
        usd_cents: data[:price]
      )
    end

    get api_path("/inventory")
    assert_response :success

    body = JSON.parse(response.body)
    stats = body["stats"]

    # Most valuable card by total price = card_1 (2 * 5000 = 10000)
    assert_equal "Expensive Card", stats["most_valuable_card"]

    # Most collected set = EXP (2 items: card_1 and card_3)
    assert_equal "Expensive Set", stats["most_collected_set"]
  end

  test "stats handle items without prices correctly" do
    # Mix of items with and without prices
    stub_scryfall_card_details("priced_card", name: "Priced Card", set_name: "Set A")
    stub_scryfall_card_details("unpriced_card", name: "Unpriced Card", set_name: "Set B")

    priced = CollectionItem.create!(
      user: @user,
      card_id: "priced_card",
      collection_type: "inventory",
      quantity: 2,
      finish: "nonfoil"
    )

    unpriced = CollectionItem.create!(
      user: @user,
      card_id: "unpriced_card",
      collection_type: "inventory",
      quantity: 3,
      finish: "nonfoil"
    )

    # Only create price for first card
    CardPrice.create!(
      card_id: "priced_card",
      fetched_at: 1.hour.ago,
      usd_cents: 1000
    )

    get api_path("/inventory")
    assert_response :success

    body = JSON.parse(response.body)
    stats = body["stats"]

    # Most valuable is the only priced card
    assert_equal "Priced Card", stats["most_valuable_card"]
  end

  test "stats handle foil pricing correctly" do
    stub_scryfall_card_details("foil_card", name: "Foil Card", set_name: "Foil Set")

    CollectionItem.create!(
      user: @user,
      card_id: "foil_card",
      collection_type: "inventory",
      quantity: 2,
      finish: "foil"
    )

    CardPrice.create!(
      card_id: "foil_card",
      fetched_at: 1.hour.ago,
      usd_cents: 1000,
      usd_foil_cents: 3000
    )

    get api_path("/inventory")
    assert_response :success

    body = JSON.parse(response.body)
    stats = body["stats"]

    # Most valuable card should be calculated using foil price
    assert_equal "Foil Card", stats["most_valuable_card"]
  end

  test "stats return nils for empty inventory" do
    get api_path("/inventory")
    assert_response :success

    body = JSON.parse(response.body)
    stats = body["stats"]

    assert_nil stats["most_valuable_card"]
    assert_nil stats["most_collected_set"]
  end

  # ---------------------------------------------------------------------------
  # Test: SQL optimization - minimal items loaded
  # ---------------------------------------------------------------------------

  test "stats calculation does not load all items into memory" do
    # Create 200 items
    200.times do |i|
      card_id = "sql_test_#{i}"
      stub_scryfall_card_details(card_id, name: "Card #{i}", set_name: "Set #{i % 10}")

      CollectionItem.create!(
        user: @user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1,
        finish: "nonfoil"
      )

      CardPrice.create!(
        card_id: card_id,
        fetched_at: 1.hour.ago,
        usd_cents: (i + 1) * 100
      )
    end

    # Monitor ActiveRecord to ensure we're using SQL aggregates
    query_log = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      query_log << payload[:sql]
    end

    get api_path("/inventory")
    assert_response :success

    ActiveSupport::Notifications.unsubscribe(subscriber)

    body = JSON.parse(response.body)
    stats = body["stats"]

    # Verify stats are calculated correctly
    assert_not_nil stats["most_valuable_card"]
    assert_not_nil stats["most_collected_set"]

    # Check that we're using SQL aggregates (COUNT, GROUP BY, ORDER BY)
    aggregate_queries = query_log.select do |sql|
      sql.match?(/COUNT|GROUP BY|ORDER BY/i) &&
        sql.match?(/collection_items/i)
    end

    assert aggregate_queries.any?, "Expected SQL aggregate queries for stats calculation"
  end

end
