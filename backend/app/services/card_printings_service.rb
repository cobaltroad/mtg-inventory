require "net/http"
require "uri"
require "json"

class CardPrintingsService
  # Cache printings API results for 24 hours to reduce API usage.
  # Can be overridden via CARD_PRINTINGS_CACHE_TTL environment variable (in seconds).
  CACHE_TTL = (ENV.fetch("CARD_PRINTINGS_CACHE_TTL", 24.hours.to_s).to_i).seconds

  # Scryfall API configuration
  SCRYFALL_API_BASE = "https://api.scryfall.com"
  REQUEST_TIMEOUT = 10 # seconds
  USER_AGENT = "mtg-inventory/1.0"

  # Custom exception classes for error handling
  class RateLimitError < StandardError; end
  class NetworkError < StandardError; end
  class TimeoutError < StandardError; end
  class InvalidResponseError < StandardError; end

  def initialize(card_id:)
    @card_id = card_id
  end

  # ---------------------------------------------------------------------------
  # Fetches all printings for a specific card from Scryfall API.
  # Returns array of printings sorted by release date (newest first).
  #
  # API Flow:
  # 1. Fetch card at /cards/{id} to get prints_search_uri
  # 2. Fetch all printings from prints_search_uri (handles pagination automatically)
  #
  # Caching strategy:
  # - External API results are cached by card_id
  # - Cache TTL: 24 hours by default (configurable via CARD_PRINTINGS_CACHE_TTL)
  # ---------------------------------------------------------------------------
  def call
    fetch_printings_with_cache
  end

  private

  # ---------------------------------------------------------------------------
  # Fetches printings from cache if available, otherwise calls external API.
  # ---------------------------------------------------------------------------
  def fetch_printings_with_cache
    Rails.cache.fetch(cache_key_for_card, expires_in: CACHE_TTL) do
      fetch_printings_from_scryfall
    end
  end

  # Generates a cache key for the given card_id
  def cache_key_for_card
    "card_printings:#{@card_id}"
  end

  # Fetches all printings for a card from the Scryfall API using two-step flow:
  # 1. Fetch card to get prints_search_uri
  # 2. Fetch prints from the prints_search_uri (with pagination support)
  def fetch_printings_from_scryfall
    prints_search_uri = fetch_prints_search_uri
    return [] unless prints_search_uri

    fetch_all_printings_pages(prints_search_uri)
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    raise NetworkError, "Network error while connecting to Scryfall API: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TimeoutError, "Request to Scryfall API timeout: #{e.message}"
  end

  # Fetches the prints_search_uri from the card endpoint
  # Returns nil if card is not found or prints_search_uri is missing
  def fetch_prints_search_uri
    card_uri = build_card_uri
    card_response = make_http_request(card_uri)
    return nil if card_response.code.to_i == 404

    card_data = parse_json_response(card_response)
    card_data["prints_search_uri"]
  end

  # Builds the Scryfall API card URI
  def build_card_uri
    URI("#{SCRYFALL_API_BASE}/cards/#{@card_id}")
  end

  # Fetches all pages of printings, handling pagination
  def fetch_all_printings_pages(initial_uri)
    all_printings = []
    current_uri = initial_uri

    loop do
      uri = URI(current_uri)
      response = make_http_request(uri)
      data = parse_json_response(response)

      # Extract and format printings from current page
      if data["data"].is_a?(Array)
        printings = data["data"].map { |card| format_printing(card) }
        all_printings.concat(printings)
      end

      # Check if there are more pages
      break unless data["has_more"] == true && data["next_page"]

      current_uri = data["next_page"]
    end

    sort_printings_by_date(all_printings)
  end

  # Parses JSON response and raises error if invalid
  def parse_json_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise InvalidResponseError, "Invalid JSON response from Scryfall API: #{e.message}"
  end

  # Makes HTTP GET request to Scryfall API with appropriate headers
  def make_http_request(uri)
    http = create_http_client(uri)
    request = create_request(uri)

    response = http.request(request)
    handle_response_status(response)
    response
  end

  # Creates and configures HTTP client
  def create_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = REQUEST_TIMEOUT
    http.read_timeout = REQUEST_TIMEOUT
    http
  end

  # Creates HTTP request with required headers
  def create_request(uri)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    request
  end

  # Handles HTTP response status codes
  def handle_response_status(response)
    case response.code.to_i
    when 200
      # Success - continue processing
    when 404
      # Not found - handled by caller
    when 429
      raise RateLimitError, "Scryfall API rate limit exceeded. Please try again later."
    else
      raise InvalidResponseError, "Scryfall API returned unexpected status: #{response.code}"
    end
  end

  # Maps Scryfall card data to our expected format for a printing
  def format_printing(card)
    {
      id: card["id"],
      name: card["name"],
      set: card["set"],
      set_name: card["set_name"],
      collector_number: card["collector_number"],
      image_url: extract_image_url(card),
      released_at: card["released_at"]
    }
  end

  # Extracts image URL from Scryfall card data
  def extract_image_url(card)
    card.dig("image_uris", "normal")
  end

  # Sorts printings by release date, newest first
  def sort_printings_by_date(printings)
    printings.sort_by { |p| p[:released_at] }.reverse
  end
end
