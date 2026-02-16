require "net/http"
require "json"
require "nokogiri"

class CardListFetcher
  # Custom error classes
  class FetchError < StandardError; end
  class ParseError < StandardError; end

  # API endpoints
  # Note: Fragment (#gamechangers) is client-side only, not sent to server
  WIZARDS_GAME_CHANGERS_URL = "https://magic.wizards.com/en/formats/commander"
  SCRYFALL_RESERVED_LIST_URL = "https://api.scryfall.com/cards/search?q=is:reserved"

  # User-Agent for polite crawling (used for Scryfall API)
  USER_AGENT = "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)"

  # Browser headers for sites that block automated requests (e.g., Moxfield)
  # These mimic a legitimate browser to avoid 403 errors
  BROWSER_HEADERS = {
    "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language" => "en-US,en;q=0.5",
    "Accept-Encoding" => "gzip, deflate, br",
    "DNT" => "1",
    "Connection" => "keep-alive",
    "Upgrade-Insecure-Requests" => "1"
  }.freeze

  # HTTP timeout in seconds
  HTTP_TIMEOUT = 10

  class << self
    # ---------------------------------------------------------------------------
    # Fetch Game Changers list from official Wizards source
    #
    # Returns: Array of card names (String), normalized and sorted alphabetically
    # Raises: FetchError on network errors, ParseError on parsing failures
    # ---------------------------------------------------------------------------
    def fetch_game_changers
      html = fetch_url(WIZARDS_GAME_CHANGERS_URL, headers: BROWSER_HEADERS)
      card_names = parse_wizards_html(html)

      if card_names.empty?
        raise ParseError, "No card names found in Wizards HTML structure. " \
                         "The page likely uses JavaScript rendering (client-side only). " \
                         "Consider maintaining config/card_lists/game_changers.yml manually."
      end

      normalize_and_sort(card_names)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise FetchError, "Network error while fetching Game Changers: timeout - #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      raise FetchError, "Network error while fetching Game Changers: connection failed - #{e.message}"
    rescue JSON::ParserError => e
      raise ParseError, "Failed to parse JSON from Moxfield: #{e.message}"
    end

    # ---------------------------------------------------------------------------
    # Fetch Reserved List from Scryfall API
    #
    # Returns: Array of card names (String), normalized and sorted alphabetically
    # Raises: FetchError on network errors, ParseError on parsing failures
    # ---------------------------------------------------------------------------
    def fetch_reserved_list
      rate_limiter = RateLimiter.for_scryfall
      card_names = []
      next_page_url = SCRYFALL_RESERVED_LIST_URL

      # Scryfall paginates results, so we need to fetch all pages
      while next_page_url
        rate_limiter.throttle

        json_response = fetch_url(next_page_url)
        parsed = parse_scryfall_json(json_response)

        card_names.concat(parsed[:cards])
        next_page_url = parsed[:next_page]
      end

      if card_names.empty?
        raise ParseError, "No card names found in Scryfall API response"
      end

      normalize_and_sort(card_names)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise FetchError, "Network error while fetching Reserved List: timeout - #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      raise FetchError, "Network error while fetching Reserved List: connection failed - #{e.message}"
    rescue JSON::ParserError => e
      raise ParseError, "Failed to parse JSON from Scryfall API: #{e.message}"
    end

    private

    # ---------------------------------------------------------------------------
    # Fetch content from a URL with proper error handling
    #
    # Arguments:
    #   url (String) - The URL to fetch
    #   headers (Hash) - Optional custom headers (defaults to simple User-Agent)
    #
    # Returns: String - The response body
    # Raises: FetchError on HTTP errors
    # ---------------------------------------------------------------------------
    def fetch_url(url, headers: nil)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)

      # Apply headers
      if headers
        headers.each do |key, value|
          request[key] = value
        end
      else
        request["User-Agent"] = USER_AGENT
      end

      response = Net::HTTP.start(uri.hostname, uri.port,
                                  use_ssl: uri.scheme == "https",
                                  open_timeout: HTTP_TIMEOUT,
                                  read_timeout: HTTP_TIMEOUT) do |http|
        http.request(request)
      end

      case response.code.to_i
      when 200
        response.body
      when 403
        raise FetchError, "Access forbidden (403): #{url}. " \
                         "Consider maintaining config/card_lists/game_changers.yml manually. " \
                         "See https://magic.wizards.com/en/formats/commander for official list."
      when 404
        raise FetchError, "Resource not found (404): #{url}"
      when 500..599
        raise FetchError, "Server error (#{response.code}): #{url}"
      else
        raise FetchError, "HTTP error (#{response.code}): #{url}"
      end
    end

    # ---------------------------------------------------------------------------
    # Parse Wizards HTML to extract card names
    #
    # The Wizards page may use various structures for displaying the Game Changers list.
    # We'll try multiple parsing strategies:
    # 1. Look for lists after the #gamechangers anchor
    # 2. Look for JSON embedded in script tags
    # 3. Parse HTML elements with card-related classes/attributes
    # 4. Look for structured data (JSON-LD, microdata)
    #
    # Arguments:
    #   html (String) - The HTML content from Wizards
    #
    # Returns: Array of card names (may contain duplicates and unnormalized names)
    # Raises: ParseError if no cards can be extracted
    # ---------------------------------------------------------------------------
    def parse_wizards_html(html)
      doc = Nokogiri::HTML(html)
      card_names = []

      # Strategy 1: Look for embedded JSON in script tags
      doc.css("script[type='application/json']").each do |script|
        begin
          data = JSON.parse(script.content)
          # Try to extract cards from various possible structures
          card_names.concat(extract_cards_from_json(data))
        rescue JSON::ParserError
          # Skip invalid JSON
        end
      end

      return card_names unless card_names.empty?

      # Strategy 2: Look for common HTML patterns used for card lists
      # Try various selectors that might contain card names
      [
        ".card-name",
        "[data-card-name]",
        ".cardboard-card",
        ".card-item",
        "a[href*='/cards/']"
      ].each do |selector|
        elements = doc.css(selector)
        elements.each do |element|
          name = element.attr("data-card-name") || element.text.strip
          card_names << name if name.present?
        end
        return card_names unless card_names.empty?
      end

      card_names
    end

    # ---------------------------------------------------------------------------
    # Extract card names from JSON data structure
    #
    # Recursively searches JSON for arrays of card objects or card name strings
    #
    # Arguments:
    #   data (Hash|Array) - JSON data structure
    #
    # Returns: Array of card names
    # ---------------------------------------------------------------------------
    def extract_cards_from_json(data)
      card_names = []

      case data
      when Hash
        # Look for common keys that might contain card data
        if data["cards"].is_a?(Array)
          card_names.concat(data["cards"].map { |c| extract_card_name(c) }.compact)
        elsif data["cardviews"].is_a?(Array)
          card_names.concat(data["cardviews"].map { |c| extract_card_name(c) }.compact)
        elsif data["data"].is_a?(Array)
          card_names.concat(data["data"].map { |c| extract_card_name(c) }.compact)
        else
          # Recursively search all values
          data.values.each do |value|
            card_names.concat(extract_cards_from_json(value))
          end
        end
      when Array
        data.each do |item|
          card_names.concat(extract_cards_from_json(item))
        end
      end

      card_names
    end

    # ---------------------------------------------------------------------------
    # Extract card name from a JSON object or string
    #
    # Arguments:
    #   card (Hash|String) - Card data
    #
    # Returns: String|nil - The card name, or nil if not found
    # ---------------------------------------------------------------------------
    def extract_card_name(card)
      case card
      when String
        card
      when Hash
        card["name"] || card["card_name"] || card["cardName"]
      end
    end

    # ---------------------------------------------------------------------------
    # Parse Scryfall JSON API response
    #
    # Arguments:
    #   json_string (String) - JSON response from Scryfall
    #
    # Returns: Hash with :cards (Array of card names) and :next_page (String|nil)
    # Raises: ParseError if JSON structure is invalid
    # ---------------------------------------------------------------------------
    def parse_scryfall_json(json_string)
      data = JSON.parse(json_string)

      unless data["object"] == "list" && data["data"].is_a?(Array)
        raise ParseError, "Invalid Scryfall API response structure: expected list object with data array"
      end

      cards = data["data"].map do |card|
        unless card["name"]
          Rails.logger.warn("Scryfall card missing name field: #{card.inspect}")
          next
        end
        card["name"]
      end.compact

      {
        cards: cards,
        next_page: data["next_page"]
      }
    end

    # ---------------------------------------------------------------------------
    # Normalize and sort card names
    #
    # - Strip whitespace
    # - Collapse multiple spaces
    # - Handle double-faced cards (use front face only)
    # - Remove duplicates
    # - Sort alphabetically
    #
    # Arguments:
    #   card_names (Array) - Array of card names
    #
    # Returns: Array of normalized, sorted, unique card names
    # ---------------------------------------------------------------------------
    def normalize_and_sort(card_names)
      card_names
        .map { |name| normalize_card_name(name) }
        .compact
        .uniq
        .sort
    end

    # ---------------------------------------------------------------------------
    # Normalize a single card name
    #
    # Arguments:
    #   name (String) - Card name
    #
    # Returns: String - Normalized card name
    # ---------------------------------------------------------------------------
    def normalize_card_name(name)
      return nil if name.blank?

      # Strip whitespace
      normalized = name.strip

      # Collapse multiple spaces
      normalized = normalized.gsub(/\s+/, " ")

      # Handle double-faced cards: use front face only
      # Format: "Front Face // Back Face" -> "Front Face"
      normalized = normalized.split(" // ").first.strip if normalized.include?(" // ")

      # Normalize various quote styles to standard double quotes
      normalized = normalized.gsub(/["""]/, '"')

      normalized
    end
  end
end
