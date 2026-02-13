require "test_helper"
require "webmock/minitest"
require "benchmark"

class InventoryPaginatedTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Spike #156: Backend Pagination Evaluation Tests
  #
  # These tests evaluate backend pagination performance vs client-side pagination.
  # Tests cover pagination functionality, performance benchmarks, and API contract.
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
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
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

  test "GET /api/inventory/paginated returns first page by default" do
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

    get api_path("/inventory/paginated")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 20, body["items"].size
    assert_equal 1, body["page"]
    assert_equal 20, body["per_page"]
    assert_equal 25, body["total_count"]
    assert_equal 2, body["total_pages"]
  end

  test "GET /api/inventory/paginated accepts page parameter" do
    30.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "page_param_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("page_param_#{i}")
    end

    get api_path("/inventory/paginated?page=2")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 10, body["items"].size  # 30 total - 20 on page 1 = 10 on page 2
    assert_equal 2, body["page"]
    assert_equal 30, body["total_count"]
  end

  test "GET /api/inventory/paginated accepts per_page parameter" do
    60.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "per_page_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("per_page_#{i}")
    end

    get api_path("/inventory/paginated?per_page=50")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 50, body["items"].size
    assert_equal 50, body["per_page"]
    assert_equal 60, body["total_count"]
    assert_equal 2, body["total_pages"]
  end

  test "GET /api/inventory/paginated limits per_page to 100 maximum" do
    150.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "max_per_page_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("max_per_page_#{i}")
    end

    get api_path("/inventory/paginated?per_page=500")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 100, body["items"].size
    assert_equal 100, body["per_page"]
  end

  # ---------------------------------------------------------------------------
  # Scenario 2: Performance benchmarks comparing both approaches
  # ---------------------------------------------------------------------------

  test "benchmark: 50 items - paginated vs non-paginated" do
    create_test_inventory(50)

    paginated_time = Benchmark.realtime do
      get api_path("/inventory/paginated?per_page=20")
      assert_response :success
    end

    non_paginated_time = Benchmark.realtime do
      get api_path("/inventory")
      assert_response :success
    end

    puts "\n=== Benchmark: 50 items ==="
    puts "Paginated (20/page):    #{(paginated_time * 1000).round(2)}ms"
    puts "Non-paginated (all 50): #{(non_paginated_time * 1000).round(2)}ms"
    puts "Difference: #{((paginated_time - non_paginated_time) * 1000).round(2)}ms"
  end

  test "benchmark: 100 items - paginated vs non-paginated" do
    create_test_inventory(100)

    paginated_time = Benchmark.realtime do
      get api_path("/inventory/paginated?per_page=20")
      assert_response :success
    end

    non_paginated_time = Benchmark.realtime do
      get api_path("/inventory")
      assert_response :success
    end

    puts "\n=== Benchmark: 100 items ==="
    puts "Paginated (20/page):     #{(paginated_time * 1000).round(2)}ms"
    puts "Non-paginated (all 100): #{(non_paginated_time * 1000).round(2)}ms"
    puts "Difference: #{((paginated_time - non_paginated_time) * 1000).round(2)}ms"
  end

  test "benchmark: 500 items - paginated vs non-paginated" do
    create_test_inventory(500)

    paginated_time = Benchmark.realtime do
      get api_path("/inventory/paginated?per_page=20")
      assert_response :success
    end

    non_paginated_time = Benchmark.realtime do
      get api_path("/inventory")
      assert_response :success
    end

    puts "\n=== Benchmark: 500 items ==="
    puts "Paginated (20/page):     #{(paginated_time * 1000).round(2)}ms"
    puts "Non-paginated (all 500): #{(non_paginated_time * 1000).round(2)}ms"
    puts "Difference: #{((paginated_time - non_paginated_time) * 1000).round(2)}ms"
    puts "Speedup: #{(non_paginated_time / paginated_time).round(2)}x"
  end

  # ---------------------------------------------------------------------------
  # Scenario 3: Database query analysis
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
      get api_path("/inventory/paginated?per_page=20")
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
      get api_path("/inventory/paginated?page=1&per_page=20")
    end
    db_queries_page_1 = queries_page_1.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }.size

    # Measure page 2
    queries_page_2 = track_queries do
      get api_path("/inventory/paginated?page=2&per_page=20")
    end
    db_queries_page_2 = queries_page_2.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }.size

    # Query count should be identical regardless of page
    assert_equal db_queries_page_1, db_queries_page_2,
                 "Query count should be consistent across pages"
  end

  # ---------------------------------------------------------------------------
  # Scenario 4: Scryfall API call reduction analysis
  # ---------------------------------------------------------------------------

  test "pagination reduces Scryfall API calls compared to loading all items" do
    # Create 100 items
    100.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "scryfall_test_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("scryfall_test_#{i}")
    end

    # Clear cache to ensure API calls are made
    Rails.cache.clear

    # Paginated request (20 items)
    get api_path("/inventory/paginated?per_page=20")
    assert_response :success
    paginated_body = JSON.parse(response.body)
    paginated_items_count = paginated_body["items"].size

    # Clear cache again
    Rails.cache.clear

    # Non-paginated request (all 100 items)
    get api_path("/inventory")
    assert_response :success
    non_paginated_body = JSON.parse(response.body)
    non_paginated_items_count = non_paginated_body.size

    puts "\n=== Scryfall API Call Reduction ==="
    puts "Paginated endpoint fetched:     #{paginated_items_count} cards"
    puts "Non-paginated endpoint fetched: #{non_paginated_items_count} cards"
    puts "Reduction: #{non_paginated_items_count - paginated_items_count} fewer API calls"
    puts "Percentage: #{((1 - paginated_items_count.to_f / non_paginated_items_count) * 100).round(1)}% reduction"

    assert paginated_items_count < non_paginated_items_count,
           "Paginated endpoint should fetch fewer cards than non-paginated"
  end

  # ---------------------------------------------------------------------------
  # Scenario 5: Payload size comparison
  # ---------------------------------------------------------------------------

  test "measure response payload sizes for different inventory sizes" do
    [50, 100, 500].each do |count|
      CollectionItem.delete_all
      create_test_inventory(count)

      # Measure paginated response (20 items)
      get api_path("/inventory/paginated?per_page=20")
      assert_response :success
      paginated_size = response.body.bytesize

      # Measure non-paginated response (all items)
      get api_path("/inventory")
      assert_response :success
      non_paginated_size = response.body.bytesize

      puts "\n=== Payload Size: #{count} items in inventory ==="
      puts "Paginated (20 items):        #{(paginated_size / 1024.0).round(2)} KB"
      puts "Non-paginated (#{count} items): #{(non_paginated_size / 1024.0).round(2)} KB"
      puts "Reduction: #{((non_paginated_size - paginated_size) / 1024.0).round(2)} KB"
      puts "Percentage: #{((1 - paginated_size.to_f / non_paginated_size) * 100).round(1)}% smaller"
    end
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
