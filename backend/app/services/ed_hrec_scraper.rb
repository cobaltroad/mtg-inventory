require "net/http"
require "uri"
require "nokogiri"

class EdHrecScraper
  BASE_URL = "https://edhrec.com"
  COMMANDERS_WEEK_URL = "#{BASE_URL}/commanders/week"
  USER_AGENT = "MTG-Inventory-Bot/1.0 (https://github.com/cobaltroad/mtg-inventory)"
  REQUEST_TIMEOUT = 10 # seconds

  # Custom exception classes for error handling
  class FetchError < StandardError; end
  class ParseError < StandardError; end

  # Fetches and parses the EDHREC weekly top commanders page
  # Returns an array of commander hashes with :name, :rank, and :url
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

  private_class_method def self.parse_commanders(html)
    doc = Nokogiri::HTML(html)

    # Find all commander cards - this selector needs to match the actual EDHREC HTML structure
    # Based on typical EDHREC structure, commanders are in divs with class 'card' containing links
    commander_elements = doc.css(".card a[href*='/commanders/']")

    if commander_elements.empty?
      Rails.logger.error("EdHrecScraper: No commander elements found in HTML")
      raise ParseError, "Could not find commander elements in HTML - page structure may have changed"
    end

    commanders = []
    commander_elements.each_with_index do |element, index|
      rank = index + 1
      break if rank > 20  # Only take top 20

      # Extract commander name - try different possible selectors
      name = extract_commander_name(element)

      # Extract URL from href attribute
      href = element["href"]
      next unless href

      # Ensure URL is absolute
      url = href.start_with?("http") ? href : "#{BASE_URL}#{href}"

      commanders << {
        name: name,
        rank: rank,
        url: url
      }
    end

    # Log warning if fewer than 20 commanders found
    if commanders.length < 20
      Rails.logger.warn("EdHrecScraper: Found only #{commanders.length} commanders (expected 20)")
    end

    if commanders.empty?
      raise ParseError, "No commanders could be parsed from HTML"
    end

    commanders
  rescue Nokogiri::XML::SyntaxError => e
    Rails.logger.error("EdHrecScraper: HTML parsing error - #{e.message}")
    raise ParseError, "Failed to parse HTML: #{e.message}"
  end

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
