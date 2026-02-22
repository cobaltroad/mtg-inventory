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
  # Commander Decklist Tests
  # ---------------------------------------------------------------------------

  test "fetch_commander_decklist returns array of 50-100 cards" do
    stub_commander_decklist_json("https://edhrec.com/commanders/atraxa-praetors-voice")

    result = EdhrecScraper.fetch_commander_decklist("https://edhrec.com/commanders/atraxa-praetors-voice")

    assert_kind_of Array, result
    assert_operator result.length, :>=, 50, "Expected at least 50 cards"
    assert_operator result.length, :<=, 100, "Expected at most 100 cards"
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

    # Stub all Scryfall API calls to return valid IDs and URIs
    stub_request(:get, %r{https://api\.scryfall\.com/cards/named})
      .to_return do |request|
        card_name = CGI.parse(URI(request.uri).query)["fuzzy"].first
        card_slug = card_name.downcase.gsub(/[^a-z0-9]+/, '-')
        {
          status: 200,
          body: {
            id: "#{card_slug}-id",
            name: card_name,
            scryfall_uri: "https://scryfall.com/card/set/1/#{card_slug}"
          }.to_json,
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

    # Build Next.js page props structure (matches EDHREC's __NEXT_DATA__)
    next_data = {
      "props" => {
        "__N_SSP" => true,
        "pageProps" => {
          "data" => {
            "container" => {
              "json_dict" => {
                "cardlists" => cardlists
              }
            }
          }
        }
      }
    }

    # Wrap JSON in HTML with Next.js data script tag (as EDHREC does)
    html = <<~HTML
      <html>
      <head><title>EDHREC Average Deck</title></head>
      <body>
        <script id="__NEXT_DATA__" type="application/json">#{next_data.to_json}</script>
      </body>
      </html>
    HTML

    stub_request(:get, "https://edhrec.com/average-decks/#{slug}")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })
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

    # Build Next.js page props structure
    next_data = {
      "props" => {
        "__N_SSP" => true,
        "pageProps" => {
          "data" => {
            "container" => {
              "json_dict" => {
                "cardlists" => cardlists
              }
            }
          }
        }
      }
    }

    # Wrap JSON in HTML with Next.js data script tag
    html = <<~HTML
      <html>
      <head><title>EDHREC Average Deck</title></head>
      <body>
        <script id="__NEXT_DATA__" type="application/json">#{next_data.to_json}</script>
      </body>
      </html>
    HTML

    stub_request(:get, "https://edhrec.com/average-decks/#{slug}")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })
  end
end
