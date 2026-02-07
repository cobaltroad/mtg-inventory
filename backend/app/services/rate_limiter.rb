class RateLimiter
  # EDHREC rate limit: 2 seconds between requests
  EDHREC_RATE_LIMIT_MS = 2000

  # Scryfall rate limit: 100ms between requests (documented API limit)
  SCRYFALL_RATE_LIMIT_MS = 100

  # Class-level state for tracking last request times per service
  @last_request_times = {}
  @mutex = Mutex.new

  class << self
    attr_reader :last_request_times, :mutex
  end

  attr_reader :min_interval_ms, :service_name

  # ---------------------------------------------------------------------------
  # Initialize a new rate limiter for a specific service
  #
  # Arguments:
  #   min_interval_ms (Integer) - Minimum milliseconds between requests
  #   service_name (String) - Name of the service (used for state tracking)
  # ---------------------------------------------------------------------------
  def initialize(min_interval_ms:, service_name:)
    @min_interval_ms = min_interval_ms
    @service_name = service_name
  end

  # ---------------------------------------------------------------------------
  # Factory method for EDHREC rate limiter
  # ---------------------------------------------------------------------------
  def self.for_edhrec
    new(min_interval_ms: EDHREC_RATE_LIMIT_MS, service_name: "edhrec")
  end

  # ---------------------------------------------------------------------------
  # Factory method for Scryfall rate limiter
  # ---------------------------------------------------------------------------
  def self.for_scryfall
    new(min_interval_ms: SCRYFALL_RATE_LIMIT_MS, service_name: "scryfall")
  end

  # ---------------------------------------------------------------------------
  # Throttles request to ensure minimum interval is respected
  #
  # This method should be called before making any HTTP request.
  # It will sleep if necessary to enforce the minimum interval.
  # ---------------------------------------------------------------------------
  def throttle
    self.class.mutex.synchronize do
      last_request = self.class.last_request_times[@service_name]

      if last_request
        elapsed_ms = (Time.now - last_request) * 1000
        sleep_ms = @min_interval_ms - elapsed_ms

        if sleep_ms > 0
          sleep(sleep_ms / 1000.0)
        end
      end

      self.class.last_request_times[@service_name] = Time.now
    end
  end

  # ---------------------------------------------------------------------------
  # Clears all rate limiter state (useful for testing)
  # ---------------------------------------------------------------------------
  def self.clear_all_state
    @mutex.synchronize do
      @last_request_times = {}
    end
  end

  # ---------------------------------------------------------------------------
  # Gets the last request time for a specific service (useful for testing)
  # ---------------------------------------------------------------------------
  def self.last_request_time_for(service_name)
    @mutex.synchronize do
      @last_request_times[service_name]
    end
  end
end
