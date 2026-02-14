require "test_helper"
require "webmock/minitest"

class InventorySortingOptimizationTest < ActionDispatch::IntegrationTest
  # Tests to verify sorting uses database ORDER BY instead of Ruby enumeration.
  # Critical test: Only paginated items should be enriched (spy on CardDetailsService).
  # This is the main performance optimization - reducing 200+ enrichments to 20.

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

  def stub_scryfall_card_details(card_id, name: "Card", set: "SET", set_name: "Set Name", released_at: "2024-01-01")
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: set,
          set_name: set_name,
          collector_number: "1",
          released_at: released_at,
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/t/e/test.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ---------------------------------------------------------------------------
  # Critical Test: Only paginated items are enriched
  # ---------------------------------------------------------------------------

  test "only enriches paginated items not all items" do
    # Create 50 items - will show 20 per page
    50.times do |i|
      card_id = "optimize_#{i}"
      stub_scryfall_card_details(card_id, name: "Card #{i.to_s.rjust(2, '0')}")

      CollectionItem.create!(
        user: @user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1,
        finish: "nonfoil"
      )
    end

    # Track CardDetailsService calls
    call_count = 0
    original_method = CardDetailsService.instance_method(:call)

    CardDetailsService.class_eval do
      define_method(:call) do
        call_count += 1
        original_method.bind(self).call
      end
    end

    get api_path("/inventory?per_page=20")
    assert_response :success

    # Restore original method
    CardDetailsService.class_eval do
      define_method(:call, original_method)
    end

    body = JSON.parse(response.body)
    assert_equal 20, body["items"].size
    assert_equal 50, body["total_count"]

    # CRITICAL ASSERTION: Should only enrich 20 items (paginated), not all 50
    assert_equal 20, call_count,
                 "Expected 20 CardDetailsService calls (paginated items only), got #{call_count}"
  end

  test "only enriches second page items not all items" do
    # Create 50 items
    50.times do |i|
      card_id = "page2_#{i}"
      stub_scryfall_card_details(card_id, name: "Card #{i}")

      CollectionItem.create!(
        user: @user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
    end

    # Track calls for page 2
    call_count = 0
    original_method = CardDetailsService.instance_method(:call)

    CardDetailsService.class_eval do
      define_method(:call) do
        call_count += 1
        original_method.bind(self).call
      end
    end

    get api_path("/inventory?page=2&per_page=20")
    assert_response :success

    CardDetailsService.class_eval do
      define_method(:call, original_method)
    end

    body = JSON.parse(response.body)
    assert_equal 20, body["items"].size

    # Should only enrich 20 items for page 2
    assert_equal 20, call_count,
                 "Expected 20 CardDetailsService calls for page 2, got #{call_count}"
  end

  # ---------------------------------------------------------------------------
  # Test: Database sorting works correctly
  # ---------------------------------------------------------------------------

  test "sorts by card_name at database level" do
    # Create items with specific names (out of alphabetical order)
    names = ["Zebra", "Apple", "Mango", "Banana"]
    names.each do |name|
      card_id = "name_#{name.downcase}"
      stub_scryfall_card_details(card_id, name: name)

      CollectionItem.create!(
        user: @user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
    end

    # Test ascending
    get api_path("/inventory?sort=name-asc")
    assert_response :success

    body = JSON.parse(response.body)
    card_names = body["items"].map { |item| item["card_name"] }
    assert_equal ["Apple", "Banana", "Mango", "Zebra"], card_names

    # Test descending
    get api_path("/inventory?sort=name-desc")
    assert_response :success

    body = JSON.parse(response.body)
    card_names = body["items"].map { |item| item["card_name"] }
    assert_equal ["Zebra", "Mango", "Banana", "Apple"], card_names
  end

  test "sorts by set_name at database level" do
    sets = [
      { id: "set1", name: "Zendikar" },
      { id: "set2", name: "Alpha" },
      { id: "set3", name: "Modern" }
    ]

    sets.each do |set_data|
      stub_scryfall_card_details(set_data[:id], set_name: set_data[:name])

      CollectionItem.create!(
        user: @user,
        card_id: set_data[:id],
        collection_type: "inventory",
        quantity: 1
      )
    end

    # Test ascending
    get api_path("/inventory?sort=set-asc")
    assert_response :success

    body = JSON.parse(response.body)
    set_names = body["items"].map { |item| item["set_name"] }
    assert_equal ["Alpha", "Modern", "Zendikar"], set_names

    # Test descending
    get api_path("/inventory?sort=set-desc")
    assert_response :success

    body = JSON.parse(response.body)
    set_names = body["items"].map { |item| item["set_name"] }
    assert_equal ["Zendikar", "Modern", "Alpha"], set_names
  end

  test "sorts by released_at at database level" do
    dates = [
      { id: "date1", date: "2020-01-01" },
      { id: "date2", date: "2023-06-15" },
      { id: "date3", date: "2019-03-20" }
    ]

    dates.each do |date_data|
      stub_scryfall_card_details(date_data[:id], released_at: date_data[:date])

      CollectionItem.create!(
        user: @user,
        card_id: date_data[:id],
        collection_type: "inventory",
        quantity: 1
      )
    end

    # Test newest first
    get api_path("/inventory?sort=release-newest")
    assert_response :success

    body = JSON.parse(response.body)
    dates_result = body["items"].map { |item| item["released_at"] }
    assert_equal ["2023-06-15", "2020-01-01", "2019-03-20"], dates_result

    # Test oldest first
    get api_path("/inventory?sort=release-oldest")
    assert_response :success

    body = JSON.parse(response.body)
    dates_result = body["items"].map { |item| item["released_at"] }
    assert_equal ["2019-03-20", "2020-01-01", "2023-06-15"], dates_result
  end

  test "sorts by value using database JOIN" do
    items_data = [
      { id: "val1", name: "Cheap", price: 100, qty: 1 },
      { id: "val2", name: "Expensive", price: 5000, qty: 2 },
      { id: "val3", name: "Medium", price: 1000, qty: 1 }
    ]

    items_data.each do |data|
      stub_scryfall_card_details(data[:id], name: data[:name])

      CollectionItem.create!(
        user: @user,
        card_id: data[:id],
        collection_type: "inventory",
        quantity: data[:qty],
        finish: "nonfoil"
      )

      CardPrice.create!(
        card_id: data[:id],
        fetched_at: 1.hour.ago,
        usd_cents: data[:price]
      )
    end

    # Test high to low
    get api_path("/inventory?sort=value-high")
    assert_response :success

    body = JSON.parse(response.body)
    names = body["items"].map { |item| item["card_name"] }
    # Expensive: 5000*2=10000, Medium: 1000*1=1000, Cheap: 100*1=100
    assert_equal ["Expensive", "Medium", "Cheap"], names

    # Test low to high
    get api_path("/inventory?sort=value-low")
    assert_response :success

    body = JSON.parse(response.body)
    names = body["items"].map { |item| item["card_name"] }
    assert_equal ["Cheap", "Medium", "Expensive"], names
  end

  test "sorts by created_at (date added)" do
    # Create items with different timestamps
    Timecop.freeze(3.days.ago) do
      stub_scryfall_card_details("old", name: "Old Card")
      CollectionItem.create!(
        user: @user,
        card_id: "old",
        collection_type: "inventory",
        quantity: 1
      )
    end

    Timecop.freeze(1.day.ago) do
      stub_scryfall_card_details("recent", name: "Recent Card")
      CollectionItem.create!(
        user: @user,
        card_id: "recent",
        collection_type: "inventory",
        quantity: 1
      )
    end

    stub_scryfall_card_details("newest", name: "Newest Card")
    CollectionItem.create!(
      user: @user,
      card_id: "newest",
      collection_type: "inventory",
      quantity: 1
    )

    # Test newest first
    get api_path("/inventory?sort=date-newest")
    assert_response :success

    body = JSON.parse(response.body)
    names = body["items"].map { |item| item["card_name"] }
    assert_equal ["Newest Card", "Recent Card", "Old Card"], names

    # Test oldest first
    get api_path("/inventory?sort=date-oldest")
    assert_response :success

    body = JSON.parse(response.body)
    names = body["items"].map { |item| item["card_name"] }
    assert_equal ["Old Card", "Recent Card", "Newest Card"], names
  end

  # ---------------------------------------------------------------------------
  # Test: Sorting with pagination works correctly
  # ---------------------------------------------------------------------------

  test "database sorting persists across pages" do
    # Create 30 items with alphabetical names
    30.times do |i|
      name = "Card #{i.to_s.rjust(2, '0')}"  # Card 00, Card 01, ...
      card_id = "page_sort_#{i}"
      stub_scryfall_card_details(card_id, name: name)

      CollectionItem.create!(
        user: @user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
    end

    # Page 1 should have Card 00 - Card 19
    get api_path("/inventory?sort=name-asc&per_page=20")
    assert_response :success

    body = JSON.parse(response.body)
    first_item = body["items"].first["card_name"]
    last_item = body["items"].last["card_name"]
    assert_equal "Card 00", first_item
    assert_equal "Card 19", last_item

    # Page 2 should have Card 20 - Card 29
    get api_path("/inventory?sort=name-asc&page=2&per_page=20")
    assert_response :success

    body = JSON.parse(response.body)
    first_item = body["items"].first["card_name"]
    last_item = body["items"].last["card_name"]
    assert_equal "Card 20", first_item
    assert_equal "Card 29", last_item
  end

  # ---------------------------------------------------------------------------
  # Test: Performance - uses database queries not Ruby sorting
  # ---------------------------------------------------------------------------

  test "uses database ORDER BY for sorting" do
    # Create items
    10.times do |i|
      card_id = "db_sort_#{i}"
      stub_scryfall_card_details(card_id, name: "Card #{i}")

      CollectionItem.create!(
        user: @user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
    end

    # Monitor SQL queries
    query_log = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      query_log << payload[:sql]
    end

    get api_path("/inventory?sort=name-asc")
    assert_response :success

    ActiveSupport::Notifications.unsubscribe(subscriber)

    # Check that ORDER BY is used in SQL
    order_by_queries = query_log.select do |sql|
      sql.match?(/ORDER BY.*card_name/i) &&
        sql.match?(/collection_items/i)
    end

    assert order_by_queries.any?, "Expected SQL queries with ORDER BY card_name"
  end

  test "uses database LIMIT and OFFSET for pagination" do
    20.times do |i|
      card_id = "pagination_#{i}"
      stub_scryfall_card_details(card_id)

      CollectionItem.create!(
        user: @user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
    end

    query_log = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      query_log << payload[:sql]
    end

    get api_path("/inventory?page=2&per_page=5")
    assert_response :success

    ActiveSupport::Notifications.unsubscribe(subscriber)

    # Check for LIMIT and OFFSET in queries
    pagination_queries = query_log.select do |sql|
      sql.match?(/LIMIT.*OFFSET/i) &&
        sql.match?(/collection_items/i)
    end

    assert pagination_queries.any?, "Expected SQL queries with LIMIT and OFFSET"
  end
end
