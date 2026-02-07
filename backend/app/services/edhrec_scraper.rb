require "net/http"
require "uri"
require "json"

class EdhrecScraper
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
    Rails.logger.error("EdhrecScraper: Network error - #{e.class}: #{e.message}")
    raise FetchError, "Network error while fetching commanders: #{e.message}"
  rescue JSON::ParserError => e
    Rails.logger.error("EdhrecScraper: JSON parsing error - #{e.message}")
    raise ParseError, "Failed to parse JSON response: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("EdhrecScraper: Unexpected error - #{e.class}: #{e.message}")
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
      Rails.logger.error("EdhrecScraper: HTTP error #{response.code} for #{url}")
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

    Rails.logger.error("EdhrecScraper: No cardviews found in JSON")
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
      "EdhrecScraper: Found only #{count} commanders (expected #{EXPECTED_COMMANDER_COUNT})"
    )
  end

  # ---------------------------------------------------------------------------
  # Validates that at least some commanders were successfully parsed
  # ---------------------------------------------------------------------------
  private_class_method def self.validate_parsed_commanders(commanders)
    return unless commanders.empty?

    raise ParseError, "No commanders could be parsed from JSON"
  end

  # ---------------------------------------------------------------------------
  # Fetches and parses a commander's average decklist from EDHREC
  #
  # Arguments:
  #   commander_url (String) - The EDHREC URL for the commander
  #
  # Returns:
  #   Array of hashes, each containing:
  #   - :name (String) - Card name
  #   - :category (String) - Card category (e.g., "Creatures", "Lands")
  #   - :is_commander (Boolean) - Whether this card is a commander
  #   - :scryfall_id (String or nil) - Scryfall ID if resolved, nil otherwise
  #
  # Raises:
  #   - FetchError: Network errors or HTTP failures
  #   - ParseError: JSON structure doesn't match expected format
  # ---------------------------------------------------------------------------
  def self.fetch_commander_decklist(commander_url)
    # Extract slug from URL and construct JSON API URL
    slug = commander_url.split("/").last
    json_url = "https://json.edhrec.com/pages/commanders/#{slug}"

    json_data = fetch_json(json_url)
    cards = parse_decklist_from_json(json_data)

    # Resolve all card names to Scryfall IDs
    card_names = cards.map { |c| c[:name] }
    scryfall_ids = ScryfallCardResolver.resolve_cards(card_names)

    # Merge Scryfall IDs back into cards
    cards.each do |card|
      card[:scryfall_id] = scryfall_ids[card[:name]]
    end

    cards
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    Rails.logger.error("EdhrecScraper: Network error - #{e.class}: #{e.message}")
    raise FetchError, "Network error while fetching decklist: #{e.message}"
  rescue JSON::ParserError => e
    Rails.logger.error("EdhrecScraper: JSON parsing error - #{e.message}")
    raise ParseError, "Failed to parse JSON response: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("EdhrecScraper: Unexpected error - #{e.class}: #{e.message}")
    raise
  end

  # ---------------------------------------------------------------------------
  # Parses decklist JSON data to extract all cards
  #
  # Arguments:
  #   data (Hash) - Parsed JSON data from EDHREC commander page
  #
  # Returns:
  #   Array of card hashes with :name, :category, and :is_commander
  # ---------------------------------------------------------------------------
  private_class_method def self.parse_decklist_from_json(data)
    cardlists = extract_cardlists_from_json(data)
    validate_cardlists(cardlists)

    cards = []

    cardlists.each do |cardlist|
      category = cardlist["tag"] || "Unknown"
      is_commander_category = category.downcase == "commanders"

      cardviews = cardlist["cardviews"] || []
      cardviews.each do |cardview|
        cards << {
          name: cardview["name"],
          category: category,
          is_commander: is_commander_category
        }
      end
    end

    validate_decklist_size(cards)
    cards
  end

  # ---------------------------------------------------------------------------
  # Extracts cardlists array from nested JSON structure
  # ---------------------------------------------------------------------------
  private_class_method def self.extract_cardlists_from_json(data)
    container = data["container"] || {}
    json_dict = container["json_dict"] || {}
    json_dict["cardlists"] || []
  end

  # ---------------------------------------------------------------------------
  # Validates that cardlists were found in the JSON
  # ---------------------------------------------------------------------------
  private_class_method def self.validate_cardlists(cardlists)
    return unless cardlists.empty?

    Rails.logger.error("EdhrecScraper: No cardlists found in JSON")
    raise ParseError, "Could not find decklist data in JSON - API structure may have changed"
  end

  # ---------------------------------------------------------------------------
  # Validates that the decklist contains exactly 100 cards
  # ---------------------------------------------------------------------------
  private_class_method def self.validate_decklist_size(cards)
    return if cards.length == 100

    Rails.logger.warn(
      "EdhrecScraper: Decklist contains #{cards.length} cards (expected 100)"
    )

    if cards.length < 100
      raise ParseError, "Decklist incomplete - only #{cards.length} cards found (expected 100)"
    elsif cards.length > 100
      raise ParseError, "Decklist has too many cards - #{cards.length} found (expected 100)"
    end
  end
end
