require "net/http"
require "uri"
require "json"

class CardSearchService
  VALID_TREATMENTS = %w[foil etched borderless showcase extended_art full_art].freeze

  # Cache external API results for 24 hours to reduce API usage.
  # Can be overridden via CARD_SEARCH_CACHE_TTL environment variable (in seconds).
  CACHE_TTL = (ENV.fetch("CARD_SEARCH_CACHE_TTL", 24.hours.to_s).to_i).seconds

  # Scryfall API configuration
  SCRYFALL_API_BASE = "https://api.scryfall.com"
  SCRYFALL_SEARCH_ENDPOINT = "#{SCRYFALL_API_BASE}/cards/search"
  REQUEST_TIMEOUT = 10 # seconds
  USER_AGENT = "mtg-inventory/1.0"

  # Custom exception classes for error handling
  class RateLimitError < StandardError; end
  class NetworkError < StandardError; end
  class TimeoutError < StandardError; end
  class InvalidResponseError < StandardError; end

  def initialize(query:, treatments: [])
    @query = query
    @treatments = treatments & VALID_TREATMENTS
  end

  # ---------------------------------------------------------------------------
  # Fetches a single page of cards matching the query, derives treatments for
  # each card, and optionally filters to only cards that carry at least one of
  # the requested treatments (OR logic).
  #
  # Caching strategy:
  # - External API results are cached by query string only (not treatments)
  # - Treatment filtering is applied after cache retrieval
  # - This allows different treatment filters to share the same cached API data
  # - Cache TTL: 24 hours by default (configurable via CARD_SEARCH_CACHE_TTL)
  # ---------------------------------------------------------------------------
  def call
    results = fetch_cards_with_cache
    @treatments.any? ? filter_by_treatments(results) : results
  end

  private

  # ---------------------------------------------------------------------------
  # Fetches cards from cache if available, otherwise calls external API.
  # Cache key is based only on query to allow treatment filtering from cache.
  # ---------------------------------------------------------------------------
  def fetch_cards_with_cache
    Rails.cache.fetch(cache_key_for_query, expires_in: CACHE_TTL) do
      fetch_cards_from_scryfall
    end
  end

  # Generates a cache key for the given query string
  def cache_key_for_query
    "card_search:#{@query}"
  end

  # Fetches cards from the Scryfall API and formats them
  def fetch_cards_from_scryfall
    uri = build_search_uri
    response = make_http_request(uri)
    parse_and_format_response(response)
  rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    raise NetworkError, "Network error while connecting to Scryfall API: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TimeoutError, "Request to Scryfall API timeout: #{e.message}"
  end

  # Builds the Scryfall API search URI with query parameter
  def build_search_uri
    uri = URI(SCRYFALL_SEARCH_ENDPOINT)
    uri.query = URI.encode_www_form(q: @query)
    uri
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
      # Not found - will return empty results
    when 429
      raise RateLimitError, "Scryfall API rate limit exceeded. Please try again later."
    else
      raise InvalidResponseError, "Scryfall API returned unexpected status: #{response.code}"
    end
  end

  # Parses JSON response and formats cards
  def parse_and_format_response(response)
    return [] if response.code.to_i == 404

    begin
      data = JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise InvalidResponseError, "Invalid JSON response from Scryfall API: #{e.message}"
    end

    return [] unless data["data"].is_a?(Array)

    data["data"].map { |card| format_card(card) }
  end

  # Maps Scryfall card data to our expected format
  def format_card(card)
    {
      id: card["id"],
      name: card["name"],
      set: card["set"],
      set_name: card["set_name"],
      collector_number: card["collector_number"],
      image_url: extract_image_url(card),
      treatments: derive_treatments(card)
    }
  end

  # Extracts image URL from Scryfall card data
  def extract_image_url(card)
    card.dig("image_uris", "normal")
  end

  # Derives treatment badges from Scryfall card attributes
  # Checks multiple Scryfall fields to identify special card treatments
  def derive_treatments(card)
    treatments = []

    # Finishes: foil and etched treatments
    treatments.concat(extract_finish_treatments(card))

    # Border color: borderless treatment
    treatments << "borderless" if borderless?(card)

    # Frame effects: showcase and extended art
    treatments.concat(extract_frame_treatments(card))

    # Full art: oversized artwork treatment
    treatments << "full_art" if full_art?(card)

    treatments
  end

  # Extracts treatments from finishes array
  def extract_finish_treatments(card)
    finishes = card["finishes"] || []
    treatments = []
    treatments << "foil" if finishes.include?("foil")
    treatments << "etched" if finishes.include?("etched")
    treatments
  end

  # Checks if card has borderless border
  def borderless?(card)
    card["border_color"] == "borderless"
  end

  # Extracts treatments from frame_effects array
  def extract_frame_treatments(card)
    frame_effects = card["frame_effects"] || []
    treatments = []
    treatments << "showcase" if frame_effects.include?("showcase")
    treatments << "extended_art" if frame_effects.include?("extendedart")
    treatments
  end

  # Checks if card has full art
  def full_art?(card)
    card["full_art"] == true
  end

  # Filters results to only cards with at least one requested treatment
  def filter_by_treatments(results)
    results.select { |card| (card[:treatments] & @treatments).any? }
  end
end
