require "test_helper"
require "webmock/minitest"

# Integration tests for CardSearchService Scryfall API interaction
# Focus: HTTP requests, error handling, response mapping, and treatment detection
class CardSearchServiceScryfallTest < ActiveSupport::TestCase
  include CardSearchTestHelper

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
  # HTTP Request & Response Mapping Tests
  # ---------------------------------------------------------------------------

  test "makes HTTP request to Scryfall API with correct endpoint and query" do
    query = "Lightning Bolt"

    stub_scryfall_request(query, scryfall_response_fixture)

    service = CardSearchService.new(query: query, finishes: [])
    service.call

    assert_requested :get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/search\?q=Lightning/, times: 1
  end

  test "includes User-Agent header in API request" do
    query = "Black Lotus"

    stub_scryfall_request(query, scryfall_response_fixture)

    service = CardSearchService.new(query: query, finishes: [])
    service.call

    assert_requested :get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}/, headers: {
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

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
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

  test "retrieves only first page of results" do
    query = "Lightning Bolt"

    stub_scryfall_request(query, scryfall_response_fixture)

    service = CardSearchService.new(query: query, finishes: [])
    service.call

    # Verify no page parameter or page=1
    assert_requested :get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/search\?q=Lightning/
    assert_not_requested :get, /page=2/
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

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
    results = service.call

    assert_nil results.first[:image_url]
  end

  # ---------------------------------------------------------------------------
  # Treatment Detection Tests
  # ---------------------------------------------------------------------------

  test "detects foil treatment from finishes array" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      finishes: ["foil", "nonfoil"]
    )

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
    results = service.call

    assert_includes results.first[:treatments], "foil"
  end

  test "detects etched treatment from finishes array" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      finishes: ["etched"]
    )

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
    results = service.call

    assert_includes results.first[:treatments], "etched"
  end

  test "detects borderless treatment from border_color field" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      border_color: "borderless"
    )

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
    results = service.call

    assert_includes results.first[:treatments], "borderless"
  end

  test "detects showcase treatment from frame_effects array" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      frame_effects: ["showcase"]
    )

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
    results = service.call

    assert_includes results.first[:treatments], "showcase"
  end

  test "detects extended_art treatment from frame_effects array" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      frame_effects: ["extendedart"]
    )

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
    results = service.call

    assert_includes results.first[:treatments], "extended_art"
  end

  test "detects full_art treatment from full_art boolean" do
    query = "Test Card"
    scryfall_data = scryfall_response_with_card(
      full_art: true
    )

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
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

    stub_scryfall_request(query, scryfall_data)

    service = CardSearchService.new(query: query, finishes: [])
    results = service.call

    treatments = results.first[:treatments]
    assert_includes treatments, "foil"
    assert_includes treatments, "etched"
    assert_includes treatments, "borderless"
    assert_includes treatments, "showcase"
    assert_includes treatments, "full_art"
  end

  # ---------------------------------------------------------------------------
  # Error Handling Tests
  # ---------------------------------------------------------------------------

  test "handles network errors with appropriate exception" do
    query = "Test Card"

    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}/)
      .to_raise(SocketError.new("Failed to open TCP connection"))

    service = CardSearchService.new(query: query, finishes: [])

    error = assert_raises(CardSearchService::NetworkError) do
      service.call
    end

    assert_match /network/i, error.message
  end

  test "handles timeout errors with appropriate exception" do
    query = "Test Card"

    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}/)
      .to_timeout

    service = CardSearchService.new(query: query, finishes: [])

    error = assert_raises(CardSearchService::TimeoutError) do
      service.call
    end

    assert_match /timeout/i, error.message
  end

  test "handles 404 not found with empty results" do
    query = "NonexistentCard99999"

    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}/)
      .to_return(
        status: 404,
        body: '{"object":"error","code":"not_found","details":"No cards found"}'
      )

    service = CardSearchService.new(query: query, finishes: [])
    results = service.call

    assert_empty results
  end

  test "handles invalid JSON response with appropriate exception" do
    query = "Test Card"

    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}/)
      .to_return(status: 200, body: "Invalid JSON {{{")

    service = CardSearchService.new(query: query, finishes: [])

    error = assert_raises(CardSearchService::InvalidResponseError) do
      service.call
    end

    assert_match /invalid.*response/i, error.message
  end

  private

  # Helper: Create a minimal valid Scryfall response fixture
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
end
