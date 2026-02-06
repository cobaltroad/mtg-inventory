require "net/http"
require "uri"
require "json"

# Fetches card details from Scryfall API and caches results to minimize API calls.
# Used to retrieve printing-specific information for cards in a user's inventory.
class CardDetailsService
  # Cache card details for 24 hours to reduce API usage.
  # Can be overridden via CARD_DETAILS_CACHE_TTL environment variable (in seconds).
  CACHE_TTL = (ENV.fetch("CARD_DETAILS_CACHE_TTL", 24.hours.to_s).to_i).seconds

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
  # Fetches card details from Scryfall API or cache.
  # Returns hash with card data or nil if card not found.
  #
  # Caching strategy:
  # - Card details are cached by card_id (UUID)
  # - Cache TTL: 24 hours by default (configurable via CARD_DETAILS_CACHE_TTL)
  # - Returns nil for 404 responses
  # - Raises exceptions for network errors, timeouts, and rate limits
  # ---------------------------------------------------------------------------
  def call
    fetch_card_details_with_cache
  end

  private

  # Fetches card details from cache if available, otherwise calls external API.
  def fetch_card_details_with_cache
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      fetch_card_details_from_scryfall
    end
  end

  # Generates a cache key for the given card_id
  def cache_key
    "card_details:#{@card_id}"
  end

  # Fetches card details from the Scryfall API
  def fetch_card_details_from_scryfall
    uri = build_card_uri
    response = make_http_request(uri)

    # Return nil for 404 (card not found)
    return nil if response.code.to_i == 404

    card_data = parse_json_response(response)
    format_card_details(card_data)
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    raise NetworkError, "Network error while connecting to Scryfall API: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TimeoutError, "Request to Scryfall API timeout: #{e.message}"
  end

  # Builds the Scryfall API card URI
  def build_card_uri
    URI("#{SCRYFALL_API_BASE}/cards/#{@card_id}")
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

  # Parses JSON response and raises error if invalid
  def parse_json_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise InvalidResponseError, "Invalid JSON response from Scryfall API: #{e.message}"
  end

  # Maps Scryfall card data to our expected format
  def format_card_details(card)
    {
      id: card["id"],
      name: card["name"],
      set: card["set"],
      set_name: card["set_name"],
      collector_number: card["collector_number"],
      released_at: card["released_at"],
      image_url: extract_image_url(card)
    }
  end

  # Extracts image URL from Scryfall card data
  # Handles both single-faced and double-faced cards
  def extract_image_url(card)
    # For double-faced cards, use the first face's image
    if card["card_faces"]&.any?
      card.dig("card_faces", 0, "image_uris", "normal")
    else
      card.dig("image_uris", "normal")
    end
  end
end
