require "test_helper"
require "webmock/minitest"

class CardSearchIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    WebMock.reset!
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  # ---------------------------------------------------------------------------
  # Scenario 1 -- search by name returns all printings with expected fields
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search returns formatted card results" do
    scryfall_response = {
      "object" => "list",
      "data" => [
        {
          "id" => "1001",
          "name" => "Lightning Bolt",
          "set" => "lea",
          "set_name" => "Limited Edition Alpha",
          "collector_number" => "157",
          "image_uris" => { "normal" => "https://example.com/bolt1.jpg" },
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        },
        {
          "id" => "1002",
          "name" => "Lightning Bolt",
          "set" => "m11",
          "set_name" => "Magic 2011",
          "collector_number" => "149",
          "image_uris" => { "normal" => "https://example.com/bolt2.jpg" },
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        }
      ]
    }

    stub_scryfall("Lightning Bolt", scryfall_response)

    get api_path("/cards/search"), params: { q: "Lightning Bolt" }

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 2, body["cards"].size

    first = body["cards"].first
    assert_equal "1001", first["id"]
    assert_equal "Lightning Bolt", first["name"]
    assert_equal "lea", first["set"]
    assert_equal "Limited Edition Alpha", first["set_name"]
    assert_equal "157", first["collector_number"]
    assert_equal "https://example.com/bolt1.jpg", first["image_url"]
    assert_equal [], first["treatments"]
  end

  # ---------------------------------------------------------------------------
  # Scenario 2 -- filter by single treatment
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search filters by single treatment" do
    scryfall_response = {
      "object" => "list",
      "data" => [
        {
          "id" => "2001",
          "name" => "Opt",
          "set" => "dom",
          "set_name" => "Dominaria",
          "collector_number" => "98",
          "image_uris" => { "normal" => "https://example.com/opt1.jpg" },
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        },
        {
          "id" => "2002",
          "name" => "Opt",
          "set" => "c20",
          "set_name" => "Commander 2020",
          "collector_number" => "72",
          "image_uris" => { "normal" => "https://example.com/opt2.jpg" },
          "border_color" => "borderless",
          "finishes" => ["nonfoil"]
        }
      ]
    }

    stub_scryfall("Opt", scryfall_response)

    get api_path("/cards/search"), params: { q: "Opt", treatments: [ "borderless" ] }

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body["cards"].size
    assert_equal "2002", body["cards"].first["id"]
    assert_includes body["cards"].first["treatments"], "borderless"
  end

  # ---------------------------------------------------------------------------
  # Scenario 3 -- multiple treatment filters use OR logic
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search with multiple treatments uses OR logic" do
    scryfall_response = {
      "object" => "list",
      "data" => [
        {
          "id" => "3001",
          "name" => "Thoughtseize",
          "set" => "set_a",
          "set_name" => "Set A",
          "collector_number" => "1",
          "image_uris" => { "normal" => "https://example.com/t1.jpg" },
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        },
        {
          "id" => "3002",
          "name" => "Thoughtseize",
          "set" => "set_b",
          "set_name" => "Set B",
          "collector_number" => "2",
          "image_uris" => { "normal" => "https://example.com/t2.jpg" },
          "border_color" => "borderless",
          "finishes" => ["nonfoil"]
        },
        {
          "id" => "3003",
          "name" => "Thoughtseize",
          "set" => "set_c",
          "set_name" => "Set C",
          "collector_number" => "3",
          "image_uris" => { "normal" => "https://example.com/t3.jpg" },
          "border_color" => "black",
          "finishes" => ["foil"]
        }
      ]
    }

    stub_scryfall("Thoughtseize", scryfall_response)

    get api_path("/cards/search"), params: { q: "Thoughtseize", treatments: [ "borderless", "foil" ] }

    assert_response :success
    body = JSON.parse(response.body)

    # Card 3002 (borderless) and 3003 (foil) should match
    assert_equal 2, body["cards"].size
    ids = body["cards"].map { |c| c["id"] }
    assert_includes ids, "3002"
    assert_includes ids, "3003"
  end

  # ---------------------------------------------------------------------------
  # Scenario 4 -- treatment filter with no matches returns empty array
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search returns empty cards array for non-matching treatment" do
    scryfall_response = {
      "object" => "list",
      "data" => [
        {
          "id" => "4001",
          "name" => "Giant Growth",
          "set" => "lea",
          "set_name" => "Limited Edition Alpha",
          "collector_number" => "200",
          "image_uris" => { "normal" => "https://example.com/gg.jpg" },
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        }
      ]
    }

    stub_scryfall("Giant Growth", scryfall_response)

    get api_path("/cards/search"), params: { q: "Giant Growth", treatments: [ "borderless" ] }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body["cards"]
  end

  # ---------------------------------------------------------------------------
  # Scenario 6 -- performance: results returned within 500 ms
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search completes within 500ms" do
    scryfall_response = {
      "object" => "list",
      "data" => [
        {
          "id" => "6001",
          "name" => "Counterspell",
          "set" => "lea",
          "set_name" => "Limited Edition Alpha",
          "collector_number" => "54",
          "image_uris" => { "normal" => "https://example.com/counter.jpg" },
          "border_color" => "black",
          "finishes" => ["nonfoil"]
        }
      ]
    }

    stub_scryfall("Counterspell", scryfall_response)

    elapsed_ms = nil
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    get api_path("/cards/search"), params: { q: "Counterspell" }
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

    assert_response :success
    assert elapsed_ms < 500, "Response took #{elapsed_ms.round(1)} ms (limit: 500 ms)"
  end

  private

  def stub_scryfall(query, response_body)
    encoded_query = CGI.escape(query)
    stub_request(:get, "https://api.scryfall.com/cards/search?q=#{encoded_query}")
      .to_return(
        status: 200,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
