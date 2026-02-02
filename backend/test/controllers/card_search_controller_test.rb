require "test_helper"

class CardSearchControllerTest < ActionDispatch::IntegrationTest
  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  # ---------------------------------------------------------------------------
  # #index -- returns search results from CardSearchService
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search with valid query returns 200 and cards array" do
    sample_cards = [
      {
        "id" => 1, "name" => "Lightning Bolt", "set" => "lea",
        "set_name" => "Limited Edition Alpha", "collector_number" => "157",
        "image_url" => "https://example.com/bolt.jpg", "treatments" => []
      }
    ]

    CardSearchService.stub(:new, Object.new.tap { |svc|
      svc.define_singleton_method(:call) { sample_cards }
    }) do
      get api_path("/cards/search"), params: { q: "Lightning Bolt" }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal sample_cards, body["cards"]
  end

  test "GET /api/cards/search passes treatments param to service" do
    expected_treatments = [ "foil", "borderless" ]
    received = {}

    fake_service = Object.new
    fake_service.define_singleton_method(:call) { [] }

    CardSearchService.stub(:new, fake_service) do
      # Intercept the constructor call to capture arguments
      original_new = CardSearchService.method(:new)
      CardSearchService.define_singleton_method(:new) do |**kwargs|
        received.merge!(kwargs)
        fake_service
      end

      get api_path("/cards/search"), params: { q: "Lightning Bolt", treatments: expected_treatments }

      # Restore original method
      CardSearchService.define_singleton_method(:new, original_new)
    end

    assert_response :success
    assert_equal "Lightning Bolt", received[:query]
    assert_equal expected_treatments, received[:treatments]
  end

  # ---------------------------------------------------------------------------
  # #index -- validation
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search without q returns 422" do
    get api_path("/cards/search")

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "Search query (q) is required", body["error"]
  end
end
