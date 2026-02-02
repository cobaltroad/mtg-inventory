require "test_helper"
require "webmock/minitest"

class CardSearchServiceScryfallTest < ActiveSupport::TestCase
  # Disable parallelization to ensure cache and WebMock work correctly
  parallelize(workers: 1)

  setup do
    # Use a real cache store for testing caching behavior
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear

    # Reset WebMock for each test
    WebMock.reset!
  end

  teardown do
    Rails.cache = @original_cache
  end

  # ---------------------------------------------------------------------------
  # Scryfall API Integration Tests
  # ---------------------------------------------------------------------------

  test "makes HTTP request to Scryfall API with correct endpoint and query" do
    query = "Lightning Bolt"
    expected_url = "https://api.scryfall.com/cards/search?q=Lightning+Bolt"

    stub_scryfall_success(query, scryfall_response_fixture)

    service = CardSearchService.new(query: query, treatments: [])
    service.call

    assert_requested :get, expected_url, times: 1
  end

  test "includes User-Agent header in API request" do
    query = "Black Lotus"

    stub_scryfall_success(query, scryfall_response_fixture)

    service = CardSearchService.new(query: query, treatments: [])
    service.call

    assert_requested :get, /api\.scryfall\.com/, headers: {
      "User-Agent" => /mtg-inventory/
    }
  end

  test "maps Scryfall response to expected format" do
    query = "Lightning Bolt"
    scryfall_data = {
      "object" => "list",
      "data" => [
        {
          "id" => "abc-123-def",
          "name" => "Lightning Bolt",
          "set" => "lea",
          "set_name" => "Limited Edition Alpha",
          "collector_number" => "157",
          "image_uris" => {
            "normal" => "https://example.com/bolt.jpg"
          },
          "border_color" => "black",
          "finishes" => ["nonfoil"],
          "frame_effects" => []
        }
      ]
    }

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_equal 1, results.size
    card = results.first

    assert_equal "abc-123-def", card[:id]
    assert_equal "Lightning Bolt", card[:name]
    assert_equal "lea", card[:set]
    assert_equal "Limited Edition Alpha", card[:set_name]
    assert_equal "157", card[:collector_number]
    assert_equal "https://example.com/bolt.jpg", card[:image_url]
    assert_kind_of Array, card[:treatments]
  end

  test "detects foil treatment from finishes array" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      finishes: ["foil", "nonfoil"]
    )

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_includes results.first[:treatments], "foil"
  end

  test "detects etched treatment from finishes array" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      finishes: ["etched"]
    )

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_includes results.first[:treatments], "etched"
  end

  test "detects borderless treatment from border_color field" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      border_color: "borderless"
    )

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_includes results.first[:treatments], "borderless"
  end

  test "detects showcase treatment from frame_effects array" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      frame_effects: ["showcase"]
    )

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_includes results.first[:treatments], "showcase"
  end

  test "detects extended_art treatment from frame_effects array" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      frame_effects: ["extendedart"]
    )

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_includes results.first[:treatments], "extended_art"
  end

  test "detects full_art treatment from full_art boolean" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      full_art: true
    )

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_includes results.first[:treatments], "full_art"
  end

  test "detects multiple treatments on single card" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      finishes: ["foil", "etched"],
      border_color: "borderless",
      frame_effects: ["showcase"],
      full_art: true
    )

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    treatments = results.first[:treatments]
    assert_includes treatments, "foil"
    assert_includes treatments, "etched"
    assert_includes treatments, "borderless"
    assert_includes treatments, "showcase"
    assert_includes treatments, "full_art"
  end

  test "handles cards without image_uris gracefully" do
    query = "Test Card"
    scryfall_data = {
      "object" => "list",
      "data" => [
        {
          "id" => "abc-123",
          "name" => "Test Card",
          "set" => "lea",
          "set_name" => "Alpha",
          "collector_number" => "1",
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        }
      ]
    }

    stub_scryfall_success(query, scryfall_data)

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_nil results.first[:image_url]
  end

  test "retrieves only first page of results" do
    query = "Lightning Bolt"
    expected_url = "https://api.scryfall.com/cards/search?q=Lightning+Bolt"

    stub_scryfall_success(query, scryfall_response_fixture)

    service = CardSearchService.new(query: query, treatments: [])
    service.call

    # Verify no page parameter or page=1
    assert_requested :get, expected_url
    assert_not_requested :get, /page=2/
  end

  # ---------------------------------------------------------------------------
  # Error Handling Tests
  # ---------------------------------------------------------------------------

  test "handles rate limit error (429) with appropriate exception" do
    query = "Test Card"

    stub_request(:get, /api\.scryfall\.com/)
      .to_return(status: 429, body: '{"object":"error","code":"rate_limit_exceeded"}')

    service = CardSearchService.new(query: query, treatments: [])

    error = assert_raises(CardSearchService::RateLimitError) do
      service.call
    end

    assert_match /rate limit/i, error.message
  end

  test "handles network errors with appropriate exception" do
    query = "Test Card"

    stub_request(:get, /api\.scryfall\.com/)
      .to_raise(SocketError.new("Failed to open TCP connection"))

    service = CardSearchService.new(query: query, treatments: [])

    error = assert_raises(CardSearchService::NetworkError) do
      service.call
    end

    assert_match /network/i, error.message
  end

  test "handles timeout errors with appropriate exception" do
    query = "Test Card"

    stub_request(:get, /api\.scryfall\.com/)
      .to_timeout

    service = CardSearchService.new(query: query, treatments: [])

    error = assert_raises(CardSearchService::TimeoutError) do
      service.call
    end

    assert_match /timeout/i, error.message
  end

  test "handles 404 not found with empty results" do
    query = "NonexistentCard99999"

    stub_request(:get, /api\.scryfall\.com/)
      .to_return(
        status: 404,
        body: '{"object":"error","code":"not_found","details":"No cards found"}'
      )

    service = CardSearchService.new(query: query, treatments: [])
    results = service.call

    assert_empty results
  end

  test "handles invalid JSON response with appropriate exception" do
    query = "Test Card"

    stub_request(:get, /api\.scryfall\.com/)
      .to_return(status: 200, body: "Invalid JSON {{{")

    service = CardSearchService.new(query: query, treatments: [])

    error = assert_raises(CardSearchService::InvalidResponseError) do
      service.call
    end

    assert_match /invalid.*response/i, error.message
  end

  # ---------------------------------------------------------------------------
  # Caching Tests (ensure cache still works with Scryfall)
  # ---------------------------------------------------------------------------

  test "caches Scryfall API results for identical query" do
    query = "Lightning Bolt"

    stub_scryfall_success(query, scryfall_response_fixture)

    service1 = CardSearchService.new(query: query, treatments: [])
    results1 = service1.call

    # Second call should use cache
    service2 = CardSearchService.new(query: query, treatments: [])
    results2 = service2.call

    # Should only make one HTTP request
    assert_requested :get, /api\.scryfall\.com/, times: 1
    assert_equal results1, results2
  end

  test "treatment filtering works with cached Scryfall results" do
    query = "Lightning Bolt"
    scryfall_data = {
      "object" => "list",
      "data" => [
        {
          "id" => "1",
          "name" => "Lightning Bolt",
          "set" => "lea",
          "set_name" => "Alpha",
          "collector_number" => "157",
          "border_color" => "borderless",
          "finishes" => ["foil"],
          "image_uris" => { "normal" => "http://example.com/1.jpg" }
        },
        {
          "id" => "2",
          "name" => "Lightning Bolt",
          "set" => "m11",
          "set_name" => "M11",
          "collector_number" => "149",
          "border_color" => "black",
          "finishes" => ["nonfoil"],
          "image_uris" => { "normal" => "http://example.com/2.jpg" }
        }
      ]
    }

    stub_scryfall_success(query, scryfall_data)

    # First call without filter
    service1 = CardSearchService.new(query: query, treatments: [])
    results1 = service1.call

    # Second call with borderless filter should use cache
    service2 = CardSearchService.new(query: query, treatments: ["borderless"])
    results2 = service2.call

    assert_requested :get, /api\.scryfall\.com/, times: 1
    assert_equal 2, results1.size
    assert_equal 1, results2.size
    assert_includes results2.first[:treatments], "borderless"
  end

  private

  # Helper: stub a successful Scryfall API response
  def stub_scryfall_success(query, response_body)
    encoded_query = CGI.escape(query)
    stub_request(:get, "https://api.scryfall.com/cards/search?q=#{encoded_query}")
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Helper: create a minimal valid Scryfall response
  def scryfall_response_fixture
    {
      "object" => "list",
      "data" => [
        {
          "id" => "abc-123-def",
          "name" => "Lightning Bolt",
          "set" => "lea",
          "set_name" => "Limited Edition Alpha",
          "collector_number" => "157",
          "image_uris" => {
            "normal" => "https://example.com/bolt.jpg"
          },
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        }
      ]
    }
  end

  # Helper: create a response with a single card with custom attributes
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

    {
      "object" => "list",
      "data" => [default_card.merge(attributes.transform_keys(&:to_s))]
    }
  end
end
