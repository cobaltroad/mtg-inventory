require "net/http"
require "uri"
require "nokogiri"

class EdHrecScraper
  BASE_URL = "https://edhrec.com"
  COMMANDERS_WEEK_URL = "#{BASE_URL}/commanders/week"
  USER_AGENT = "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)"
  REQUEST_TIMEOUT = 10 # seconds
  EXPECTED_COMMANDER_COUNT = 20
  COMMANDER_CSS_SELECTOR = ".card a[href*='/commanders/']"

  # Custom exception classes for error handling
  class FetchError < StandardError; end
  class ParseError < StandardError; end

  # ---------------------------------------------------------------------------
  # Fetches and parses the EDHREC weekly top commanders page
  #
  # Returns:
  #   Array of hashes, each containing:
  #   - :name (String) - Commander name
  #   - :rank (Integer) - Rank from 1 to 20
  #   - :url (String) - Full EDHREC URL for the commander
  #
  # Raises:
  #   - FetchError: Network errors or HTTP failures
  #   - ParseError: HTML structure doesn't match expected format
  # ---------------------------------------------------------------------------
  def self.fetch_top_commanders
    html = fetch_page(COMMANDERS_WEEK_URL)
    parse_commanders(html)
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    Rails.logger.error("EdHrecScraper: Network error - #{e.class}: #{e.message}")
    raise FetchError, "Network error while fetching commanders: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("EdHrecScraper: Unexpected error - #{e.class}: #{e.message}")
    raise
  end

  # ---------------------------------------------------------------------------
  # Fetches HTML content from the given URL
  #
  # Arguments:
  #   url (String) - The URL to fetch
  #
  # Returns:
  #   String - HTML content of the page
  #
  # Raises:
  #   FetchError: If the HTTP request fails
  # ---------------------------------------------------------------------------
  private_class_method def self.fetch_page(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: REQUEST_TIMEOUT) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("EdHrecScraper: HTTP error #{response.code} for #{url}")
      raise FetchError, "HTTP error #{response.code}: #{response.message}"
    end

    response.body
  end

  # ---------------------------------------------------------------------------
  # Parses HTML content to extract commander information
  #
  # Arguments:
  #   html (String) - HTML content from EDHREC page
  #
  # Returns:
  #   Array of commander hashes with :name, :rank, and :url
  #
  # Raises:
  #   ParseError: If HTML structure is invalid or commanders cannot be extracted
  # ---------------------------------------------------------------------------
  private_class_method def self.parse_commanders(html)
    doc = Nokogiri::HTML(html)
    commander_elements = doc.css(COMMANDER_CSS_SELECTOR)

    validate_commander_elements(commander_elements)

    commanders = extract_commanders_from_elements(commander_elements)
    log_commander_count_warning(commanders.length)
    validate_parsed_commanders(commanders)

    commanders
  rescue Nokogiri::XML::SyntaxError => e
    Rails.logger.error("EdHrecScraper: HTML parsing error - #{e.message}")
    raise ParseError, "Failed to parse HTML: #{e.message}"
  end

  # ---------------------------------------------------------------------------
  # Validates that commander elements were found in the HTML
  # ---------------------------------------------------------------------------
  private_class_method def self.validate_commander_elements(elements)
    return unless elements.empty?

    Rails.logger.error("EdHrecScraper: No commander elements found in HTML")
    raise ParseError, "Could not find commander elements in HTML - page structure may have changed"
  end

  # ---------------------------------------------------------------------------
  # Extracts commander data from Nokogiri element collection
  # ---------------------------------------------------------------------------
  private_class_method def self.extract_commanders_from_elements(elements)
    elements.first(EXPECTED_COMMANDER_COUNT).map.with_index(1) do |element, rank|
      href = element["href"]
      next unless href

      {
        name: extract_commander_name(element),
        rank: rank,
        url: build_absolute_url(href)
      }
    end.compact
  end

  # ---------------------------------------------------------------------------
  # Builds absolute URL from relative or absolute href
  # ---------------------------------------------------------------------------
  private_class_method def self.build_absolute_url(href)
    href.start_with?("http") ? href : "#{BASE_URL}#{href}"
  end

  # ---------------------------------------------------------------------------
  # Logs warning if fewer commanders than expected were found
  # ---------------------------------------------------------------------------
  private_class_method def self.log_commander_count_warning(count)
    return unless count < EXPECTED_COMMANDER_COUNT

    Rails.logger.warn(
      "EdHrecScraper: Found only #{count} commanders (expected #{EXPECTED_COMMANDER_COUNT})"
    )
  end

  # ---------------------------------------------------------------------------
  # Validates that at least some commanders were successfully parsed
  # ---------------------------------------------------------------------------
  private_class_method def self.validate_parsed_commanders(commanders)
    return unless commanders.empty?

    raise ParseError, "No commanders could be parsed from HTML"
  end

  # ---------------------------------------------------------------------------
  # Extracts commander name from element using multiple fallback strategies
  # ---------------------------------------------------------------------------
  private_class_method def self.extract_commander_name(element)
    # Try multiple strategies to extract the name
    name = element.css(".name").first&.text&.strip ||
           element.css(".card-header .name").first&.text&.strip ||
           element.text.strip

    # Clean up the name - remove rank numbers if present
    name = name.gsub(/^\d+\s*/, "").strip

    name.presence || "Unknown Commander"
  end
end
