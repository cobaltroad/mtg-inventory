require "test_helper"

class CardListFetcherIntegrationTest < ActiveSupport::TestCase
  # These tests use VCR to record actual HTTP responses from external services
  # Run with cassettes deleted to re-record: rm -rf test/fixtures/vcr_cassettes/card_list_*

  # ---------------------------------------------------------------------------
  # Moxfield Game Changers Integration Tests
  # ---------------------------------------------------------------------------

  test "fetch_game_changers retrieves real data from Moxfield" do
    skip "Moxfield blocks automated requests with Cloudflare bot protection (403). " \
         "Use manual YAML file maintenance instead. See config/card_lists/game_changers.yml"

    VCR.use_cassette("card_list_fetcher/moxfield_game_changers") do
      result = CardListFetcher.fetch_game_changers

      # Basic structure validation
      assert_kind_of Array, result
      assert_operator result.length, :>, 0, "Should fetch at least one card"

      # All items should be strings
      assert result.all? { |card| card.is_a?(String) }, "All cards should be strings"

      # Should be alphabetically sorted
      assert_equal result.sort, result, "Cards should be sorted alphabetically"

      # Should not have duplicates
      assert_equal result.uniq, result, "Should not contain duplicates"

      # Known Game Changers (as of February 2026)
      # These cards are confirmed to be on the list
      expected_cards = [
        "Dockside Extortionist",
        "Jeweled Lotus",
        "Mana Crypt"
      ]

      expected_cards.each do |card|
        assert_includes result, card, "Expected Game Changers list to include #{card}"
      end

      # All cards should be normalized (no leading/trailing whitespace)
      result.each do |card|
        assert_equal card.strip, card, "Card name should have no leading/trailing whitespace"
        refute_match(/\s{2,}/, card, "Card name should not have multiple consecutive spaces")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Scryfall Reserved List Integration Tests
  # ---------------------------------------------------------------------------

  test "fetch_reserved_list retrieves real data from Scryfall" do
    VCR.use_cassette("card_list_fetcher/scryfall_reserved_list") do
      result = CardListFetcher.fetch_reserved_list

      # Basic structure validation
      assert_kind_of Array, result
      assert_operator result.length, :>, 200, "Reserved list should have more than 200 cards"

      # All items should be strings
      assert result.all? { |card| card.is_a?(String) }, "All cards should be strings"

      # Should be alphabetically sorted
      assert_equal result.sort, result, "Cards should be sorted alphabetically"

      # Should not have duplicates
      assert_equal result.uniq, result, "Should not contain duplicates"

      # Known Reserved List cards (these are guaranteed to be on the list)
      expected_cards = [
        "Black Lotus",
        "Gaea's Cradle",
        "Lion's Eye Diamond",
        "Mox Ruby",
        "Time Walk"
      ]

      expected_cards.each do |card|
        assert_includes result, card, "Expected Reserved List to include #{card}"
      end

      # All cards should be normalized
      result.each do |card|
        assert_equal card.strip, card, "Card name should have no leading/trailing whitespace"
        refute_match(/\s{2,}/, card, "Card name should not have multiple consecutive spaces")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Error Handling with Real Responses
  # ---------------------------------------------------------------------------

  test "handles Moxfield HTML structure correctly" do
    skip "Moxfield blocks automated requests with Cloudflare bot protection (403)"

    VCR.use_cassette("card_list_fetcher/moxfield_game_changers") do
      # This test verifies we can parse the actual HTML structure
      # If Moxfield changes their HTML, this test will fail and we'll know to update the parser
      assert_nothing_raised do
        CardListFetcher.fetch_game_changers
      end
    end
  end

  test "handles Scryfall pagination correctly" do
    VCR.use_cassette("card_list_fetcher/scryfall_reserved_list") do
      # Scryfall returns paginated results (175 cards per page)
      # This test verifies we're fetching all pages
      result = CardListFetcher.fetch_reserved_list

      # Reserved list has approximately 572 cards (as of 2024)
      # If we get significantly fewer, pagination is broken
      assert_operator result.length, :>=, 500, "Should fetch all pages from Scryfall (expected 500+ cards)"
    end
  end
end
