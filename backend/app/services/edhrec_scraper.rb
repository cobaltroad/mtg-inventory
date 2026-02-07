require "net/http"
require "uri"
require "json"
require "nokogiri"

class EdhrecScraper
  BASE_URL = "https://edhrec.com"
  JSON_API_URL = "https://json.edhrec.com/pages/commanders/week.json"
  USER_AGENT = "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)"
  REQUEST_TIMEOUT = 10 # seconds
  EXPECTED_COMMANDER_COUNT = 20

  # Rate limiting configuration
  REQUEST_DELAY = 2.0 # seconds between requests to avoid 429 errors
  MAX_RETRIES = 3
  RETRY_BACKOFF_BASE = 5 # seconds (exponential backoff: 5s, 10s, 20s)

  # Custom exception classes for error handling
  class FetchError < StandardError; end
  class ParseError < StandardError; end
  class RateLimitError < StandardError; end

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
    average_deck_url = build_average_deck_url(commander_url)
    html_content = fetch_html(average_deck_url)
    json_data = extract_json_from_html(html_content)
    cards = parse_decklist_from_json(json_data)
    enrich_cards_with_scryfall_ids(cards)

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
  # Builds average deck URL from commander page URL
  # ---------------------------------------------------------------------------
  private_class_method def self.build_average_deck_url(commander_url)
    slug = commander_url.split("/").last
    "https://edhrec.com/average-decks/#{slug}"
  end

  # ---------------------------------------------------------------------------
  # Fetches HTML content from the given URL with rate limiting and retry logic
  #
  # Arguments:
  #   url (String) - The URL to fetch
  #   retry_count (Integer) - Current retry attempt (used internally)
  #
  # Returns:
  #   String - HTML content
  #
  # Raises:
  #   FetchError: If the HTTP request fails
  #   RateLimitError: If rate limit is exceeded after retries
  # ---------------------------------------------------------------------------
  private_class_method def self.fetch_html(url, retry_count = 0)
    # Apply rate limiting delay before making request
    sleep(REQUEST_DELAY) if retry_count == 0

    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: REQUEST_TIMEOUT) do |http|
      http.request(request)
    end

    # Handle 429 Too Many Requests with exponential backoff
    if response.code == "429"
      if retry_count < MAX_RETRIES
        wait_time = RETRY_BACKOFF_BASE * (2 ** retry_count)
        Rails.logger.warn("EdhrecScraper: Rate limit hit (429) for #{url}, retrying in #{wait_time}s (attempt #{retry_count + 1}/#{MAX_RETRIES})")
        sleep(wait_time)
        return fetch_html(url, retry_count + 1)
      else
        Rails.logger.error("EdhrecScraper: Rate limit exceeded after #{MAX_RETRIES} retries for #{url}")
        raise RateLimitError, "EDHREC rate limit exceeded. Please try again later."
      end
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("EdhrecScraper: HTTP error #{response.code} for #{url}")
      raise FetchError, "HTTP error #{response.code}: #{response.message}"
    end

    response.body
  end

  # ---------------------------------------------------------------------------
  # Extracts embedded JSON data from EDHREC HTML page
  #
  # Arguments:
  #   html (String) - HTML content from EDHREC average deck page
  #
  # Returns:
  #   Hash - Parsed JSON data with cardlists
  #
  # Raises:
  #   ParseError: If JSON cannot be extracted or parsed
  # ---------------------------------------------------------------------------
  private_class_method def self.extract_json_from_html(html)
    doc = Nokogiri::HTML(html)

    # Find Next.js data script tag (id="__NEXT_DATA__")
    script_tag = doc.at_css('script#__NEXT_DATA__')

    unless script_tag
      Rails.logger.error("EdhrecScraper: Could not find __NEXT_DATA__ script tag in HTML")
      raise ParseError, "Could not find embedded deck data in page"
    end

    # Parse the JSON content
    next_data = JSON.parse(script_tag.content)

    # Extract the data container from Next.js page props
    # Structure: props.pageProps.data.container (matches old JSON API structure)
    data_container = next_data.dig("props", "pageProps", "data", "container")

    unless data_container
      Rails.logger.error("EdhrecScraper: Could not find container in Next.js data")
      raise ParseError, "Could not find deck data container in page"
    end

    # Extract cardlists and commander card
    json_dict = data_container["json_dict"] || {}
    cardlists = json_dict["cardlists"]
    commander_card = json_dict["card"]

    unless cardlists
      Rails.logger.error("EdhrecScraper: Could not find cardlists in data container")
      raise ParseError, "Could not find cardlists in page data"
    end

    # Add commander as a separate cardlist (to match old API structure)
    # The commander is stored separately in the 'card' field
    if commander_card
      commander_cardlist = {
        "tag" => "Commanders",
        "cardviews" => [commander_card]
      }
      cardlists = [commander_cardlist] + cardlists
    end

    # Return in the same format expected by parse_decklist_from_json
    {
      "container" => {
        "json_dict" => {
          "cardlists" => cardlists
        }
      }
    }
  rescue Nokogiri::SyntaxError => e
    Rails.logger.error("EdhrecScraper: HTML parsing error - #{e.message}")
    raise ParseError, "Failed to parse HTML: #{e.message}"
  end

  # ---------------------------------------------------------------------------
  # Enriches card data with Scryfall IDs
  # ---------------------------------------------------------------------------
  private_class_method def self.enrich_cards_with_scryfall_ids(cards)
    card_names = cards.map { |c| c[:name] }
    scryfall_ids = ScryfallCardResolver.resolve_cards(card_names)

    cards.each do |card|
      card[:scryfall_id] = scryfall_ids[card[:name]]
    end
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

    cards = cardlists.flat_map { |cardlist| build_cards_from_cardlist(cardlist) }

    validate_decklist_size(cards)
    cards
  end

  # ---------------------------------------------------------------------------
  # Builds card hashes from a single cardlist category
  # ---------------------------------------------------------------------------
  private_class_method def self.build_cards_from_cardlist(cardlist)
    category = cardlist["tag"] || "Unknown"
    is_commander_category = (category.downcase == "commanders")
    cardviews = cardlist["cardviews"] || []

    cardviews.map do |cardview|
      {
        name: cardview["name"],
        category: category,
        is_commander: is_commander_category
      }
    end
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
  # Validates that the decklist contains a reasonable number of cards
  # Note: EDHREC average decks typically have 75-100 cards (not always exactly 100)
  # ---------------------------------------------------------------------------
  private_class_method def self.validate_decklist_size(cards)
    card_count = cards.length

    # Average decks from EDHREC typically have 75-100 cards
    if card_count < 75
      raise ParseError, "Decklist incomplete - only #{card_count} cards found (expected at least 75)"
    elsif card_count > 100
      raise ParseError, "Decklist has too many cards - #{card_count} found (expected at most 100)"
    end

    # Log info if not exactly 100 cards (common for average decks)
    if card_count != 100
      Rails.logger.info(
        "EdhrecScraper: Average deck contains #{card_count} cards (EDHREC average decks typically have 75-100 cards)"
      )
    end
  end
end
