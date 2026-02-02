require "test_helper"
require "webmock/minitest"

class CardSearchServiceTest < ActiveSupport::TestCase
  # Disable parallelization for this test class to ensure cache works correctly
  parallelize(workers: 1)

  setup do
    # Use a real cache store for testing caching behavior (test env uses :null_store by default)
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear

    # Reset WebMock for each test
    WebMock.reset!
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
    scryfall_response = {
      "object" => "list",
      "data" => [
        {
          "id" => "abc123",
          "name" => "Lightning Bolt",
          "set" => "lea",
          "set_name" => "Limited Edition Alpha",
          "collector_number" => "157",
          "image_uris" => { "normal" => "https://example.com/bolt.jpg" },
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        }
      ]
    }

    stub_scryfall_request(query, scryfall_response)

    service1 = CardSearchService.new(query: query, treatments: [])
    results1 = service1.call

    # Second call with same query should use cache
    service2 = CardSearchService.new(query: query, treatments: [])
    results2 = service2.call

    # Should only make one HTTP request (second uses cache)
    assert_requested :get, scryfall_url(query), times: 1
    assert_equal results1, results2, "Expected identical results from cache"
  end

  test "different queries generate separate cache entries" do
    query1 = "Lightning Bolt"
    query2 = "Black Lotus"

    response1 = scryfall_response_with_card(
      id: "1", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
      collector_number: "157", image_url: "http://example.com/bolt.jpg"
    )
    response2 = scryfall_response_with_card(
      id: "2", name: "Black Lotus", set: "lea", set_name: "Alpha",
      collector_number: "232", image_url: "http://example.com/lotus.jpg"
    )

    stub_scryfall_request(query1, response1)
    stub_scryfall_request(query2, response2)

    service1 = CardSearchService.new(query: query1, treatments: [])
    results1 = service1.call

    service2 = CardSearchService.new(query: query2, treatments: [])
    results2 = service2.call

    assert_requested :get, scryfall_url(query1), times: 1
    assert_requested :get, scryfall_url(query2), times: 1
    refute_equal results1, results2, "Expected different results for different queries"
  end

  test "treatment filters do not affect cache key when treatments are empty" do
    query = "Lightning Bolt"
    response = scryfall_response_with_card(
      id: "1", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
      collector_number: "157", image_url: "http://example.com/bolt.jpg"
    )

    stub_scryfall_request(query, response)

    # First call without treatments
    service1 = CardSearchService.new(query: query, treatments: [])
    service1.call

    # Second call with empty treatments should hit cache
    service2 = CardSearchService.new(query: query, treatments: [])
    service2.call

    assert_requested :get, scryfall_url(query), times: 1
  end

  test "cache respects treatment filter parameter" do
    query = "Lightning Bolt"
    response = {
      "object" => "list",
      "data" => [
        {
          "id" => "1", "name" => "Lightning Bolt", "set" => "znr",
          "set_name" => "Zendikar Rising", "collector_number" => "157",
          "image_uris" => { "normal" => "http://example.com/bolt.jpg" },
          "border_color" => "borderless", "finishes" => ["nonfoil"]
        },
        {
          "id" => "2", "name" => "Lightning Bolt", "set" => "lea",
          "set_name" => "Alpha", "collector_number" => "157",
          "image_uris" => { "normal" => "http://example.com/bolt2.jpg" },
          "border_color" => "black", "finishes" => ["nonfoil"]
        }
      ]
    }

    stub_scryfall_request(query, response)

    # First call with no treatment filter - should cache full results
    service1 = CardSearchService.new(query: query, treatments: [])
    results1 = service1.call

    # Second call with borderless filter - should use cache but filter locally
    service2 = CardSearchService.new(query: query, treatments: [ "borderless" ])
    results2 = service2.call

    assert_requested :get, scryfall_url(query), times: 1
    assert_equal 2, results1.size, "Expected all cards without filter"
    assert_equal 1, results2.size, "Expected filtered results"
    assert_includes results2.first[:treatments], "borderless"
  end

  test "cache key includes query but not treatments" do
    query = "Lightning Bolt"
    response = scryfall_response_with_card(
      id: "1", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
      collector_number: "157", image_url: "http://example.com/bolt.jpg",
      border_color: "borderless"
    )

    stub_scryfall_request(query, response)

    # Call with no treatments
    service1 = CardSearchService.new(query: query, treatments: [])
    service1.call

    # Call with treatments should use same cache
    service2 = CardSearchService.new(query: query, treatments: [ "borderless" ])
    service2.call

    assert_requested :get, scryfall_url(query), times: 1
  end

  test "handles empty results from API" do
    query = "NonexistentCard12345"

    stub_request(:get, scryfall_url(query))
      .to_return(
        status: 404,
        body: '{"object":"error","code":"not_found"}',
        headers: { "Content-Type" => "application/json" }
      )

    service1 = CardSearchService.new(query: query, treatments: [])
    results1 = service1.call

    service2 = CardSearchService.new(query: query, treatments: [])
    results2 = service2.call

    assert_requested :get, scryfall_url(query), times: 1
    assert_empty results1
    assert_empty results2
  end

  test "cache expires after configured TTL" do
    query = "Lightning Bolt"
    response = scryfall_response_with_card(
      id: "1", name: "Lightning Bolt", set: "lea", set_name: "Alpha",
      collector_number: "157", image_url: "http://example.com/bolt.jpg"
    )

    stub_scryfall_request(query, response)

    # First call
    service1 = CardSearchService.new(query: query, treatments: [])
    service1.call

    # Simulate cache expiration
    cache_key = "card_search:Lightning Bolt"
    Rails.cache.delete(cache_key)

    # Second call after cache expiration
    service2 = CardSearchService.new(query: query, treatments: [])
    service2.call

    assert_requested :get, scryfall_url(query), times: 2
  end

  # ---------------------------------------------------------------------------
  # Existing functionality tests (ensure we don't break anything)
  # ---------------------------------------------------------------------------
  test "formats card data correctly" do
    query = "Lightning Bolt"
    response = scryfall_response_with_card(
      id: "abc123",
      name: "Lightning Bolt",
      set: "lea",
      set_name: "Limited Edition Alpha",
      collector_number: "157",
      image_url: "https://example.com/bolt.jpg"
    )

    stub_scryfall_request(query, response)

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

  test "derives borderless treatment correctly" do
    query = "Test Card"
    response = scryfall_response_with_card(
      id: "1",
      name: "Test Card",
      set: "znr",
      set_name: "Zendikar Rising",
      collector_number: "1",
      image_url: "http://example.com/test.jpg",
      border_color: "borderless"
    )

    stub_scryfall_request(query, response)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_includes results.first[:treatments], "borderless"
  end

  private

  # Helper to build Scryfall API URL
  def scryfall_url(query)
    "https://api.scryfall.com/cards/search?q=#{CGI.escape(query)}"
  end

  # Helper to stub Scryfall API request
  def stub_scryfall_request(query, response_body)
    stub_request(:get, scryfall_url(query))
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Helper to create a Scryfall response with a single card
  def scryfall_response_with_card(attributes = {})
    default_card = {
      "id" => "test-123",
      "name" => "Test Card",
      "set" => "tst",
      "set_name" => "Test Set",
      "collector_number" => "1",
      "image_uris" => { "normal" => "http://example.com/test.jpg" },
      "border_color" => "black",
      "finishes" => ["nonfoil"]
    }

    # Handle image_url shortcut
    if attributes[:image_url]
      attributes["image_uris"] = { "normal" => attributes.delete(:image_url) }
    end

    {
      "object" => "list",
      "data" => [default_card.merge(attributes.transform_keys(&:to_s))]
    }
  end
end
