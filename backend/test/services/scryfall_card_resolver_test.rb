require "test_helper"
require "webmock/minitest"

class ScryfallCardResolverTest < ActiveSupport::TestCase
  setup do
    WebMock.reset!
    ScryfallCardResolver.clear_cache
  end

  # ---------------------------------------------------------------------------
  # Basic Functionality Tests
  # ---------------------------------------------------------------------------

  test "resolve_cards returns mapping of card_name to scryfall_id" do
    stub_scryfall_card("Sol Ring", "sol-ring-id")
    stub_scryfall_card("Lightning Bolt", "lightning-bolt-id")

    result = ScryfallCardResolver.resolve_cards(["Sol Ring", "Lightning Bolt"])

    assert_kind_of Hash, result
    assert_equal "sol-ring-id", result["Sol Ring"]
    assert_equal "lightning-bolt-id", result["Lightning Bolt"]
  end

  test "resolve_cards returns nil for cards that cannot be resolved" do
    stub_scryfall_card_not_found("Invalid Card Name")

    result = ScryfallCardResolver.resolve_cards(["Invalid Card Name"])

    assert_kind_of Hash, result
    assert_nil result["Invalid Card Name"]
  end

  test "resolve_cards handles mix of successful and failed resolutions" do
    stub_scryfall_card("Sol Ring", "sol-ring-id")
    stub_scryfall_card_not_found("Invalid Card")
    stub_scryfall_card("Lightning Bolt", "lightning-bolt-id")

    result = ScryfallCardResolver.resolve_cards(["Sol Ring", "Invalid Card", "Lightning Bolt"])

    assert_equal "sol-ring-id", result["Sol Ring"]
    assert_nil result["Invalid Card"]
    assert_equal "lightning-bolt-id", result["Lightning Bolt"]
  end

  test "resolve_cards caches successful lookups to avoid duplicate requests" do
    stub = stub_scryfall_card("Sol Ring", "sol-ring-id")

    # Call twice with same card name
    ScryfallCardResolver.resolve_cards(["Sol Ring"])
    ScryfallCardResolver.resolve_cards(["Sol Ring"])

    # Should only make one API request due to caching
    assert_requested stub, times: 1
  end

  test "resolve_cards uses fuzzy search endpoint" do
    stub = stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => "Sol Ring" })
      .to_return(
        status: 200,
        body: { id: "sol-ring-id", name: "Sol Ring" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    ScryfallCardResolver.resolve_cards(["Sol Ring"])

    assert_requested stub
  end

  test "resolve_cards enforces 100ms rate limit between requests" do
    stub_scryfall_card("Card 1", "id-1")
    stub_scryfall_card("Card 2", "id-2")

    start_time = Time.now
    ScryfallCardResolver.resolve_cards(["Card 1", "Card 2"])
    elapsed = Time.now - start_time

    # Should take at least 100ms for two requests
    assert elapsed >= 0.1, "Expected rate limiting delay of at least 100ms, got #{elapsed}s"
  end

  test "resolve_cards handles Scryfall 500 error gracefully" do
    stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => "Error Card" })
      .to_return(status: 500, body: "Internal Server Error")

    result = ScryfallCardResolver.resolve_cards(["Error Card"])

    assert_nil result["Error Card"]
  end

  test "resolve_cards handles Scryfall timeout gracefully" do
    stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => "Timeout Card" })
      .to_timeout

    result = ScryfallCardResolver.resolve_cards(["Timeout Card"])

    assert_nil result["Timeout Card"]
  end

  test "resolve_cards handles 429 rate limit with exponential backoff" do
    # First request returns 429, second succeeds
    stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => "Rate Limited Card" })
      .to_return(status: 429, body: "Rate limit exceeded")
      .then
      .to_return(
        status: 200,
        body: { id: "rate-limited-id", name: "Rate Limited Card" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = ScryfallCardResolver.resolve_cards(["Rate Limited Card"])

    assert_equal "rate-limited-id", result["Rate Limited Card"]
  end

  test "resolve_cards gives up after max retries on persistent 429" do
    # Always return 429
    stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => "Always Rate Limited" })
      .to_return(status: 429, body: "Rate limit exceeded")

    result = ScryfallCardResolver.resolve_cards(["Always Rate Limited"])

    assert_nil result["Always Rate Limited"]
  end

  test "resolve_cards handles card name variations with fuzzy search" do
    # Scryfall fuzzy search should handle apostrophe variations
    stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => "Atraxa, Praetors' Voice" })
      .to_return(
        status: 200,
        body: { id: "atraxa-id", name: "Atraxa, Praetors' Voice" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = ScryfallCardResolver.resolve_cards(["Atraxa, Praetors' Voice"])

    assert_equal "atraxa-id", result["Atraxa, Praetors' Voice"]
  end

  test "resolve_cards logs warnings for unresolved cards" do
    stub_scryfall_card_not_found("Invalid Card")

    logs = capture_log_output do
      ScryfallCardResolver.resolve_cards(["Invalid Card"])
    end

    assert_match(/warn.*could not resolve.*invalid card/i, logs)
  end

  test "resolve_cards logs rate limit events" do
    stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => "Rate Limited" })
      .to_return(status: 429, body: "Rate limit exceeded")
      .then
      .to_return(
        status: 200,
        body: { id: "id", name: "Rate Limited" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    logs = capture_log_output do
      ScryfallCardResolver.resolve_cards(["Rate Limited"])
    end

    assert_match(/warn.*rate limit.*429/i, logs)
  end

  private

  def stub_scryfall_card(card_name, scryfall_id)
    stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => card_name })
      .to_return(
        status: 200,
        body: { id: scryfall_id, name: card_name }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_scryfall_card_not_found(card_name)
    stub_request(:get, "https://api.scryfall.com/cards/named")
      .with(query: { "fuzzy" => card_name })
      .to_return(
        status: 404,
        body: { object: "error", code: "not_found", details: "No card found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def capture_log_output
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    yield

    log_output.string
  ensure
    Rails.logger = original_logger
  end
end
