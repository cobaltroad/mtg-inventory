require "net/http"
require "uri"
require "json"

class ScryfallCardResolver
  SCRYFALL_API_BASE = "https://api.scryfall.com"
  RATE_LIMIT_MS = 100
  MAX_RETRIES = 3
  INITIAL_BACKOFF_MS = 500
  USER_AGENT = "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)"
  REQUEST_TIMEOUT = 10 # seconds

  # Custom exception class for resolution errors
  class ResolutionError < StandardError; end

  # Class-level cache for resolved cards
  @cache = {}
  @last_request_time = nil

  class << self
    attr_accessor :cache, :last_request_time
  end

  # ---------------------------------------------------------------------------
  # Resolves an array of card names to Scryfall IDs and URIs
  #
  # Arguments:
  #   card_names (Array<String>) - Array of card names to resolve
  #
  # Returns:
  #   Hash - Mapping of card_name => { id: scryfall_id, uri: scryfall_uri } (or nil if not found)
  #
  # Example:
  #   resolve_cards(["Sol Ring", "Lightning Bolt"])
  #   => {
  #     "Sol Ring" => { id: "abc123", uri: "https://scryfall.com/card/..." },
  #     "Lightning Bolt" => { id: "def456", uri: "https://scryfall.com/card/..." }
  #   }
  # ---------------------------------------------------------------------------
  def self.resolve_cards(card_names)
    result = {}

    card_names.each do |card_name|
      # Check cache first
      if cache.key?(card_name)
        result[card_name] = cache[card_name]
        next
      end

      # Enforce rate limiting before making request
      enforce_rate_limit

      # Resolve card and cache result
      card_data = resolve_single_card(card_name)
      cache[card_name] = card_data
      result[card_name] = card_data
    end

    result
  end

  # ---------------------------------------------------------------------------
  # Clears the resolution cache (useful for testing)
  # ---------------------------------------------------------------------------
  def self.clear_cache
    @cache = {}
    @last_request_time = nil
  end

  # ---------------------------------------------------------------------------
  # Resolves a single card name to its Scryfall data using fuzzy search
  #
  # Arguments:
  #   card_name (String) - The card name to resolve
  #
  # Returns:
  #   Hash or nil - { id: scryfall_id, uri: scryfall_uri } if found, nil otherwise
  # ---------------------------------------------------------------------------
  private_class_method def self.resolve_single_card(card_name)
    (MAX_RETRIES + 1).times do |attempt|
      begin
        response = fetch_card_from_scryfall(card_name)
        result = handle_response(response, card_name, attempt)

        # If result is :retry symbol, continue to next iteration
        next if result == :retry

        return result
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
        log_network_error(card_name, e)
        return nil
      rescue JSON::ParserError => e
        log_json_error(card_name, e)
        return nil
      rescue StandardError => e
        log_unexpected_error(card_name, e)
        return nil
      end
    end

    nil
  end

  # ---------------------------------------------------------------------------
  # Handles HTTP response and extracts Scryfall ID or handles errors
  # ---------------------------------------------------------------------------
  private_class_method def self.handle_response(response, card_name, attempt)
    case response
    when Net::HTTPSuccess
      extract_scryfall_id(response)
    when Net::HTTPNotFound
      log_card_not_found(card_name)
      nil
    when Net::HTTPTooManyRequests
      handle_too_many_requests(card_name, attempt)
    else
      log_http_error(card_name, response.code)
      nil
    end
  end

  # ---------------------------------------------------------------------------
  # Extracts Scryfall data from successful response
  # ---------------------------------------------------------------------------
  private_class_method def self.extract_scryfall_id(response)
    data = JSON.parse(response.body)
    {
      id: data["id"],
      uri: data["scryfall_uri"]
    }
  end

  # ---------------------------------------------------------------------------
  # Handles 429 rate limit response with retry logic
  # ---------------------------------------------------------------------------
  private_class_method def self.handle_too_many_requests(card_name, attempt)
    if attempt < MAX_RETRIES
      apply_exponential_backoff(card_name, attempt)
      :retry # Signal to retry
    else
      log_max_retries_exceeded(card_name)
      nil
    end
  end

  # ---------------------------------------------------------------------------
  # Fetches card data from Scryfall's fuzzy search endpoint
  # ---------------------------------------------------------------------------
  private_class_method def self.fetch_card_from_scryfall(card_name)
    uri = build_fuzzy_search_uri(card_name)
    request = build_http_request(uri)

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: REQUEST_TIMEOUT) do |http|
      http.request(request)
    end
  end

  # ---------------------------------------------------------------------------
  # Builds URI for Scryfall fuzzy search endpoint
  # ---------------------------------------------------------------------------
  private_class_method def self.build_fuzzy_search_uri(card_name)
    uri = URI("#{SCRYFALL_API_BASE}/cards/named")
    uri.query = URI.encode_www_form({ fuzzy: card_name })
    uri
  end

  # ---------------------------------------------------------------------------
  # Builds HTTP request with appropriate headers
  # ---------------------------------------------------------------------------
  private_class_method def self.build_http_request(uri)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    request
  end

  # ---------------------------------------------------------------------------
  # Applies exponential backoff for rate limiting
  # ---------------------------------------------------------------------------
  private_class_method def self.apply_exponential_backoff(card_name, retry_count)
    backoff_ms = INITIAL_BACKOFF_MS * (2**retry_count)
    Rails.logger.warn("ScryfallCardResolver: Rate limit (429) hit for '#{card_name}' - backing off #{backoff_ms}ms")
    sleep(backoff_ms / 1000.0)
  end

  # ---------------------------------------------------------------------------
  # Enforces rate limiting between Scryfall API requests
  # ---------------------------------------------------------------------------
  private_class_method def self.enforce_rate_limit
    if last_request_time
      elapsed_ms = (Time.now - last_request_time) * 1000
      sleep_ms = RATE_LIMIT_MS - elapsed_ms
      sleep(sleep_ms / 1000.0) if sleep_ms > 0
    end

    self.last_request_time = Time.now
  end

  # ---------------------------------------------------------------------------
  # Logging helper methods
  # ---------------------------------------------------------------------------
  private_class_method def self.log_card_not_found(card_name)
    Rails.logger.warn("ScryfallCardResolver: Could not resolve card '#{card_name}' - not found on Scryfall")
  end

  private_class_method def self.log_max_retries_exceeded(card_name)
    Rails.logger.error("ScryfallCardResolver: Max retries exceeded for '#{card_name}'")
  end

  private_class_method def self.log_http_error(card_name, status_code)
    Rails.logger.error("ScryfallCardResolver: HTTP error #{status_code} for '#{card_name}'")
  end

  private_class_method def self.log_network_error(card_name, error)
    Rails.logger.error("ScryfallCardResolver: Network error for '#{card_name}' - #{error.class}: #{error.message}")
  end

  private_class_method def self.log_json_error(card_name, error)
    Rails.logger.error("ScryfallCardResolver: JSON parse error for '#{card_name}' - #{error.message}")
  end

  private_class_method def self.log_unexpected_error(card_name, error)
    Rails.logger.error("ScryfallCardResolver: Unexpected error for '#{card_name}' - #{error.class}: #{error.message}")
  end
end
