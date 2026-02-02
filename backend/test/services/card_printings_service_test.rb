require "test_helper"
require "webmock/minitest"

class CardPrintingsServiceTest < ActiveSupport::TestCase
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
  # Core functionality tests
  # ---------------------------------------------------------------------------
  test "fetches all printings for a card from Scryfall using two-step API flow" do
    card_id = "f3c42c51-2e0f-4c5e-b1b1-6e3e6e5e3e5e"
    oracle_id = "4457ed35-7c10-48c8-9776-456485fdf070"
    prints_search_uri = "https://api.scryfall.com/cards/search?order=released&q=oracleid%3A#{oracle_id}&unique=prints"

    # Step 1: Stub the card endpoint to return prints_search_uri
    card_response = {
      "id" => card_id,
      "name" => "Lightning Bolt",
      "oracle_id" => oracle_id,
      "prints_search_uri" => prints_search_uri
    }
    stub_scryfall_card_request(card_id, card_response)

    # Step 2: Stub the prints_search_uri endpoint to return all printings
    printings_response = {
      "object" => "list",
      "has_more" => false,
      "data" => [
        {
          "id" => "f3c42c51-2e0f-4c5e-b1b1-6e3e6e5e3e5e",
          "name" => "Lightning Bolt",
          "set" => "lea",
          "set_name" => "Limited Edition Alpha",
          "collector_number" => "157",
          "image_uris" => { "normal" => "https://example.com/bolt-alpha.jpg" },
          "released_at" => "1993-08-05"
        },
        {
          "id" => "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6",
          "name" => "Lightning Bolt",
          "set" => "m10",
          "set_name" => "Magic 2010",
          "collector_number" => "146",
          "image_uris" => { "normal" => "https://example.com/bolt-m10.jpg" },
          "released_at" => "2009-07-17"
        }
      ]
    }
    stub_prints_search_request(prints_search_uri, printings_response)

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    # Verify both API calls were made
    assert_requested :get, scryfall_card_url(card_id), times: 1
    assert_requested :get, prints_search_uri, times: 1

    assert_equal 2, results.size
    # Results should be sorted newest first (M10 2009, then Alpha 1993)
    assert_equal "Lightning Bolt", results.first[:name]
    assert_equal "m10", results.first[:set]
    assert_equal "Magic 2010", results.first[:set_name]
    assert_equal "146", results.first[:collector_number]
    assert_equal "https://example.com/bolt-m10.jpg", results.first[:image_url]
    assert_equal "2009-07-17", results.first[:released_at]
  end

  test "formats card printing data correctly" do
    card_id = "test-card-id"
    prints_search_uri = "https://api.scryfall.com/cards/search?q=test"

    stub_two_step_flow(card_id, prints_search_uri, [
      {
        id: "abc123",
        name: "Test Card",
        set: "znr",
        set_name: "Zendikar Rising",
        collector_number: "42",
        image_url: "https://example.com/test.jpg",
        released_at: "2020-09-25"
      }
    ])

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    assert_equal 1, results.size
    result = results.first
    assert_equal "abc123", result[:id]
    assert_equal "Test Card", result[:name]
    assert_equal "znr", result[:set]
    assert_equal "Zendikar Rising", result[:set_name]
    assert_equal "42", result[:collector_number]
    assert_equal "https://example.com/test.jpg", result[:image_url]
    assert_equal "2020-09-25", result[:released_at]
  end

  test "sorts printings by release date, newest first" do
    card_id = "multi-printing-card"
    prints_search_uri = "https://api.scryfall.com/cards/search?q=test"

    stub_two_step_flow(card_id, prints_search_uri, [
      {
        id: "old-printing",
        name: "Card Name",
        set: "lea",
        set_name: "Alpha",
        collector_number: "1",
        image_url: "https://example.com/old.jpg",
        released_at: "1993-08-05"
      },
      {
        id: "new-printing",
        name: "Card Name",
        set: "m21",
        set_name: "Core Set 2021",
        collector_number: "1",
        image_url: "https://example.com/new.jpg",
        released_at: "2020-07-03"
      },
      {
        id: "mid-printing",
        name: "Card Name",
        set: "m10",
        set_name: "Magic 2010",
        collector_number: "1",
        image_url: "https://example.com/mid.jpg",
        released_at: "2009-07-17"
      }
    ])

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    assert_equal 3, results.size
    assert_equal "new-printing", results[0][:id], "Expected newest printing first"
    assert_equal "mid-printing", results[1][:id], "Expected middle printing second"
    assert_equal "old-printing", results[2][:id], "Expected oldest printing last"
  end

  test "handles card with no image_uris by using nil" do
    card_id = "no-image-card"
    prints_search_uri = "https://api.scryfall.com/cards/search?q=test"

    # Stub card endpoint
    card_response = {
      "id" => card_id,
      "prints_search_uri" => prints_search_uri
    }
    stub_scryfall_card_request(card_id, card_response)

    # Stub prints search with card that has no image_uris
    response = {
      "object" => "list",
      "has_more" => false,
      "data" => [
        {
          "id" => "no-image-id",
          "name" => "No Image Card",
          "set" => "tst",
          "set_name" => "Test Set",
          "collector_number" => "1",
          "released_at" => "2020-01-01"
          # No image_uris key
        }
      ]
    }
    stub_prints_search_request(prints_search_uri, response)

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    assert_equal 1, results.size
    assert_nil results.first[:image_url]
  end

  # ---------------------------------------------------------------------------
  # Caching behavior tests
  # ---------------------------------------------------------------------------
  test "caches printings results for identical card_id" do
    card_id = "cached-card"
    prints_search_uri = "https://api.scryfall.com/cards/search?q=test"

    stub_two_step_flow(card_id, prints_search_uri, [
      {
        id: "print1",
        name: "Cached Card",
        set: "tst",
        set_name: "Test",
        collector_number: "1",
        image_url: "https://example.com/test.jpg",
        released_at: "2020-01-01"
      }
    ])

    service1 = CardPrintingsService.new(card_id: card_id)
    results1 = service1.call

    # Second call with same card_id should use cache
    service2 = CardPrintingsService.new(card_id: card_id)
    results2 = service2.call

    # Should only make one set of HTTP requests (second uses cache)
    assert_requested :get, scryfall_card_url(card_id), times: 1
    assert_requested :get, prints_search_uri, times: 1
    assert_equal results1, results2, "Expected identical results from cache"
  end

  test "different card_ids generate separate cache entries" do
    card_id1 = "card-one"
    card_id2 = "card-two"
    prints_search_uri1 = "https://api.scryfall.com/cards/search?q=one"
    prints_search_uri2 = "https://api.scryfall.com/cards/search?q=two"

    stub_two_step_flow(card_id1, prints_search_uri1, [
      { id: "1", name: "Card One", set: "tst", set_name: "Test",
        collector_number: "1", image_url: "http://example.com/1.jpg", released_at: "2020-01-01" }
    ])
    stub_two_step_flow(card_id2, prints_search_uri2, [
      { id: "2", name: "Card Two", set: "tst", set_name: "Test",
        collector_number: "2", image_url: "http://example.com/2.jpg", released_at: "2020-01-01" }
    ])

    service1 = CardPrintingsService.new(card_id: card_id1)
    results1 = service1.call

    service2 = CardPrintingsService.new(card_id: card_id2)
    results2 = service2.call

    assert_requested :get, scryfall_card_url(card_id1), times: 1
    assert_requested :get, scryfall_card_url(card_id2), times: 1
    assert_requested :get, prints_search_uri1, times: 1
    assert_requested :get, prints_search_uri2, times: 1
    refute_equal results1, results2, "Expected different results for different cards"
  end

  # ---------------------------------------------------------------------------
  # Error handling tests
  # ---------------------------------------------------------------------------
  test "handles card not found (404) from first API call" do
    card_id = "nonexistent-card"

    stub_request(:get, scryfall_card_url(card_id))
      .to_return(
        status: 404,
        body: '{"object":"error","code":"not_found"}',
        headers: { "Content-Type" => "application/json" }
      )

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    assert_empty results
  end

  test "handles empty printings search results" do
    card_id = "no-printings-card"
    prints_search_uri = "https://api.scryfall.com/cards/search?q=test"

    # Card exists but has no printings
    card_response = {
      "id" => card_id,
      "prints_search_uri" => prints_search_uri
    }
    stub_scryfall_card_request(card_id, card_response)

    # Prints search returns empty data
    printings_response = {
      "object" => "list",
      "has_more" => false,
      "data" => []
    }
    stub_prints_search_request(prints_search_uri, printings_response)

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    assert_empty results
  end

  test "raises NetworkError on connection failure in first API call" do
    card_id = "network-error-card"

    stub_request(:get, scryfall_card_url(card_id))
      .to_raise(SocketError.new("Connection refused"))

    service = CardPrintingsService.new(card_id: card_id)

    assert_raises(CardPrintingsService::NetworkError) do
      service.call
    end
  end

  test "raises NetworkError on connection failure in second API call" do
    card_id = "network-error-card"
    prints_search_uri = "https://api.scryfall.com/cards/search?q=test"

    card_response = {
      "id" => card_id,
      "prints_search_uri" => prints_search_uri
    }
    stub_scryfall_card_request(card_id, card_response)

    stub_request(:get, prints_search_uri)
      .to_raise(SocketError.new("Connection refused"))

    service = CardPrintingsService.new(card_id: card_id)

    assert_raises(CardPrintingsService::NetworkError) do
      service.call
    end
  end

  test "raises TimeoutError on request timeout in first API call" do
    card_id = "timeout-card"

    stub_request(:get, scryfall_card_url(card_id))
      .to_timeout

    service = CardPrintingsService.new(card_id: card_id)

    assert_raises(CardPrintingsService::TimeoutError) do
      service.call
    end
  end

  test "raises RateLimitError on 429 response in first API call" do
    card_id = "rate-limited-card"

    stub_request(:get, scryfall_card_url(card_id))
      .to_return(
        status: 429,
        body: '{"object":"error","code":"rate_limit"}',
        headers: { "Content-Type" => "application/json" }
      )

    service = CardPrintingsService.new(card_id: card_id)

    assert_raises(CardPrintingsService::RateLimitError) do
      service.call
    end
  end

  test "raises InvalidResponseError on non-JSON response in first API call" do
    card_id = "bad-response-card"

    stub_request(:get, scryfall_card_url(card_id))
      .to_return(
        status: 200,
        body: "Not JSON",
        headers: { "Content-Type" => "text/html" }
      )

    service = CardPrintingsService.new(card_id: card_id)

    assert_raises(CardPrintingsService::InvalidResponseError) do
      service.call
    end
  end

  test "handles pagination when has_more is true" do
    card_id = "paginated-card"
    prints_search_uri = "https://api.scryfall.com/cards/search?q=test"
    next_page_uri = "https://api.scryfall.com/cards/search?q=test&page=2"

    # Stub card endpoint
    card_response = {
      "id" => card_id,
      "prints_search_uri" => prints_search_uri
    }
    stub_scryfall_card_request(card_id, card_response)

    # First page of printings
    first_page_response = {
      "object" => "list",
      "has_more" => true,
      "next_page" => next_page_uri,
      "data" => [
        {
          "id" => "card1",
          "name" => "Test Card",
          "set" => "set1",
          "set_name" => "Set 1",
          "collector_number" => "1",
          "image_uris" => { "normal" => "https://example.com/1.jpg" },
          "released_at" => "2020-01-01"
        }
      ]
    }
    stub_prints_search_request(prints_search_uri, first_page_response)

    # Second page of printings
    second_page_response = {
      "object" => "list",
      "has_more" => false,
      "data" => [
        {
          "id" => "card2",
          "name" => "Test Card",
          "set" => "set2",
          "set_name" => "Set 2",
          "collector_number" => "2",
          "image_uris" => { "normal" => "https://example.com/2.jpg" },
          "released_at" => "2019-01-01"
        }
      ]
    }
    stub_prints_search_request(next_page_uri, second_page_response)

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    # Should have results from both pages
    assert_equal 2, results.size
    assert_equal "card1", results[0][:id]
    assert_equal "card2", results[1][:id]

    # Verify all API calls were made
    assert_requested :get, scryfall_card_url(card_id), times: 1
    assert_requested :get, prints_search_uri, times: 1
    assert_requested :get, next_page_uri, times: 1
  end

  private

  # Helper to build Scryfall card API URL
  def scryfall_card_url(card_id)
    "https://api.scryfall.com/cards/#{card_id}"
  end

  # Helper to stub Scryfall card API request (first step)
  def stub_scryfall_card_request(card_id, response_body)
    stub_request(:get, scryfall_card_url(card_id))
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Helper to stub Scryfall prints search API request (second step)
  def stub_prints_search_request(prints_search_uri, response_body)
    stub_request(:get, prints_search_uri)
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Helper to stub the complete two-step flow
  def stub_two_step_flow(card_id, prints_search_uri, cards = [])
    # Step 1: Card endpoint returns prints_search_uri
    card_response = {
      "id" => card_id,
      "prints_search_uri" => prints_search_uri
    }
    stub_scryfall_card_request(card_id, card_response)

    # Step 2: Prints search endpoint returns card data
    printings_response = scryfall_printings_response_with_cards(cards)
    stub_prints_search_request(prints_search_uri, printings_response)
  end

  # Helper to create a Scryfall response with multiple card printings
  def scryfall_printings_response_with_cards(cards = [])
    default_card = {
      "id" => "test-123",
      "name" => "Test Card",
      "set" => "tst",
      "set_name" => "Test Set",
      "collector_number" => "1",
      "image_uris" => { "normal" => "http://example.com/test.jpg" },
      "released_at" => "2020-01-01"
    }

    formatted_cards = cards.map do |card_attrs|
      # Handle image_url shortcut
      if card_attrs[:image_url]
        card_attrs["image_uris"] = { "normal" => card_attrs.delete(:image_url) }
      end

      default_card.merge(card_attrs.transform_keys(&:to_s))
    end

    {
      "object" => "list",
      "has_more" => false,
      "data" => formatted_cards
    }
  end
end
