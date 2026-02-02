require "test_helper"
require "ostruct"

class CardSearchServiceTest < ActiveSupport::TestCase
  # Disable parallelization for this test class to ensure cache works correctly
  parallelize(workers: 1)

  setup do
    # Use a real cache store for testing caching behavior (test env uses :null_store by default)
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
  end

  teardown do
    # Restore the original cache store
    Rails.cache = @original_cache
  end

  # ---------------------------------------------------------------------------
  # Caching behavior tests
  # ---------------------------------------------------------------------------
  test "caches external API results for identical query" do
    query = "Lightning Bolt"
    sample_cards = [
      OpenStruct.new(
        id: "abc123",
        name: "Lightning Bolt",
        set: "lea",
        set_name: "Limited Edition Alpha",
        number: "157",
        image_url: "https://example.com/bolt.jpg",
        border: "black"
      )
    ]

    # First call should hit the external API
    call_count = 0
    stub_response = OpenStruct.new
    stub_response.define_singleton_method(:all) do
      call_count += 1
      sample_cards
    end

    MTG::Card.stub(:where, stub_response) do
      service1 = CardSearchService.new(query: query, treatments: [])
      results1 = service1.call

      # Second call with same query should use cache
      service2 = CardSearchService.new(query: query, treatments: [])
      results2 = service2.call

      assert_equal 1, call_count, "Expected only one external API call"
      assert_equal results1, results2, "Expected identical results from cache"
    end
  end

  test "different queries generate separate cache entries" do
    query1 = "Lightning Bolt"
    query2 = "Black Lotus"

    card1 = OpenStruct.new(
      id: "1", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
      number: "157", image_url: "http://example.com/bolt.jpg", border: "black"
    )
    card2 = OpenStruct.new(
      id: "2", name: "Black Lotus", set: "lea", set_name: "Alpha",
      number: "232", image_url: "http://example.com/lotus.jpg", border: "black"
    )

    api_calls = []
    stub_response = Object.new
    stub_response.define_singleton_method(:all) do
      # Capture which query was made based on the order
      query_name = api_calls.size == 0 ? query1 : query2
      api_calls << query_name
      query_name == query1 ? [ card1 ] : [ card2 ]
    end

    MTG::Card.stub(:where, stub_response) do
      service1 = CardSearchService.new(query: query1, treatments: [])
      results1 = service1.call

      service2 = CardSearchService.new(query: query2, treatments: [])
      results2 = service2.call

      assert_equal 2, api_calls.size, "Expected two different API calls"
      refute_equal results1, results2, "Expected different results for different queries"
    end
  end

  test "treatment filters do not affect cache key when treatments are empty" do
    query = "Lightning Bolt"
    sample_cards = [
      OpenStruct.new(
        id: "1", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
        number: "157", image_url: "http://example.com/bolt.jpg", border: "black"
      )
    ]

    call_count = 0
    stub_response = Object.new
    stub_response.define_singleton_method(:all) do
      call_count += 1
      sample_cards
    end

    MTG::Card.stub(:where, stub_response) do
      # First call without treatments
      service1 = CardSearchService.new(query: query, treatments: [])
      service1.call

      # Second call with empty treatments should hit cache
      service2 = CardSearchService.new(query: query, treatments: [])
      service2.call

      assert_equal 1, call_count, "Expected cache hit for same query"
    end
  end

  test "cache respects treatment filter parameter" do
    query = "Lightning Bolt"
    borderless_card = OpenStruct.new(
      id: "1", name: "Lightning Bolt", set: "znr", set_name: "Zendikar Rising",
      number: "157", image_url: "http://example.com/bolt.jpg", border: "borderless"
    )
    normal_card = OpenStruct.new(
      id: "2", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
      number: "157", image_url: "http://example.com/bolt2.jpg", border: "black"
    )

    call_count = 0
    stub_response = Object.new
    stub_response.define_singleton_method(:all) do
      call_count += 1
      [ borderless_card, normal_card ]
    end

    MTG::Card.stub(:where, stub_response) do
      # First call with no treatment filter - should cache full results
      service1 = CardSearchService.new(query: query, treatments: [])
      results1 = service1.call

      # Second call with borderless filter - should use cache but filter locally
      service2 = CardSearchService.new(query: query, treatments: [ "borderless" ])
      results2 = service2.call

      assert_equal 1, call_count, "Expected single API call with cached filtering"
      assert_equal 2, results1.size, "Expected all cards without filter"
      assert_equal 1, results2.size, "Expected filtered results"
      assert_equal "borderless", results2.first[:treatments].first
    end
  end

  test "cache key includes query but not treatments" do
    query = "Lightning Bolt"
    card = OpenStruct.new(
      id: "1", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
      number: "157", image_url: "http://example.com/bolt.jpg", border: "borderless"
    )

    call_count = 0
    stub_response = Object.new
    stub_response.define_singleton_method(:all) do
      call_count += 1
      [ card ]
    end

    MTG::Card.stub(:where, stub_response) do
      # Call with no treatments
      service1 = CardSearchService.new(query: query, treatments: [])
      service1.call

      # Call with treatments should use same cache
      service2 = CardSearchService.new(query: query, treatments: [ "borderless" ])
      service2.call

      assert_equal 1, call_count, "Expected treatments not to affect cache key"
    end
  end

  test "handles empty results from API" do
    query = "NonexistentCard12345"

    call_count = 0
    stub_response = Object.new
    stub_response.define_singleton_method(:all) do
      call_count += 1
      []
    end

    MTG::Card.stub(:where, stub_response) do
      service1 = CardSearchService.new(query: query, treatments: [])
      results1 = service1.call

      service2 = CardSearchService.new(query: query, treatments: [])
      results2 = service2.call

      assert_equal 1, call_count, "Expected empty results to be cached"
      assert_empty results1
      assert_empty results2
    end
  end

  test "cache expires after configured TTL" do
    query = "Lightning Bolt"
    card = OpenStruct.new(
      id: "1", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
      number: "157", image_url: "http://example.com/bolt.jpg", border: "black"
    )

    call_count = 0
    stub_response = Object.new
    stub_response.define_singleton_method(:all) do
      call_count += 1
      [ card ]
    end

    MTG::Card.stub(:where, stub_response) do
      # First call
      service1 = CardSearchService.new(query: query, treatments: [])
      service1.call

      # Simulate cache expiration
      cache_key = "card_search:Lightning Bolt"
      Rails.cache.delete(cache_key)

      # Second call after cache expiration
      service2 = CardSearchService.new(query: query, treatments: [])
      service2.call

      assert_equal 2, call_count, "Expected API call after cache expiration"
    end
  end

  # ---------------------------------------------------------------------------
  # Existing functionality tests (ensure we don't break anything)
  # ---------------------------------------------------------------------------
  test "formats card data correctly" do
    query = "Lightning Bolt"
    card = OpenStruct.new(
      id: "abc123",
      name: "Lightning Bolt",
      set: "lea",
      set_name: "Limited Edition Alpha",
      number: "157",
      image_url: "https://example.com/bolt.jpg",
      border: "black"
    )

    stub_response = Object.new
    stub_response.define_singleton_method(:all) { [ card ] }

    MTG::Card.stub(:where, stub_response) do
      service = CardSearchService.new(query: query, treatments: [])
      results = service.call

      assert_equal 1, results.size
      result = results.first
      assert_equal "abc123", result[:id]
      assert_equal "Lightning Bolt", result[:name]
      assert_equal "lea", result[:set]
      assert_equal "Limited Edition Alpha", result[:set_name]
      assert_equal "157", result[:collector_number]
      assert_equal "https://example.com/bolt.jpg", result[:image_url]
      assert_equal [], result[:treatments]
    end
  end

  test "derives borderless treatment correctly" do
    query = "Test Card"
    card = OpenStruct.new(
      id: "1", name: "Test Card", set: "znr", set_name: "Zendikar Rising",
      number: "1", image_url: "http://example.com/test.jpg", border: "borderless"
    )

    stub_response = Object.new
    stub_response.define_singleton_method(:all) { [ card ] }

    MTG::Card.stub(:where, stub_response) do
      service = CardSearchService.new(query: query, treatments: [])
      results = service.call

      assert_equal [ "borderless" ], results.first[:treatments]
    end
  end
end
