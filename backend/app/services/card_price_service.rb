require "net/http"
require "uri"
require "json"

# Fetches current market prices for Magic: The Gathering cards from Scryfall API.
# Implements caching, retry logic, and error handling for reliable price data retrieval.
#
# Pricing data includes USD, USD foil, and USD etched variants. Prices are converted
# from dollars to cents (integers) to avoid floating-point precision issues.
class CardPriceService
  # Cache price data for 24 hours to reduce API usage.
  # Can be overridden via CARD_PRICE_CACHE_TTL environment variable (in seconds).
  CACHE_TTL = (ENV.fetch("CARD_PRICE_CACHE_TTL", 24.hours.to_s).to_i).seconds

  # Scryfall API configuration
  SCRYFALL_API_BASE = "https://api.scryfall.com"
  REQUEST_TIMEOUT = 10 # seconds
  USER_AGENT = "mtg-inventory/1.0"

  # Retry configuration
  MAX_RETRIES = 3
  INITIAL_BACKOFF = 1 # second
  BACKOFF_MULTIPLIER = 2

  # Custom exception classes for error handling
  class RateLimitError < StandardError; end
  class NetworkError < StandardError; end
  class TimeoutError < StandardError; end
  class InvalidResponseError < StandardError; end

  def initialize(card_id:)
    @card_id = card_id
  end

  # ---------------------------------------------------------------------------
  # Fetches card prices from Scryfall API or cache.
  # Returns hash with price data in cents or nil if card not found.
  #
  # Caching strategy:
  # - Prices are cached by card_id (UUID)
  # - Cache TTL: 24 hours by default (configurable via CARD_PRICE_CACHE_TTL)
  # - Returns nil for 404 responses
  # - Raises exceptions for network errors, timeouts, and rate limits
  #
  # Return format:
  # {
  #   card_id: String,
  #   usd_cents: Integer or nil,
  #   usd_foil_cents: Integer or nil,
  #   usd_etched_cents: Integer or nil,
  #   fetched_at: Time
  # }
  # ---------------------------------------------------------------------------
  def call
    fetch_prices_with_cache
  end

  private

  # Fetches prices from cache if available, otherwise calls external API.
  def fetch_prices_with_cache
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      fetch_prices_from_scryfall
    end
  end

  # Generates a cache key for the given card_id
  def cache_key
    "card_price:#{@card_id}"
  end

  # Fetches card prices from the Scryfall API with retry logic
  def fetch_prices_from_scryfall
    attempt = 0

    begin
      attempt += 1
      uri = build_card_uri
      response = make_http_request(uri)

      # Return nil for 404 (card not found)
      return nil if response.code.to_i == 404

      card_data = parse_json_response(response)
      format_price_data(card_data)
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      if attempt < MAX_RETRIES
        sleep_duration = INITIAL_BACKOFF * (BACKOFF_MULTIPLIER ** (attempt - 1))
        sleep(sleep_duration)
        retry
      else
        Rails.logger.error("Critical: Failed to fetch prices for card #{@card_id} after #{MAX_RETRIES} attempts: #{e.message}")
        raise NetworkError, "Network error while connecting to Scryfall API: #{e.message}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise TimeoutError, "Request to Scryfall API timeout: #{e.message}"
    end
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

  # Handles HTTP response status codes with retry logic for rate limits
  def handle_response_status(response)
    case response.code.to_i
    when 200
      # Success - continue processing
    when 404
      # Not found - handled by caller
    when 429
      Rails.logger.error("Rate limit exceeded for card #{@card_id}")
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

  # Formats Scryfall card data into our price structure
  # Converts dollar amounts to cents (integers)
  def format_price_data(card)
    prices = card["prices"] || {}

    # Check if all prices are nil
    if prices["usd"].nil? && prices["usd_foil"].nil? && prices["usd_etched"].nil?
      Rails.logger.info("Card #{@card_id} has no price data available")
    end

    {
      card_id: @card_id,
      usd_cents: convert_to_cents(prices["usd"]),
      usd_foil_cents: convert_to_cents(prices["usd_foil"]),
      usd_etched_cents: convert_to_cents(prices["usd_etched"]),
      fetched_at: Time.current
    }
  end

  # Converts dollar string to cents (integer)
  # Returns nil if input is nil
  # Rounds to nearest cent for prices with more than 2 decimal places
  def convert_to_cents(price_string)
    return nil if price_string.nil?

    (price_string.to_f * 100).round
  end
end
