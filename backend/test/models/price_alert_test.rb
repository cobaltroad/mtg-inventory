require "test_helper"

class PriceAlertTest < ActiveSupport::TestCase
  # Test fixtures
  def setup
    @user = User.create!(email: "test@example.com", name: "Test User")
    @card_id = "test-card-uuid-123"
  end

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  test "should be valid with all required attributes" do
    alert = PriceAlert.new(
      user: @user,
      card_id: @card_id,
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0,
      treatment: "normal"
    )
    assert alert.valid?
  end

  test "should require user" do
    alert = PriceAlert.new(
      card_id: @card_id,
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0
    )
    assert_not alert.valid?
    assert_includes alert.errors[:user], "must exist"
  end

  test "should require card_id" do
    alert = PriceAlert.new(
      user: @user,
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0
    )
    assert_not alert.valid?
    assert_includes alert.errors[:card_id], "can't be blank"
  end

  test "should require alert_type" do
    alert = PriceAlert.new(
      user: @user,
      card_id: @card_id,
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0
    )
    assert_not alert.valid?
    assert_includes alert.errors[:alert_type], "can't be blank"
  end

  test "should only allow valid alert types" do
    valid_types = ["price_increase", "price_decrease"]
    valid_types.each do |type|
      alert = PriceAlert.new(
        user: @user,
        card_id: @card_id,
        alert_type: type,
        old_price_cents: 100,
        new_price_cents: 150,
        percentage_change: 50.0
      )
      assert alert.valid?, "#{type} should be valid"
    end

    invalid_alert = PriceAlert.new(
      user: @user,
      card_id: @card_id,
      alert_type: "invalid_type",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0
    )
    assert_not invalid_alert.valid?
    assert_includes invalid_alert.errors[:alert_type], "is not included in the list"
  end

  test "should require old_price_cents" do
    alert = PriceAlert.new(
      user: @user,
      card_id: @card_id,
      alert_type: "price_increase",
      new_price_cents: 150,
      percentage_change: 50.0
    )
    assert_not alert.valid?
    assert_includes alert.errors[:old_price_cents], "can't be blank"
  end

  test "should require new_price_cents" do
    alert = PriceAlert.new(
      user: @user,
      card_id: @card_id,
      alert_type: "price_increase",
      old_price_cents: 100,
      percentage_change: 50.0
    )
    assert_not alert.valid?
    assert_includes alert.errors[:new_price_cents], "can't be blank"
  end

  test "should require percentage_change" do
    alert = PriceAlert.new(
      user: @user,
      card_id: @card_id,
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150
    )
    assert_not alert.valid?
    assert_includes alert.errors[:percentage_change], "can't be blank"
  end

  test "should validate price_cents are non-negative" do
    alert = PriceAlert.new(
      user: @user,
      card_id: @card_id,
      alert_type: "price_increase",
      old_price_cents: -100,
      new_price_cents: 150,
      percentage_change: 50.0
    )
    assert_not alert.valid?
    assert_includes alert.errors[:old_price_cents], "must be greater than or equal to 0"

    alert.old_price_cents = 100
    alert.new_price_cents = -50
    assert_not alert.valid?
    assert_includes alert.errors[:new_price_cents], "must be greater than or equal to 0"
  end

  test "should default dismissed to false" do
    alert = PriceAlert.create!(
      user: @user,
      card_id: @card_id,
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0
    )
    assert_equal false, alert.dismissed
  end

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------

  test "active scope should return non-dismissed alerts" do
    dismissed_alert = PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0,
      dismissed: true
    )

    active_alert = PriceAlert.create!(
      user: @user,
      card_id: "card-2",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0,
      dismissed: false
    )

    active_alerts = PriceAlert.active
    assert_includes active_alerts, active_alert
    assert_not_includes active_alerts, dismissed_alert
  end

  test "for_user scope should return alerts for specific user" do
    other_user = User.create!(email: "other@example.com", name: "Other User")

    user_alert = PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0
    )

    other_alert = PriceAlert.create!(
      user: other_user,
      card_id: "card-2",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0
    )

    user_alerts = PriceAlert.for_user(@user)
    assert_includes user_alerts, user_alert
    assert_not_includes user_alerts, other_alert
  end

  test "recent scope should return alerts ordered by created_at desc" do
    old_alert = PriceAlert.create!(
      user: @user,
      card_id: "card-1",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0,
      created_at: 2.days.ago
    )

    new_alert = PriceAlert.create!(
      user: @user,
      card_id: "card-2",
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0,
      created_at: 1.day.ago
    )

    recent_alerts = PriceAlert.recent
    assert_equal new_alert, recent_alerts.first
    assert_equal old_alert, recent_alerts.second
  end

  # ---------------------------------------------------------------------------
  # Instance Methods
  # ---------------------------------------------------------------------------

  test "dismiss! should mark alert as dismissed" do
    alert = PriceAlert.create!(
      user: @user,
      card_id: @card_id,
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 150,
      percentage_change: 50.0
    )

    assert_equal false, alert.dismissed
    assert_nil alert.dismissed_at

    alert.dismiss!
    alert.reload

    assert_equal true, alert.dismissed
    assert_not_nil alert.dismissed_at
    assert_in_delta Time.current, alert.dismissed_at, 1.second
  end

  test "price_increase? should return true for price increase alerts" do
    alert = PriceAlert.new(alert_type: "price_increase")
    assert alert.price_increase?

    alert.alert_type = "price_decrease"
    assert_not alert.price_increase?
  end

  test "price_decrease? should return true for price decrease alerts" do
    alert = PriceAlert.new(alert_type: "price_decrease")
    assert alert.price_decrease?

    alert.alert_type = "price_increase"
    assert_not alert.price_decrease?
  end
end
