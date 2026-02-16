require "test_helper"
require "webmock/minitest"

class CardListFetcherTest < ActiveSupport::TestCase
  setup do
    WebMock.reset!
    RateLimiter.clear_all_state
  end

  # ---------------------------------------------------------------------------
  # Game Changers - Basic Functionality Tests
  # ---------------------------------------------------------------------------

  test "fetch_game_changers returns array of card names" do
    stub_moxfield_game_changers

    result = CardListFetcher.fetch_game_changers

    assert_kind_of Array, result
    assert_operator result.length, :>, 0, "Expected at least one card in Game Changers list"
  end

  test "fetch_game_changers returns normalized card names" do
    stub_moxfield_game_changers

    result = CardListFetcher.fetch_game_changers

    result.each do |card_name|
      assert_kind_of String, card_name
      assert_equal card_name.strip, card_name, "Card name should have no leading/trailing whitespace"
      refute_match(/\s{2,}/, card_name, "Card name should not have multiple consecutive spaces")
    end
  end

  test "fetch_game_changers returns alphabetically sorted list" do
    stub_moxfield_game_changers

    result = CardListFetcher.fetch_game_changers

    assert_equal result.sort, result, "Card names should be sorted alphabetically"
  end

  test "fetch_game_changers includes known game changer cards" do
    stub_moxfield_game_changers

    result = CardListFetcher.fetch_game_changers

    # These are known Game Changers as of the Commander Bracket announcement
    known_cards = ["Dockside Extortionist", "Jeweled Lotus", "Mana Crypt"]
    known_cards.each do |card|
      assert_includes result, card, "Expected Game Changers list to include #{card}"
    end
  end

  test "fetch_game_changers removes duplicate card names" do
    stub_moxfield_game_changers_with_duplicates

    result = CardListFetcher.fetch_game_changers

    assert_equal result.uniq, result, "Result should not contain duplicate card names"
  end

  test "fetch_game_changers handles unicode characters correctly" do
    stub_moxfield_game_changers_with_unicode

    result = CardListFetcher.fetch_game_changers

    # Should preserve unicode characters like æ
    assert_includes result, "Juzám Djinn", "Should preserve unicode characters"
  end

  test "fetch_game_changers handles double-faced cards by using front face" do
    stub_moxfield_game_changers_with_dfc

    result = CardListFetcher.fetch_game_changers

    # If a double-faced card is present, should use front face only
    assert_includes result, "Delver of Secrets", "Should use front face of double-faced card"
    refute_includes result, "Delver of Secrets // Insectile Aberration", "Should not include full DFC name"
  end

  # ---------------------------------------------------------------------------
  # Game Changers - Error Handling Tests
  # ---------------------------------------------------------------------------

  test "fetch_game_changers raises FetchError on network timeout" do
    stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .to_timeout

    error = assert_raises(CardListFetcher::FetchError) do
      CardListFetcher.fetch_game_changers
    end

    assert_match(/network error|timeout/i, error.message)
  end

  test "fetch_game_changers raises FetchError on 404 status" do
    stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .to_return(status: 404, body: "Not Found")

    error = assert_raises(CardListFetcher::FetchError) do
      CardListFetcher.fetch_game_changers
    end

    assert_match(/404|not found/i, error.message)
  end

  test "fetch_game_changers raises FetchError on 500 status" do
    stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .to_return(status: 500, body: "Internal Server Error")

    error = assert_raises(CardListFetcher::FetchError) do
      CardListFetcher.fetch_game_changers
    end

    assert_match(/500|server error/i, error.message)
  end

  test "fetch_game_changers raises ParseError when HTML structure is invalid" do
    stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .to_return(status: 200, body: "<html><body>No card data here</body></html>")

    error = assert_raises(CardListFetcher::ParseError) do
      CardListFetcher.fetch_game_changers
    end

    assert_match(/parse|extract|structure/i, error.message)
  end

  test "fetch_game_changers includes browser headers to avoid 403 errors" do
    # Moxfield blocks requests without proper browser headers
    expected_headers = {
      "User-Agent" => /Mozilla.*Chrome.*Safari/,  # Browser-like User-Agent
      "Accept" => /text\/html/,
      "Accept-Language" => /en/,
      "Connection" => "keep-alive"
    }

    stub = stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .with(headers: expected_headers)
      .to_return(status: 200, body: build_moxfield_html(["Mana Crypt"]))

    CardListFetcher.fetch_game_changers

    assert_requested stub
  end

  # ---------------------------------------------------------------------------
  # Reserved List - Basic Functionality Tests
  # ---------------------------------------------------------------------------

  test "fetch_reserved_list returns array of card names" do
    stub_scryfall_reserved_list

    result = CardListFetcher.fetch_reserved_list

    assert_kind_of Array, result
    assert_operator result.length, :>, 0, "Expected at least one card in Reserved List"
  end

  test "fetch_reserved_list returns normalized card names" do
    stub_scryfall_reserved_list

    result = CardListFetcher.fetch_reserved_list

    result.each do |card_name|
      assert_kind_of String, card_name
      assert_equal card_name.strip, card_name, "Card name should have no leading/trailing whitespace"
      refute_match(/\s{2,}/, card_name, "Card name should not have multiple consecutive spaces")
    end
  end

  test "fetch_reserved_list returns alphabetically sorted list" do
    stub_scryfall_reserved_list

    result = CardListFetcher.fetch_reserved_list

    assert_equal result.sort, result, "Card names should be sorted alphabetically"
  end

  test "fetch_reserved_list includes known reserved list cards" do
    stub_scryfall_reserved_list

    result = CardListFetcher.fetch_reserved_list

    # These are known Reserved List cards
    known_cards = ["Black Lotus", "Gaea's Cradle", "Lion's Eye Diamond"]
    known_cards.each do |card|
      assert_includes result, card, "Expected Reserved List to include #{card}"
    end
  end

  test "fetch_reserved_list handles paginated Scryfall results" do
    stub_scryfall_reserved_list_paginated

    result = CardListFetcher.fetch_reserved_list

    # Should fetch all pages and combine results
    assert_operator result.length, :>=, 200, "Expected at least 200 cards from paginated results"
  end

  test "fetch_reserved_list removes duplicate card names" do
    stub_scryfall_reserved_list_with_duplicates

    result = CardListFetcher.fetch_reserved_list

    assert_equal result.uniq, result, "Result should not contain duplicate card names"
  end

  test "fetch_reserved_list uses RateLimiter for Scryfall requests" do
    stub_scryfall_reserved_list_paginated

    # Create a mock rate limiter that tracks calls
    throttle_called = false
    mock_rate_limiter = Object.new
    mock_rate_limiter.define_singleton_method(:throttle) do
      throttle_called = true
    end

    # Stub the factory method to return our mock
    RateLimiter.stub(:for_scryfall, mock_rate_limiter) do
      CardListFetcher.fetch_reserved_list
    end

    assert throttle_called, "Expected RateLimiter throttle method to be called"
  end

  # ---------------------------------------------------------------------------
  # Reserved List - Error Handling Tests
  # ---------------------------------------------------------------------------

  test "fetch_reserved_list raises FetchError on network timeout" do
    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_timeout

    error = assert_raises(CardListFetcher::FetchError) do
      CardListFetcher.fetch_reserved_list
    end

    assert_match(/network error|timeout/i, error.message)
  end

  test "fetch_reserved_list raises FetchError on 404 status" do
    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_return(status: 404, body: '{"object":"error","code":"not_found"}')

    error = assert_raises(CardListFetcher::FetchError) do
      CardListFetcher.fetch_reserved_list
    end

    assert_match(/404|not found/i, error.message)
  end

  test "fetch_reserved_list raises FetchError on 500 status" do
    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_return(status: 500, body: '{"object":"error"}')

    error = assert_raises(CardListFetcher::FetchError) do
      CardListFetcher.fetch_reserved_list
    end

    assert_match(/500|server error/i, error.message)
  end

  test "fetch_reserved_list raises ParseError when JSON structure is invalid" do
    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_return(status: 200, body: '{"invalid": "structure"}')

    error = assert_raises(CardListFetcher::ParseError) do
      CardListFetcher.fetch_reserved_list
    end

    assert_match(/parse|data|structure/i, error.message)
  end

  test "fetch_reserved_list raises ParseError when JSON is malformed" do
    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_return(status: 200, body: "invalid json")

    error = assert_raises(CardListFetcher::ParseError) do
      CardListFetcher.fetch_reserved_list
    end

    assert_match(/parse|json/i, error.message)
  end

  test "fetch_reserved_list includes polite User-Agent header" do
    stub = stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .with(headers: { "User-Agent" => "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)" })
      .to_return(status: 200, body: build_scryfall_json(["Mox Ruby"]))

    CardListFetcher.fetch_reserved_list

    assert_requested stub
  end

  private

  # ---------------------------------------------------------------------------
  # Test Helpers - Moxfield Stubs
  # ---------------------------------------------------------------------------

  def stub_moxfield_game_changers
    html = build_moxfield_html([
      "Dockside Extortionist",
      "Jeweled Lotus",
      "Mana Crypt",
      "Mana Vault",
      "Sol Ring"
    ])

    stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })
  end

  def stub_moxfield_game_changers_with_duplicates
    html = build_moxfield_html([
      "Dockside Extortionist",
      "Jeweled Lotus",
      "Jeweled Lotus",  # Duplicate
      "Mana Crypt"
    ])

    stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .to_return(status: 200, body: html)
  end

  def stub_moxfield_game_changers_with_unicode
    html = build_moxfield_html([
      "Juzám Djinn",
      "Dockside Extortionist"
    ])

    stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .to_return(status: 200, body: html)
  end

  def stub_moxfield_game_changers_with_dfc
    # Moxfield might include double-faced cards with // separator
    html = build_moxfield_html([
      "Delver of Secrets // Insectile Aberration",
      "Dockside Extortionist"
    ])

    stub_request(:get, "https://moxfield.com/commanderbrackets/gamechangers")
      .to_return(status: 200, body: html)
  end

  def build_moxfield_html(card_names)
    # Build a minimal HTML structure that mimics Moxfield's page
    # The actual structure will need to be adjusted based on real page inspection
    cards_html = card_names.map do |name|
      %(<div class="card-name">#{name}</div>)
    end.join("\n")

    <<~HTML
      <html>
      <head><title>Game Changers - Moxfield</title></head>
      <body>
        <div class="card-list">
          #{cards_html}
        </div>
      </body>
      </html>
    HTML
  end

  # ---------------------------------------------------------------------------
  # Test Helpers - Scryfall Stubs
  # ---------------------------------------------------------------------------

  def stub_scryfall_reserved_list
    json = build_scryfall_json([
      "Black Lotus",
      "Gaea's Cradle",
      "Lion's Eye Diamond",
      "Mox Ruby",
      "Time Walk"
    ])

    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_return(status: 200, body: json, headers: { "Content-Type" => "application/json" })
  end

  def stub_scryfall_reserved_list_paginated
    # First page
    page1_json = build_scryfall_json_with_pagination(
      (1..175).map { |i| "Reserved Card #{i}" },
      has_more: true,
      next_page: "https://api.scryfall.com/cards/search?q=is:reserved&page=2"
    )

    # Second page
    page2_json = build_scryfall_json_with_pagination(
      (176..300).map { |i| "Reserved Card #{i}" },
      has_more: false
    )

    stub_request(:get, "https://api.scryfall.com/cards/search?q=is:reserved")
      .to_return(status: 200, body: page1_json, headers: { "Content-Type" => "application/json" })

    stub_request(:get, "https://api.scryfall.com/cards/search?q=is:reserved&page=2")
      .to_return(status: 200, body: page2_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_scryfall_reserved_list_with_duplicates
    # Scryfall might return multiple printings of the same card
    json = build_scryfall_json([
      "Black Lotus",
      "Black Lotus",  # Different printing
      "Gaea's Cradle"
    ])

    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_return(status: 200, body: json)
  end

  def build_scryfall_json(card_names)
    cards = card_names.map do |name|
      {
        id: SecureRandom.uuid,
        name: name,
        object: "card"
      }
    end

    {
      object: "list",
      total_cards: cards.length,
      has_more: false,
      data: cards
    }.to_json
  end

  def build_scryfall_json_with_pagination(card_names, has_more:, next_page: nil)
    cards = card_names.map do |name|
      {
        id: SecureRandom.uuid,
        name: name,
        object: "card"
      }
    end

    result = {
      object: "list",
      total_cards: 300,  # Total across all pages
      has_more: has_more,
      data: cards
    }

    result[:next_page] = next_page if next_page

    result.to_json
  end
end
