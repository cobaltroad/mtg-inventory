require "test_helper"
require "webmock/minitest"

class EdHrecScraperTest < ActiveSupport::TestCase
  setup do
    WebMock.reset!
  end

  # ---------------------------------------------------------------------------
  # Basic Functionality Tests
  # ---------------------------------------------------------------------------

  test "fetch_top_commanders returns array of 20 commander hashes" do
    stub_edhrec_json_api

    result = EdHrecScraper.fetch_top_commanders

    assert_kind_of Array, result
    assert_equal 20, result.length
  end

  test "each commander hash has required keys name, rank, and url" do
    stub_edhrec_json_api

    result = EdHrecScraper.fetch_top_commanders

    result.each do |commander|
      assert_kind_of Hash, commander
      assert_includes commander.keys, :name
      assert_includes commander.keys, :rank
      assert_includes commander.keys, :url
    end
  end

  test "commander ranks are sequential from 1 to 20" do
    stub_edhrec_json_api

    result = EdHrecScraper.fetch_top_commanders

    ranks = result.map { |c| c[:rank] }
    assert_equal (1..20).to_a, ranks
  end

  test "commander URLs are properly formatted with full domain" do
    stub_edhrec_json_api

    result = EdHrecScraper.fetch_top_commanders

    result.each do |commander|
      assert_match %r{\Ahttps://edhrec\.com/commanders/}, commander[:url],
        "Expected URL to start with https://edhrec.com/commanders/, got: #{commander[:url]}"
    end
  end

  test "commander names are extracted correctly" do
    stub_edhrec_json_api

    result = EdHrecScraper.fetch_top_commanders

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

    error = assert_raises(EdHrecScraper::FetchError) do
      EdHrecScraper.fetch_top_commanders
    end

    assert_match(/network error/i, error.message)
  end

  test "raises FetchError when receiving 404 status" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 404, body: "Not Found")

    error = assert_raises(EdHrecScraper::FetchError) do
      EdHrecScraper.fetch_top_commanders
    end

    assert_match(/404/i, error.message)
  end

  test "raises FetchError when receiving 500 status" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 500, body: "Internal Server Error")

    error = assert_raises(EdHrecScraper::FetchError) do
      EdHrecScraper.fetch_top_commanders
    end

    assert_match(/500/i, error.message)
  end

  test "raises ParseError when JSON structure is invalid" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 200, body: '{"invalid": "structure"}')

    error = assert_raises(EdHrecScraper::ParseError) do
      EdHrecScraper.fetch_top_commanders
    end

    assert_match(/could not find commander data|api structure/i, error.message)
  end

  test "raises ParseError when JSON is malformed" do
    stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .to_return(status: 200, body: "invalid json")

    error = assert_raises(EdHrecScraper::ParseError) do
      EdHrecScraper.fetch_top_commanders
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
      result = EdHrecScraper.fetch_top_commanders
      assert_equal 15, result.length
    end

    # Check for warning about fewer commanders (case insensitive)
    assert_match(/warn.*found only 15 commanders/i, logs)
  end

  test "includes polite User-Agent header in HTTP request" do
    stub = stub_request(:get, "https://json.edhrec.com/pages/commanders/week.json")
      .with(headers: { "User-Agent" => "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)" })
      .to_return(status: 200, body: build_commanders_json(20).to_json)

    EdHrecScraper.fetch_top_commanders

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
end
