# frozen_string_literal: true

# Shared test helpers for CardSearchService tests
# Provides common stubbing methods and response builders to reduce duplication
module CardSearchTestHelper
  # Helper: Build Scryfall API URL for a given query
  def scryfall_url(query)
    "https://api.scryfall.com/cards/search?q=#{CGI.escape(query)}"
  end

  # Helper: Stub a successful Scryfall API response
  def stub_scryfall_request(query, response_body)
    stub_request(:get, scryfall_url(query))
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Helper: Create a minimal valid Scryfall response with a single card
  # Accepts custom attributes to override defaults
  def scryfall_response_with_card(attributes = {})
    default_card = {
      "id" => "test-123",
      "name" => "Test Card",
      "set" => "tst",
      "set_name" => "Test Set",
      "collector_number" => "1",
      "image_uris" => { "normal" => "http://example.com/test.jpg" },
      "border_color" => "black",
      "finishes" => ["nonfoil"]
    }

    # Handle image_url shortcut (convenience for tests)
    if attributes[:image_url]
      attributes["image_uris"] = { "normal" => attributes.delete(:image_url) }
    end

    {
      "object" => "list",
      "data" => [default_card.merge(attributes.transform_keys(&:to_s))]
    }
  end
end
