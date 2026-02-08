require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  # ---------------------------------------------------------------------------
  # #index -- valid searches return 200 with correct JSON structure
  # ---------------------------------------------------------------------------
  test "GET /api/search with valid query returns 200 with correct JSON structure" do
    sample_results = {
      decklists: [
        {
          commander_id: 1,
          commander_name: "Atraxa, Praetors' Voice",
          commander_rank: 5,
          card_matches: [
            { card_name: "Sol Ring", quantity: 1 }
          ],
          match_count: 1
        }
      ]
    }

    SearchService.stub(:new, Object.new.tap { |svc|
      svc.define_singleton_method(:call) { sample_results }
      svc.define_singleton_method(:search_inventory) { |_user, _query| [] }
    }) do
      get api_path("/search"), params: { q: "sol ring" }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "sol ring", body["query"]
    assert_equal 1, body["total_results"]

    # Verify response structure
    assert_equal 1, body["results"]["decklists"].size
    decklist = body["results"]["decklists"].first
    assert_equal 1, decklist["commander_id"]
    assert_equal "Atraxa, Praetors' Voice", decklist["commander_name"]
    assert_equal 5, decklist["commander_rank"]
    assert_equal 1, decklist["match_count"]
    assert_equal 1, decklist["card_matches"].size
    assert_equal "Sol Ring", decklist["card_matches"].first["card_name"]
    assert_equal 1, decklist["card_matches"].first["quantity"]
  end

  test "GET /api/search is case insensitive" do
    sample_results = {
      decklists: [
        {
          commander_id: 1,
          commander_name: "Atraxa, Praetors' Voice",
          commander_rank: 5,
          card_matches: [
            { card_name: "Sol Ring", quantity: 1 }
          ],
          match_count: 1
        }
      ]
    }

    SearchService.stub(:new, Object.new.tap { |svc|
      svc.define_singleton_method(:call) { sample_results }
      svc.define_singleton_method(:search_inventory) { |_user, _query| [] }
    }) do
      get api_path("/search"), params: { q: "SOL RING" }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "SOL RING", body["query"]
  end

  # ---------------------------------------------------------------------------
  # #index -- validation errors
  # ---------------------------------------------------------------------------
  test "GET /api/search without query parameter returns 400 with error message" do
    get api_path("/search")

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal "Search query (q) is required", body["error"]
  end

  test "GET /api/search with query less than 2 characters returns 400 with error message" do
    get api_path("/search"), params: { q: "a" }

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal "Search query must be at least 2 characters", body["error"]
  end

  test "GET /api/search with empty query returns 400 with error message" do
    get api_path("/search"), params: { q: "" }

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal "Search query (q) is required", body["error"]
  end

  # ---------------------------------------------------------------------------
  # #index -- combined decklist and inventory search
  # ---------------------------------------------------------------------------
  test "GET /api/search returns both decklists and inventory in combined response" do
    mock_service = Object.new
    mock_service.define_singleton_method(:call) do
      {
        decklists: [
          {
            commander_id: 1,
            commander_name: "Atraxa, Praetors' Voice",
            commander_rank: 5,
            card_matches: [ { card_name: "Lightning Bolt", quantity: 1 } ],
            match_count: 1
          }
        ]
      }
    end
    mock_service.define_singleton_method(:search_inventory) do |_user, _query|
      [
        {
          id: 1,
          card_id: "test-id",
          card_name: "Lightning Bolt",
          set: "lea",
          set_name: "Limited Edition Alpha",
          collector_number: "161",
          quantity: 4,
          image_url: "https://cards.scryfall.io/normal/test.jpg",
          treatment: "foil",
          unit_price_cents: 500,
          total_price_cents: 2000
        }
      ]
    end

    SearchService.stub(:new, mock_service) do
      get api_path("/search"), params: { q: "lightning bolt" }
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "lightning bolt", body["query"]
    assert_equal 2, body["total_results"]

    # Verify response structure with both decklists and inventory
    assert body["results"].key?("decklists")
    assert body["results"].key?("inventory")

    assert_equal 1, body["results"]["decklists"].size
    assert_equal 1, body["results"]["inventory"].size

    # Verify decklist structure
    decklist = body["results"]["decklists"].first
    assert_equal 1, decklist["commander_id"]
    assert_equal "Atraxa, Praetors' Voice", decklist["commander_name"]

    # Verify inventory structure
    inventory_item = body["results"]["inventory"].first
    assert_equal 1, inventory_item["id"]
    assert_equal "Lightning Bolt", inventory_item["card_name"]
    assert_equal "lea", inventory_item["set"]
    assert_equal 4, inventory_item["quantity"]
  end

  test "GET /api/search total_results counts both decklists and inventory" do
    mock_service = Object.new
    mock_service.define_singleton_method(:call) do
      { decklists: [ { commander_id: 1, match_count: 1 }, { commander_id: 2, match_count: 1 } ] }
    end
    mock_service.define_singleton_method(:search_inventory) do |_user, _query|
      [ { id: 1 }, { id: 2 }, { id: 3 } ]
    end

    SearchService.stub(:new, mock_service) do
      get api_path("/search"), params: { q: "test" }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 5, body["total_results"], "Expected total_results to be sum of decklists (2) + inventory (3)"
  end

  test "GET /api/search with no inventory returns empty array" do
    mock_service = Object.new
    mock_service.define_singleton_method(:call) do
      { decklists: [ { commander_id: 1, match_count: 1 } ] }
    end
    mock_service.define_singleton_method(:search_inventory) do |_user, _query|
      []
    end

    SearchService.stub(:new, mock_service) do
      get api_path("/search"), params: { q: "test" }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["total_results"]
    assert_equal [], body["results"]["inventory"]
    assert_equal 1, body["results"]["decklists"].size
  end
end
