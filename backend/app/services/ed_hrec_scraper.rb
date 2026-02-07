require "net/http"
require "uri"
require "json"

class EdHrecScraper
  BASE_URL = "https://edhrec.com"
  JSON_API_URL = "https://json.edhrec.com/pages/commanders/week.json"
  USER_AGENT = "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)"
  REQUEST_TIMEOUT = 10 # seconds
  EXPECTED_COMMANDER_COUNT = 20

  # Custom exception classes for error handling
  class FetchError < StandardError; end
  class ParseError < StandardError; end

  # ---------------------------------------------------------------------------
  # Fetches and parses the EDHREC weekly top commanders via JSON API
  #
  # Returns:
  #   Array of hashes, each containing:
  #   - :name (String) - Commander name
  #   - :rank (Integer) - Rank from 1 to 20
  #   - :url (String) - Full EDHREC URL for the commander
  #
  # Raises:
  #   - FetchError: Network errors or HTTP failures
  #   - ParseError: JSON structure doesn't match expected format
  # ---------------------------------------------------------------------------
  def self.fetch_top_commanders
    json_data = fetch_json(JSON_API_URL)
    parse_commanders_from_json(json_data)
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    Rails.logger.error("EdHrecScraper: Network error - #{e.class}: #{e.message}")
    raise FetchError, "Network error while fetching commanders: #{e.message}"
  rescue JSON::ParserError => e
    Rails.logger.error("EdHrecScraper: JSON parsing error - #{e.message}")
    raise ParseError, "Failed to parse JSON response: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("EdHrecScraper: Unexpected error - #{e.class}: #{e.message}")
    raise
  end

  # ---------------------------------------------------------------------------
  # Fetches JSON content from the given URL
  #
  # Arguments:
  #   url (String) - The URL to fetch
  #
  # Returns:
  #   Hash - Parsed JSON data
  #
  # Raises:
  #   FetchError: If the HTTP request fails
  # ---------------------------------------------------------------------------
  private_class_method def self.fetch_json(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: REQUEST_TIMEOUT) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("EdHrecScraper: HTTP error #{response.code} for #{url}")
      raise FetchError, "HTTP error #{response.code}: #{response.message}"
    end

    JSON.parse(response.body)
  end

  # ---------------------------------------------------------------------------
  # Parses JSON data to extract commander information
  #
  # Arguments:
  #   data (Hash) - Parsed JSON data from EDHREC API
  #
  # Returns:
  #   Array of commander hashes with :name, :rank, and :url
  #
  # Raises:
  #   ParseError: If JSON structure is invalid or commanders cannot be extracted
  # ---------------------------------------------------------------------------
  private_class_method def self.parse_commanders_from_json(data)
    cardviews = extract_cardviews_from_json(data)
    validate_cardviews(cardviews)

    commanders = build_commanders_from_cardviews(cardviews)
    log_commander_count_warning(commanders.length)
    validate_parsed_commanders(commanders)

    commanders
  end

  # ---------------------------------------------------------------------------
  # Extracts cardviews array from nested JSON structure
  # ---------------------------------------------------------------------------
  private_class_method def self.extract_cardviews_from_json(data)
    container = data["container"] || {}
    json_dict = container["json_dict"] || {}
    cardlists = json_dict["cardlists"] || []

    return [] if cardlists.empty?

    cardlists.first["cardviews"] || []
  end

  # ---------------------------------------------------------------------------
  # Validates that cardviews were found in the JSON
  # ---------------------------------------------------------------------------
  private_class_method def self.validate_cardviews(cardviews)
    return unless cardviews.empty?

    Rails.logger.error("EdHrecScraper: No cardviews found in JSON")
    raise ParseError, "Could not find commander data in JSON - API structure may have changed"
  end

  # ---------------------------------------------------------------------------
  # Builds commander data from cardviews
  # ---------------------------------------------------------------------------
  private_class_method def self.build_commanders_from_cardviews(cardviews)
    cardviews.first(EXPECTED_COMMANDER_COUNT).map do |cardview|
      {
        name: cardview["name"],
        rank: cardview["rank"],
        url: "#{BASE_URL}#{cardview["url"]}"
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Logs warning if fewer commanders than expected were found
  # ---------------------------------------------------------------------------
  private_class_method def self.log_commander_count_warning(count)
    return unless count < EXPECTED_COMMANDER_COUNT

    Rails.logger.warn(
      "EdHrecScraper: Found only #{count} commanders (expected #{EXPECTED_COMMANDER_COUNT})"
    )
  end

  # ---------------------------------------------------------------------------
  # Validates that at least some commanders were successfully parsed
  # ---------------------------------------------------------------------------
  private_class_method def self.validate_parsed_commanders(commanders)
    return unless commanders.empty?

    raise ParseError, "No commanders could be parsed from JSON"
  end
end
