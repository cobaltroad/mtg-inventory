require "net/http"
require "uri"

# Service to download and cache card images from Scryfall to local Active Storage.
# Used to improve inventory display performance by serving images locally instead of
# fetching them from Scryfall CDN on every page load.
class CardImageCacheService
  # Request timeout in seconds
  REQUEST_TIMEOUT = 10
  USER_AGENT = "mtg-inventory/1.0"

  def initialize(collection_item:, image_url:)
    @collection_item = collection_item
    @image_url = image_url
  end

  # Downloads and caches the card image from Scryfall.
  # Returns a hash with :success flag and optional :downloaded or :error keys.
  # Never raises exceptions - all errors are caught and returned in the result hash.
  def call
    # Validate inputs
    return failure_result("Image URL is required") if @image_url.blank?

    # Skip if image already cached
    if @collection_item.cached_image.attached?
      return { success: true, downloaded: false, cached: true }
    end

    # Download and attach image
    download_and_attach_image
    { success: true, downloaded: true }
  rescue StandardError => e
    log_error(e)
    failure_result(format_error_message(e))
  end

  private

  # Downloads image from URL and attaches to collection item
  def download_and_attach_image
    uri = URI(@image_url)
    image_data = fetch_image_data(uri)

    # Attach image to collection item using Active Storage
    @collection_item.cached_image.attach(
      io: StringIO.new(image_data),
      filename: generate_filename,
      content_type: "image/jpeg"
    )
  end

  # Fetches image data from URL
  def fetch_image_data(uri)
    http = create_http_client(uri)
    request = create_request(uri)

    response = http.request(request)
    validate_response(response)

    response.body
  end

  # Creates and configures HTTP client
  def create_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = REQUEST_TIMEOUT
    http.read_timeout = REQUEST_TIMEOUT
    http
  end

  # Creates HTTP request with headers
  def create_request(uri)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    request
  end

  # Validates HTTP response
  def validate_response(response)
    return if response.code.to_i == 200

    raise "HTTP error #{response.code}: #{response.message}"
  end

  # Generates filename from card ID
  def generate_filename
    "#{@collection_item.card_id}.jpg"
  end

  # Formats error message based on exception type
  def format_error_message(error)
    case error
    when SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      "Network error: #{error.message}"
    when Net::OpenTimeout, Net::ReadTimeout
      "Timeout: #{error.message}"
    else
      "Failed to cache image: #{error.message}"
    end
  end

  # Logs error to Rails logger
  def log_error(error)
    Rails.logger.error(
      "Failed to cache image for card #{@collection_item.card_id}: #{error.class} - #{error.message}"
    )
  end

  # Returns failure result hash
  def failure_result(error_message)
    { success: false, error: error_message }
  end
end
