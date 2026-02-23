require "test_helper"
require "webmock/minitest"

class CardListFetcherIntegrationTest < ActiveSupport::TestCase
  # These tests use WebMock to stub the Scryfall API responses.
  # The stubs mirror the real Scryfall paginated list response structure.

  SCRYFALL_BASE = ApiEndpoints.scryfall_base

  # ---------------------------------------------------------------------------
  # Wizards Game Changers Integration Tests
  # ---------------------------------------------------------------------------

  test "fetch_game_changers retrieves real data from Wizards official source" do
    skip "Wizards.com uses JavaScript to render the Game Changers list (client-side only). " \
         "The HTML response doesn't contain the card data. " \
         "Use manual YAML file: config/card_lists/game_changers.yml"
  end

  # ---------------------------------------------------------------------------
  # Scryfall Reserved List Tests
  # ---------------------------------------------------------------------------

  test "fetch_reserved_list retrieves data from Scryfall" do
    stub_scryfall_reserved_list_paginated

    result = CardListFetcher.fetch_reserved_list

    assert_kind_of Array, result
    assert_operator result.length, :>, 0, "Should fetch at least one card"
    assert result.all? { |card| card.is_a?(String) }, "All cards should be strings"
    assert_equal result.sort, result, "Cards should be sorted alphabetically"
    assert_equal result.uniq, result, "Should not contain duplicates"

    # Known Reserved List cards present in our stub data
    assert_includes result, "Black Lotus"
    assert_includes result, "Mox Ruby"
    assert_includes result, "Time Walk"

    result.each do |card|
      assert_equal card.strip, card, "Card name should have no leading/trailing whitespace"
      refute_match(/\s{2,}/, card, "Card name should not have multiple consecutive spaces")
    end
  end

  test "handles Wizards HTML structure correctly" do
    skip "Wizards.com uses JavaScript rendering - no cards in initial HTML response"
  end

  test "handles Scryfall pagination correctly" do
    stub_scryfall_reserved_list_paginated

    result = CardListFetcher.fetch_reserved_list

    # Verify we collected cards from both pages of our stub
    assert_operator result.length, :>=, 4, "Should collect cards across all stubbed pages"
    assert_includes result, "Black Lotus",  "Should include cards from page 1"
    assert_includes result, "Volcanic Island", "Should include cards from page 2"
  end

  private

  # Stubs a two-page Scryfall reserved list response using the configured test base URL.
  # Page 1 returns a `next_page` pointing to page 2; page 2 has no `next_page`.
  def stub_scryfall_reserved_list_paginated
    page2_url = "#{SCRYFALL_BASE}/cards/search?order=name&page=2&q=is%3Areserved&unique=cards"

    page1_body = {
      "object" => "list",
      "total_cards" => 6,
      "has_more" => true,
      "next_page" => page2_url,
      "data" => [
        { "name" => "Black Lotus" },
        { "name" => "Mox Ruby" },
        { "name" => "Time Walk" }
      ]
    }.to_json

    page2_body = {
      "object" => "list",
      "total_cards" => 6,
      "has_more" => false,
      "data" => [
        { "name" => "Ancestral Recall" },
        { "name" => "Timetwister" },
        { "name" => "Volcanic Island" }
      ]
    }.to_json

    stub_request(:get, /#{Regexp.escape(SCRYFALL_BASE)}\/cards\/search\?q=is:reserved/)
      .to_return(status: 200, body: page1_body, headers: { "Content-Type" => "application/json" })

    stub_request(:get, page2_url)
      .to_return(status: 200, body: page2_body, headers: { "Content-Type" => "application/json" })
  end
end
