require "test_helper"

class PriceAlertsControllerTest < ActionDispatch::IntegrationTest
  def setup
    CollectionItem.delete_all
    PriceAlert.delete_all
    User.delete_all
    # Create the default user that current_user will resolve to
    @user = User.create!(email: User::DEFAULT_EMAIL, name: "Default User")
  end

  # ---------------------------------------------------------------------------
  # GET /api/price_alerts
  # ---------------------------------------------------------------------------

  test "index returns active price alerts for user" do
    # Create some alerts
    alert1 = PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0,
      treatment: "normal",
      created_at: 1.hour.ago
    )

    alert2 = PriceAlert.create!(
      user: @user,
      card_id: "card-2",
      alert_type: "price_decrease",
      old_price_cents: 200,
      new_price_cents: 140,
      percentage_change: -30.0,
      treatment: "foil",
      created_at: 2.hours.ago
    )

    # Create dismissed alert (should not appear)
    PriceAlert.create!(
      user: @user,
      card_id: "card-3",
      alert_type: "price_increase",
      old_price_cents: 50,
      new_price_cents: 75,
      percentage_change: 50.0,
      dismissed: true
    )

    get "/projects/mtg/api/price_alerts"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.length
    assert_equal "card-1", json[0]["card_id"]
    assert_equal "price_increase", json[0]["alert_type"]
    assert_equal 100, json[0]["old_price_cents"]
    assert_equal 130, json[0]["new_price_cents"]
    assert_equal "30.0", json[0]["percentage_change"]
    assert_equal "normal", json[0]["treatment"]
    assert json[0].key?("created_at")
  end

  test "index returns empty array when no active alerts exist" do
    get "/projects/mtg/api/price_alerts"

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

    get "/projects/mtg/api/price_alerts"

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

    get "/projects/mtg/api/price_alerts"

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

    get "/projects/mtg/api/price_alerts"

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 10, json.length
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/price_alerts/:id/dismiss
  # ---------------------------------------------------------------------------

  test "dismiss marks alert as dismissed" do
    alert = PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0
    )

    patch "/projects/mtg/api/price_alerts/#{alert.id}/dismiss"

    assert_response :success
    alert.reload
    assert alert.dismissed
    assert_not_nil alert.dismissed_at
  end

  test "dismiss returns 404 for non-existent alert" do
    patch "/projects/mtg/api/price_alerts/99999/dismiss"

    assert_response :not_found
  end

  test "dismiss returns 403 when alert belongs to different user" do
    other_user = User.create!(email: "other@example.com", name: "Other User")

    alert = PriceAlert.create!(
      user: other_user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0
    )

    patch "/projects/mtg/api/price_alerts/#{alert.id}/dismiss"

    assert_response :forbidden
    alert.reload
    assert_not alert.dismissed
  end
end
