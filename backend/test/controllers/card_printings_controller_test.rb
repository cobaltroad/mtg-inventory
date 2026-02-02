require "test_helper"

class CardPrintingsControllerTest < ActionDispatch::IntegrationTest
  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  # ---------------------------------------------------------------------------
  # #show -- returns all printings for a specific card
  # ---------------------------------------------------------------------------
  test "GET /api/cards/:id/printings returns 200 and printings array" do
    card_id = "f3c42c51-2e0f-4c5e-b1b1-6e3e6e5e3e5e"
    sample_printings = [
      {
        "id" => "f3c42c51-2e0f-4c5e-b1b1-6e3e6e5e3e5e",
        "name" => "Lightning Bolt",
        "set" => "lea",
        "set_name" => "Limited Edition Alpha",
        "collector_number" => "157",
        "image_url" => "https://example.com/bolt-alpha.jpg",
        "released_at" => "1993-08-05"
      },
      {
        "id" => "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6",
        "name" => "Lightning Bolt",
        "set" => "m10",
        "set_name" => "Magic 2010",
        "collector_number" => "146",
        "image_url" => "https://example.com/bolt-m10.jpg",
        "released_at" => "2009-07-17"
      }
    ]

    CardPrintingsService.stub(:new, Object.new.tap { |svc|
      svc.define_singleton_method(:call) { sample_printings }
    }) do
      get api_path("/cards/#{card_id}/printings")
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal sample_printings, body["printings"]
  end

  test "GET /api/cards/:id/printings passes card_id to service" do
    card_id = "f3c42c51-2e0f-4c5e-b1b1-6e3e6e5e3e5e"
    received_card_id = nil

    fake_service = Object.new
    fake_service.define_singleton_method(:call) { [] }

    CardPrintingsService.stub(:new, fake_service) do
      # Intercept the constructor call to capture arguments
      original_new = CardPrintingsService.method(:new)
      CardPrintingsService.define_singleton_method(:new) do |**kwargs|
        received_card_id = kwargs[:card_id]
        fake_service
      end

      get api_path("/cards/#{card_id}/printings")

      # Restore original method
      CardPrintingsService.define_singleton_method(:new, original_new)
    end

    assert_response :success
    assert_equal card_id, received_card_id
  end

  test "GET /api/cards/:id/printings returns empty array when no printings found" do
    card_id = "nonexistent-card-id"

    CardPrintingsService.stub(:new, Object.new.tap { |svc|
      svc.define_singleton_method(:call) { [] }
    }) do
      get api_path("/cards/#{card_id}/printings")
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body["printings"]
  end

  test "GET /api/cards/:id/printings handles service errors gracefully" do
    card_id = "error-card-id"

    CardPrintingsService.stub(:new, Object.new.tap { |svc|
      svc.define_singleton_method(:call) { raise StandardError, "API error" }
    }) do
      get api_path("/cards/#{card_id}/printings")
    end

    assert_response :internal_server_error
    body = JSON.parse(response.body)
    assert_includes body["error"], "Unable to fetch printings"
  end
end
