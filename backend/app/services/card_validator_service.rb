require "net/http"
require "uri"
require "json"

# Validates that a card ID exists in the Scryfall database
class CardValidatorService
  SCRYFALL_API_BASE = "https://api.scryfall.com"
  REQUEST_TIMEOUT = 5 # seconds

  class CardNotFoundError < StandardError; end

  def initialize(card_id)
    @card_id = card_id
  end

  # Validates the card exists by fetching it from Scryfall
  # Raises CardNotFoundError if card doesn't exist
  def validate!
    uri = URI("#{SCRYFALL_API_BASE}/cards/#{@card_id}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = REQUEST_TIMEOUT
    http.read_timeout = REQUEST_TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "mtg-inventory/1.0"

    response = http.request(request)

    unless response.code.to_i == 200
      raise CardNotFoundError, "Card not found in MTG database"
    end

    true
  rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    # Network errors shouldn't block inventory creation - log and continue
    Rails.logger.warn("Card validation failed due to network error: #{e.message}")
    true
  end
end
