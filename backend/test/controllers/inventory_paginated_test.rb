require "test_helper"
require "webmock/minitest"

class InventoryPaginatedTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Backend Pagination Tests
  #
  # These tests verify pagination functionality and API contract.
  # ---------------------------------------------------------------------------

  setup do
    CollectionItem.delete_all
    User.delete_all
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

  def stub_scryfall_card_details(card_id, name: "Test Card #{card_id}")
    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/#{card_id}/)
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: "TST",
          set_name: "Test Set",
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
  # Scenario 1: Basic pagination functionality
  # ---------------------------------------------------------------------------

  test "GET /api/inventory returns first page by default" do
    # Create 25 items (more than one page at 20 per page)
    25.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "page_test_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("page_test_#{i}")
    end

    get api_path("/inventory")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 20, body["items"].size
    assert_equal 1, body["page"]
    assert_equal 20, body["per_page"]
    assert_equal 25, body["total_count"]
    assert_equal 2, body["total_pages"]
  end

  test "GET /api/inventory accepts page parameter" do
    30.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "page_param_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("page_param_#{i}")
    end

    get api_path("/inventory?page=2")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 10, body["items"].size  # 30 total - 20 on page 1 = 10 on page 2
    assert_equal 2, body["page"]
    assert_equal 30, body["total_count"]
  end

  test "GET /api/inventory accepts per_page parameter" do
    60.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "per_page_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("per_page_#{i}")
    end

    get api_path("/inventory?per_page=50")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 50, body["items"].size
    assert_equal 50, body["per_page"]
    assert_equal 60, body["total_count"]
    assert_equal 2, body["total_pages"]
  end

  test "GET /api/inventory limits per_page to 100 maximum" do
    150.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "max_per_page_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("max_per_page_#{i}")
    end

    get api_path("/inventory?per_page=500")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 100, body["items"].size
    assert_equal 100, body["per_page"]
  end

  # ---------------------------------------------------------------------------
  # Scenario 2: Database query analysis
  # ---------------------------------------------------------------------------

  test "paginated endpoint prevents N+1 queries with eager loading" do
    20.times do |i|
      item = CollectionItem.create!(
        user: @user,
        card_id: "eager_paginated_#{i}",
        collection_type: "inventory",
        quantity: 1,
        finish: "nonfoil"
      )

      item.cached_image.attach(
        io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
        filename: "card_#{i}.jpg",
        content_type: "image/jpeg"
      )

      CardPrice.create!(
        card_id: "eager_paginated_#{i}",
        fetched_at: 1.hour.ago,
        usd_cents: 100 + i
      )

      stub_scryfall_card_details("eager_paginated_#{i}", name: "Test Card #{i}")
    end

    queries = track_queries do
      get api_path("/inventory?per_page=20")
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 20, body["items"].size

    db_queries = queries.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }

    # Should maintain same low query count as non-paginated endpoint
    assert db_queries.size < 10,
           "Expected fewer than 10 DB queries with pagination + eager loading, but got #{db_queries.size}"
  end

  test "pagination query count remains constant across pages" do
    50.times do |i|
      item = CollectionItem.create!(
        user: @user,
        card_id: "page_consistency_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      item.cached_image.attach(
        io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
        filename: "card_#{i}.jpg",
        content_type: "image/jpeg"
      )
      stub_scryfall_card_details("page_consistency_#{i}")
    end

    # Measure page 1
    queries_page_1 = track_queries do
      get api_path("/inventory?page=1&per_page=20")
    end
    db_queries_page_1 = queries_page_1.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }.size

    # Measure page 2
    queries_page_2 = track_queries do
      get api_path("/inventory?page=2&per_page=20")
    end
    db_queries_page_2 = queries_page_2.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }.size

    # Query count should be identical regardless of page
    assert_equal db_queries_page_1, db_queries_page_2,
                 "Query count should be consistent across pages"
  end

  private

  def create_test_inventory(count)
    count.times do |i|
      item = CollectionItem.create!(
        user: @user,
        card_id: "bench_#{count}_#{i}",
        collection_type: "inventory",
        quantity: rand(1..10),
        finish: ["nonfoil", "foil", "etched"].sample
      )

      # Add some cached images (50% of items)
      if i % 2 == 0
        item.cached_image.attach(
          io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
          filename: "card_#{i}.jpg",
          content_type: "image/jpeg"
        )
      end

      # Add price data for all items
      CardPrice.create!(
        card_id: "bench_#{count}_#{i}",
        fetched_at: 1.hour.ago,
        usd_cents: rand(10..10000),
        usd_foil_cents: rand(10..20000),
        usd_etched_cents: rand(10..15000)
      )

      stub_scryfall_card_details("bench_#{count}_#{i}", name: "Bench Card #{i}")
    end
  end

  def track_queries
    queries = []
    query_subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA"
    end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(query_subscriber) if query_subscriber
  end
end
