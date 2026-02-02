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
  test "fetches all printings for a card from Scryfall" do
    card_id = "f3c42c51-2e0f-4c5e-b1b1-6e3e6e5e3e5e"
    scryfall_response = {
      "object" => "list",
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

    stub_scryfall_printings_request(card_id, scryfall_response)

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

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
    response = scryfall_printings_response_with_cards([
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

    stub_scryfall_printings_request(card_id, response)

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
    response = scryfall_printings_response_with_cards([
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

    stub_scryfall_printings_request(card_id, response)

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    assert_equal 3, results.size
    assert_equal "new-printing", results[0][:id], "Expected newest printing first"
    assert_equal "mid-printing", results[1][:id], "Expected middle printing second"
    assert_equal "old-printing", results[2][:id], "Expected oldest printing last"
  end

  test "handles card with no image_uris by using nil" do
    card_id = "no-image-card"
    response = {
      "object" => "list",
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

    stub_scryfall_printings_request(card_id, response)

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
    response = scryfall_printings_response_with_cards([
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

    stub_scryfall_printings_request(card_id, response)

    service1 = CardPrintingsService.new(card_id: card_id)
    results1 = service1.call

    # Second call with same card_id should use cache
    service2 = CardPrintingsService.new(card_id: card_id)
    results2 = service2.call

    # Should only make one HTTP request (second uses cache)
    assert_requested :get, scryfall_printings_url(card_id), times: 1
    assert_equal results1, results2, "Expected identical results from cache"
  end

  test "different card_ids generate separate cache entries" do
    card_id1 = "card-one"
    card_id2 = "card-two"

    response1 = scryfall_printings_response_with_cards([
      { id: "1", name: "Card One", set: "tst", set_name: "Test",
        collector_number: "1", image_url: "http://example.com/1.jpg", released_at: "2020-01-01" }
    ])
    response2 = scryfall_printings_response_with_cards([
      { id: "2", name: "Card Two", set: "tst", set_name: "Test",
        collector_number: "2", image_url: "http://example.com/2.jpg", released_at: "2020-01-01" }
    ])

    stub_scryfall_printings_request(card_id1, response1)
    stub_scryfall_printings_request(card_id2, response2)

    service1 = CardPrintingsService.new(card_id: card_id1)
    results1 = service1.call

    service2 = CardPrintingsService.new(card_id: card_id2)
    results2 = service2.call

    assert_requested :get, scryfall_printings_url(card_id1), times: 1
    assert_requested :get, scryfall_printings_url(card_id2), times: 1
    refute_equal results1, results2, "Expected different results for different cards"
  end

  # ---------------------------------------------------------------------------
  # Error handling tests
  # ---------------------------------------------------------------------------
  test "handles empty results from API" do
    card_id = "nonexistent-card"

    stub_request(:get, scryfall_printings_url(card_id))
      .to_return(
        status: 404,
        body: '{"object":"error","code":"not_found"}',
        headers: { "Content-Type" => "application/json" }
      )

    service = CardPrintingsService.new(card_id: card_id)
    results = service.call

    assert_empty results
  end

  test "raises NetworkError on connection failure" do
    card_id = "network-error-card"

    stub_request(:get, scryfall_printings_url(card_id))
      .to_raise(SocketError.new("Connection refused"))

    service = CardPrintingsService.new(card_id: card_id)

    assert_raises(CardPrintingsService::NetworkError) do
      service.call
    end
  end

  test "raises TimeoutError on request timeout" do
    card_id = "timeout-card"

    stub_request(:get, scryfall_printings_url(card_id))
      .to_timeout

    service = CardPrintingsService.new(card_id: card_id)

    assert_raises(CardPrintingsService::TimeoutError) do
      service.call
    end
  end

  test "raises RateLimitError on 429 response" do
    card_id = "rate-limited-card"

    stub_request(:get, scryfall_printings_url(card_id))
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

  test "raises InvalidResponseError on non-JSON response" do
    card_id = "bad-response-card"

    stub_request(:get, scryfall_printings_url(card_id))
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

  private

  # Helper to build Scryfall printings API URL
  def scryfall_printings_url(card_id)
    "https://api.scryfall.com/cards/#{card_id}/prints"
  end

  # Helper to stub Scryfall printings API request
  def stub_scryfall_printings_request(card_id, response_body)
    stub_request(:get, scryfall_printings_url(card_id))
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
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
      "data" => formatted_cards
    }
  end
end
