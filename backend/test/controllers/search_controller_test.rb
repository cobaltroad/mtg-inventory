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
end
