require "test_helper"
require "webmock/minitest"
require "cgi"

class EdhrecScraperTest < ActiveSupport::TestCase
  setup do
    WebMock.reset!
    ScryfallCardResolver.clear_cache
  end

  # ---------------------------------------------------------------------------
  # Basic Functionality Tests
  # ---------------------------------------------------------------------------

  test "fetch_top_commanders returns array of 20 commander hashes" do
    stub_edhrec_json_api

    result = EdhrecScraper.fetch_top_commanders

    assert_kind_of Array, result
    assert_equal 20, result.length
  end

  test "each commander hash has required keys name, rank, and url" do
    stub_edhrec_json_api

    result = EdhrecScraper.fetch_top_commanders

    result.each do |commander|
      assert_kind_of Hash, commander
      assert_includes commander.keys, :name
      assert_includes commander.keys, :rank
      assert_includes commander.keys, :url
    end
  end

  test "commander ranks are sequential from 1 to 20" do
    stub_edhrec_json_api

    result = EdhrecScraper.fetch_top_commanders

    ranks = result.map { |c| c[:rank] }
    assert_equal (1..20).to_a, ranks
  end

  test "commander URLs are properly formatted with full domain" do
    stub_edhrec_json_api

    result = EdhrecScraper.fetch_top_commanders

    result.each do |commander|
      assert_match %r{\Ahttps://edhrec\.com/commanders/}, commander[:url],
        "Expected URL to start with https://edhrec.com/commanders/, got: #{commander[:url]}"
    end
  end

  test "commander names are extracted correctly" do
    stub_edhrec_json_api

    result = EdhrecScraper.fetch_top_commanders

    # Verify at least the first commander has a non-empty name
    assert_not_nil result.first[:name]
    assert result.first[:name].length > 0
  end

  # ---------------------------------------------------------------------------
  # Error Handling Tests
  # ---------------------------------------------------------------------------

  test "raises FetchError when network request fails" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_timeout

    error = assert_raises(EdhrecScraper::FetchError) do
      EdhrecScraper.fetch_top_commanders
    end

    assert_match(/network error/i, error.message)
  end

  test "raises FetchError when receiving 404 status" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 404, body: "Not Found")

    error = assert_raises(EdhrecScraper::FetchError) do
      EdhrecScraper.fetch_top_commanders
    end

    assert_match(/404/i, error.message)
  end

  test "raises FetchError when receiving 500 status" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 500, body: "Internal Server Error")

    error = assert_raises(EdhrecScraper::FetchError) do
      EdhrecScraper.fetch_top_commanders
    end

    assert_match(/500/i, error.message)
  end

  test "raises ParseError when JSON structure is invalid" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 200, body: '{"invalid": "structure"}')

    error = assert_raises(EdhrecScraper::ParseError) do
      EdhrecScraper.fetch_top_commanders
    end

    assert_match(/could not find commander data|api structure/i, error.message)
  end

  test "raises ParseError when JSON is malformed" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 200, body: "invalid json")

    error = assert_raises(EdhrecScraper::ParseError) do
      EdhrecScraper.fetch_top_commanders
    end

    assert_match(/failed to parse json/i, error.message)
  end

  test "logs warning and returns partial results when fewer than 20 commanders found" do
    # Stub with only 15 commanders
    json = build_commanders_json(15)
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 200, body: json.to_json)

    # Capture log output
    logs = capture_log_output do
      result = EdhrecScraper.fetch_top_commanders
      assert_equal 15, result.length
    end

    # Check for warning about fewer commanders (case insensitive)
    assert_match(/warn.*found only 15 commanders/i, logs)
  end

  test "includes polite User-Agent header in HTTP request" do
    stub = stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .with(headers: { "User-Agent" => "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)" })
      .to_return(status: 200, body: build_commanders_json(20).to_json)

    EdhrecScraper.fetch_top_commanders

    assert_requested stub
  end

  private

  # Build a minimal valid EDHREC JSON response
  # This mimics the actual structure of the EDHREC JSON API
  def build_commanders_json(count)
    cardviews = (1..count).map do |rank|
      commander_name = "Commander #{rank}"
      commander_slug = commander_name.downcase.gsub(" ", "-")
      {
        "id" => SecureRandom.uuid,
        "name" => commander_name,
        "sanitized" => commander_slug,
        "url" => "/commanders/#{commander_slug}",
        "inclusion" => 1000 - (rank * 10),
        "num_decks" => 1000 - (rank * 10),
        "rank" => rank
      }
    end

    {
      "container" => {
        "json_dict" => {
          "cardlists" => [
            {
              "cardviews" => cardviews
            }
          ]
        }
      }
    }
  end

  # Stub the EDHREC JSON API with 20 valid commanders
  def stub_edhrec_json_api
    json = build_commanders_json(20)
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 200, body: json.to_json)
  end

  # Helper to capture Rails logger output
  def capture_log_output
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    yield

    log_output.string
  ensure
    Rails.logger = original_logger
  end

  # ---------------------------------------------------------------------------
  # Commander Decklist Tests
  # ---------------------------------------------------------------------------

  test "fetch_commander_decklist returns array of exactly 100 cards" do
    stub_commander_decklist_json("https://edhrec.com/commanders/atraxa-praetors-voice")

    result = EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/atraxa-praetors-voice")

    assert_kind_of Array, result
    assert_equal 100, result.length
  end

  test "fetch_commander_decklist identifies which card is the commander" do
    stub_commander_decklist_json("https://edhrec.com/commanders/atraxa-praetors-voice")

    result = EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/atraxa-praetors-voice")

    commanders = result.select { |card| card[:is_commander] }
    assert_equal 1, commanders.length
    assert_equal "Atraxa, Praetors' Voice", commanders.first[:name]
  end

  test "fetch_commander_decklist supports partner commanders" do
    stub_partner_commander_decklist_json("https://edhrec.com/commanders/thrasios-triton-hero-and-tymna-the-weaver")

    result = EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/thrasios-triton-hero-and-tymna-the-weaver")

    commanders = result.select { |card| card[:is_commander] }
    assert_equal 2, commanders.length
    assert_includes commanders.map { |c| c[:name] }, "Thrasios, Triton Hero"
    assert_includes commanders.map { |c| c[:name] }, "Tymna the Weaver"
    assert_equal 100, result.length
  end

  test "fetch_commander_decklist extracts card names and categories" do
    stub_commander_decklist_json("https://edhrec.com/commanders/atraxa-praetors-voice")

    result = EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/atraxa-praetors-voice")

    # Check that cards have required fields
    result.each do |card|
      assert_includes card.keys, :name
      assert_includes card.keys, :category
      assert_includes card.keys, :is_commander
      assert_not_nil card[:name]
      assert_not_nil card[:category]
    end
  end

  test "fetch_commander_decklist resolves cards with Scryfall IDs" do
    stub_commander_decklist_json("https://edhrec.com/commanders/atraxa-praetors-voice")

    # Stub all Scryfall API calls to return valid IDs
    stub_request(:get, %r{https://api\.scryfall\.com/cards/named})
      .to_return do |request|
        card_name = CGI.parse(URI(request.uri).query)["fuzzy"].first
        {
          status: 200,
          body: { id: "#{card_name.downcase.gsub(/[^a-z]/, '-')}-id", name: card_name }.to_json,
          headers: { "Content-Type" => "application/json" }
        }
      end

    result = EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/atraxa-praetors-voice")

    # Check that cards have scryfall_id
    result.each do |card|
      assert_includes card.keys, :scryfall_id
      assert_not_nil card[:scryfall_id]
    end
  end

  test "fetch_commander_decklist keeps cards with nil scryfall_id when fuzzy search fails" do
    stub_commander_decklist_json("https://edhrec.com/commanders/atraxa-praetors-voice")

    # Stub Scryfall API to return 404 for most cards, but succeed for Sol Ring
    stub_request(:get, %r{https://api\.scryfall\.com/cards/named})
      .to_return do |request|
        card_name = CGI.parse(URI(request.uri).query)["fuzzy"].first
        if card_name == "Sol Ring"
          {
            status: 200,
            body: { id: "sol-ring-id", name: card_name }.to_json,
            headers: { "Content-Type" => "application/json" }
          }
        else
          {
            status: 404,
            body: { object: "error", code: "not_found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          }
        end
      end

    result = EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/atraxa-praetors-voice")

    # All 100 cards should still be in the list
    assert_equal 100, result.length

    # Cards with failed resolution should have nil scryfall_id
    failed_cards = result.select { |c| c[:scryfall_id].nil? }
    assert failed_cards.length > 0, "Expected some cards to have nil scryfall_id"

    # Sol Ring should have its ID
    sol_ring = result.find { |c| c[:name] == "Sol Ring" }
    assert_equal "sol-ring-id", sol_ring[:scryfall_id] if sol_ring
  end

  test "fetch_commander_decklist raises FetchError on network failure" do
    stub_request(:get, %r{https://json\.edhrec\.com/pages/commanders/.*})
      .to_timeout

    error = assert_raises(EdhrecScraper::FetchError) do
      EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/atraxa-praetors-voice")
    end

    assert_match(/network error/i, error.message)
  end

  test "fetch_commander_decklist raises ParseError when JSON structure is invalid" do
    stub_request(:get, %r{https://json\.edhrec\.com/pages/commanders/.*})
      .to_return(status: 200, body: '{"invalid": "structure"}')

    error = assert_raises(EdhrecScraper::ParseError) do
      EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/atraxa-praetors-voice")
    end

    assert_match(/could not find|parse/i, error.message)
  end

  def stub_commander_decklist_json(commander_url)
    # Extract commander slug from URL
    slug = commander_url.split("/").last

    # Build a decklist with exactly 100 cards
    cardlists = []

    # Commander card
    cardlists << {
      "tag" => "Commanders",
      "cardviews" => [
        {
          "name" => "Atraxa, Praetors' Voice",
          "sanitized" => "atraxa-praetors-voice",
          "inclusion" => 100
        }
      ]
    }

    # Add 99 other cards in various categories
    categories = [
      { "tag" => "Creatures", "count" => 30 },
      { "tag" => "Instants", "count" => 10 },
      { "tag" => "Sorceries", "count" => 10 },
      { "tag" => "Artifacts", "count" => 15 },
      { "tag" => "Enchantments", "count" => 10 },
      { "tag" => "Planeswalkers", "count" => 5 },
      { "tag" => "Lands", "count" => 19 }
    ]

    categories.each do |category|
      cardviews = (1..category["count"]).map do |i|
        {
          "name" => "#{category["tag"][0...-1]} #{i}",
          "sanitized" => "#{category["tag"].downcase}-#{i}",
          "inclusion" => 90 - i
        }
      end
      cardlists << {
        "tag" => category["tag"],
        "cardviews" => cardviews
      }
    end

    # Add Sol Ring to artifacts for test purposes
    artifacts_list = cardlists.find { |cl| cl["tag"] == "Artifacts" }
    artifacts_list["cardviews"][0]["name"] = "Sol Ring" if artifacts_list && artifacts_list["cardviews"]&.any?

    json = {
      "container" => {
        "json_dict" => {
          "cardlists" => cardlists
        }
      }
    }

    stub_request(:get, "https://json.edhrec.com/pages/commanders/#{slug}")
      .to_return(status: 200, body: json.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_partner_commander_decklist_json(commander_url)
    slug = commander_url.split("/").last

    cardlists = []

    # Two commander cards (partners)
    cardlists << {
      "tag" => "Commanders",
      "cardviews" => [
        {
          "name" => "Thrasios, Triton Hero",
          "sanitized" => "thrasios-triton-hero",
          "inclusion" => 100
        },
        {
          "name" => "Tymna the Weaver",
          "sanitized" => "tymna-the-weaver",
          "inclusion" => 100
        }
      ]
    }

    # Add 98 other cards to make exactly 100
    categories = [
      { "tag" => "Creatures", "count" => 30 },
      { "tag" => "Instants", "count" => 10 },
      { "tag" => "Sorceries", "count" => 10 },
      { "tag" => "Artifacts", "count" => 15 },
      { "tag" => "Enchantments", "count" => 10 },
      { "tag" => "Planeswalkers", "count" => 5 },
      { "tag" => "Lands", "count" => 18 }
    ]

    categories.each do |category|
      cardviews = (1..category["count"]).map do |i|
        {
          "name" => "#{category["tag"][0...-1]} #{i}",
          "sanitized" => "#{category["tag"].downcase}-#{i}",
          "inclusion" => 90 - i
        }
      end
      cardlists << {
        "tag" => category["tag"],
        "cardviews" => cardviews
      }
    end

    json = {
      "container" => {
        "json_dict" => {
          "cardlists" => cardlists
        }
      }
    }

    stub_request(:get, "https://json.edhrec.com/pages/commanders/#{slug}")
      .to_return(status: 200, body: json.to_json, headers: { "Content-Type" => "application/json" })
  end
end
