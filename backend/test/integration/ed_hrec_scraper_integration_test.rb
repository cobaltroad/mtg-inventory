require "test_helper"
require "vcr"

class EdHrecScraperIntegrationTest < ActiveSupport::TestCase
  # Disable parallelization to avoid VCR conflicts
  parallelize(workers: 1)

  # ---------------------------------------------------------------------------
  # Integration test with real EDHREC page using VCR
  # ---------------------------------------------------------------------------
  test "successfully fetches and parses real EDHREC page" do
    VCR.use_cassette("edhrec_commanders_week") do
      result = EdHrecScraper.fetch_top_commanders

      # Basic validation - at least some commanders should be found
      assert_kind_of Array, result
      assert_operator result.length, :>, 0, "Expected at least some commanders to be found"

      # Validate structure of first commander
      first_commander = result.first
      assert_kind_of Hash, first_commander
      assert_includes first_commander.keys, :name
      assert_includes first_commander.keys, :rank
      assert_includes first_commander.keys, :url

      # Validate data types
      assert_kind_of String, first_commander[:name]
      assert_kind_of Integer, first_commander[:rank]
      assert_kind_of String, first_commander[:url]

      # Validate rank starts at 1
      assert_equal 1, first_commander[:rank]

      # Validate URL format
      assert_match %r{\Ahttps://edhrec\.com}, first_commander[:url]

      # Validate name is not empty
      assert first_commander[:name].length > 0

      # Log results for debugging
      Rails.logger.info("EdHrecScraper integration test found #{result.length} commanders")
      Rails.logger.info("First commander: #{first_commander[:name]} (#{first_commander[:url]})")
    end
  end

  # ---------------------------------------------------------------------------
  # Test that VCR cassette can be replayed without real network calls
  # ---------------------------------------------------------------------------
  test "replays VCR cassette without network calls" do
    # First request records the cassette
    VCR.use_cassette("edhrec_commanders_week_replay") do
      result1 = EdHrecScraper.fetch_top_commanders
      assert_operator result1.length, :>, 0
    end

    # Second request should replay from cassette
    VCR.use_cassette("edhrec_commanders_week_replay") do
      result2 = EdHrecScraper.fetch_top_commanders
      assert_operator result2.length, :>, 0
    end
  end
end
