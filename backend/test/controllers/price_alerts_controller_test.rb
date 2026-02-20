require "test_helper"
require "webmock/minitest"

class PriceAlertsControllerTest < ActionDispatch::IntegrationTest
  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  def setup
    CollectionItem.delete_all
    PriceAlert.delete_all
    User.delete_all
    # Create the default user that current_user will resolve to
    @user = User.create!(email: User::DEFAULT_EMAIL, name: "Default User")
    WebMock.reset!

    # Use memory store for cache testing instead of null store
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def teardown
    # Restore original cache
    Rails.cache = @original_cache
  end

  # Stubs Scryfall API to return card details
  def stub_scryfall_card_details(card_id, name: "Test Card")
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: "TST",
          set_name: "Test Set",
          collector_number: "1",
          image_uris: {
            normal: "https://example.com/image.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ---------------------------------------------------------------------------
  # GET /api/price_alerts
  # ---------------------------------------------------------------------------

  test "index returns active price alerts for user" do
    # Stub Scryfall API for card details
    stub_scryfall_card_details("card-1", name: "Lightning Bolt")
    stub_scryfall_card_details("card-2", name: "Counterspell")

    # Create some alerts
    alert1 = PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0,
      finish: "nonfoil",
      created_at: 1.hour.ago
    )

    alert2 = PriceAlert.create!(
      user: @user,
      card_id: "card-2",
      alert_type: "price_decrease",
      old_price_cents: 200,
      new_price_cents: 140,
      percentage_change: -30.0,
      finish: "foil",
      created_at: 2.hours.ago
    )

    get api_path("/price_alerts")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.length
    assert_equal "card-1", json[0]["card_id"]
    assert_equal "Lightning Bolt", json[0]["card_name"]
    assert_equal "price_increase", json[0]["alert_type"]
    assert_equal 100, json[0]["old_price_cents"]
    assert_equal 130, json[0]["new_price_cents"]
    assert_equal "30.0", json[0]["percentage_change"]
    assert_equal "nonfoil", json[0]["finish"]
    assert json[0].key?("created_at")
  end

  test "index returns empty array when no active alerts exist" do
    get api_path("/price_alerts")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 0, json.length
  end

  test "index only returns alerts for specified user" do
    other_user = User.create!(email: "other@example.com", name: "Other User")

    PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0
    )

    PriceAlert.create!(
      user: other_user,
      card_id: "card-2",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0
    )

    get api_path("/price_alerts")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal "card-1", json[0]["card_id"]
  end

  test "index returns alerts ordered by created_at desc (most recent first)" do
    old_alert = PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0,
      created_at: 3.hours.ago
    )

    new_alert = PriceAlert.create!(
      user: @user,
      card_id: "card-2",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0,
      created_at: 1.hour.ago
    )

    get api_path("/price_alerts")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "card-2", json[0]["card_id"]
    assert_equal "card-1", json[1]["card_id"]
  end

  test "index limits results to top 10 alerts" do
    # Create 15 alerts
    15.times do |i|
      PriceAlert.create!(
        user: @user,
        card_id: "card-#{i}",
        alert_type: "price_increase",
        old_price_cents: 100,
        new_price_cents: 130,
        percentage_change: 30.0 + i,
        created_at: i.hours.ago
      )
    end

    get api_path("/price_alerts")

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 10, json.length
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/price_alerts/:id/dismiss
  # ---------------------------------------------------------------------------

  test "dismiss marks alert as dismissed" do
    stub_scryfall_card_details("card-1", name: "Test Card")

    alert = PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0
    )

    alert_id = alert.id

    patch api_path("/price_alerts/#{alert_id}/dismiss")

    assert_response :success

    # Alert should be permanently deleted
    assert_nil PriceAlert.find_by(id: alert_id)
  end

  test "dismiss returns 404 for non-existent alert" do
    patch api_path("/price_alerts/99999/dismiss")

    assert_response :not_found
  end

  test "dismiss returns 403 when alert belongs to different user" do
    stub_scryfall_card_details("card-1", name: "Test Card")
    other_user = User.create!(email: "other@example.com", name: "Other User")

    alert = PriceAlert.create!(
      user: other_user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0
    )

    patch api_path("/price_alerts/#{alert.id}/dismiss")

    assert_response :forbidden

    # Alert should still exist (not deleted due to permission error)
    alert.reload
    assert_not_nil alert
  end
end
