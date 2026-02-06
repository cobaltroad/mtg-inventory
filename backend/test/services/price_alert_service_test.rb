require "test_helper"

class PriceAlertServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", name: "Test User")
    @card_id = "test-card-123"
    @service = PriceAlertService.new
  end

  # ---------------------------------------------------------------------------
  # Price Change Detection - Increases
  # ---------------------------------------------------------------------------

  test "detects 20% price increase for normal cards" do
    # Create old price (1 day ago)
    old_price = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    # Create new price (now)
    new_price = CardPrice.create!(
      card_id: @card_id,
      usd_cents: 120,  # 20% increase
      fetched_at: Time.current
    )

    # Create inventory item for user
    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    # Run detection
    alerts = @service.detect_price_changes

    assert_equal 1, alerts.count
    alert = alerts.first
    assert_equal @user, alert.user
    assert_equal @card_id, alert.card_id
    assert_equal "price_increase", alert.alert_type
    assert_equal 100, alert.old_price_cents
    assert_equal 120, alert.new_price_cents
    assert_equal 20.0, alert.percentage_change.to_f
    assert_equal "normal", alert.treatment
  end

  test "does not create alert for increase below 20% threshold" do
    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 115,  # Only 15% increase
      fetched_at: Time.current
    )

    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1
    )

    alerts = @service.detect_price_changes

    assert_equal 0, alerts.count
  end

  # ---------------------------------------------------------------------------
  # Price Change Detection - Decreases
  # ---------------------------------------------------------------------------

  test "detects 30% price decrease for normal cards" do
    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 70,  # 30% decrease
      fetched_at: Time.current
    )

    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1
    )

    alerts = @service.detect_price_changes

    assert_equal 1, alerts.count
    alert = alerts.first
    assert_equal "price_decrease", alert.alert_type
    assert_equal 100, alert.old_price_cents
    assert_equal 70, alert.new_price_cents
    assert_equal(-30.0, alert.percentage_change.to_f)
  end

  test "does not create alert for decrease below 30% threshold" do
    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 75,  # Only 25% decrease
      fetched_at: Time.current
    )

    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1
    )

    alerts = @service.detect_price_changes

    assert_equal 0, alerts.count
  end

  # ---------------------------------------------------------------------------
  # Treatment-Specific Price Changes
  # ---------------------------------------------------------------------------

  test "detects price changes for foil cards" do
    CardPrice.create!(
      card_id: @card_id,
      usd_foil_cents: 200,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_foil_cents: 250,  # 25% increase
      fetched_at: Time.current
    )

    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Foil"
    )

    alerts = @service.detect_price_changes

    assert_equal 1, alerts.count
    alert = alerts.first
    assert_equal "foil", alert.treatment
    assert_equal 200, alert.old_price_cents
    assert_equal 250, alert.new_price_cents
  end

  test "detects price changes for etched cards" do
    CardPrice.create!(
      card_id: @card_id,
      usd_etched_cents: 300,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_etched_cents: 375,  # 25% increase
      fetched_at: Time.current
    )

    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1,
      treatment: "Etched"
    )

    alerts = @service.detect_price_changes

    assert_equal 1, alerts.count
    alert = alerts.first
    assert_equal "etched", alert.treatment
  end

  # ---------------------------------------------------------------------------
  # Multiple Users and Cards
  # ---------------------------------------------------------------------------

  test "creates separate alerts for different users with same card" do
    user2 = User.create!(email: "user2@example.com", name: "User Two")

    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 130,  # 30% increase
      fetched_at: Time.current
    )

    CollectionItem.create!(user: @user, card_id: @card_id, collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: user2, card_id: @card_id, collection_type: "inventory", quantity: 1)

    alerts = @service.detect_price_changes

    assert_equal 2, alerts.count
    assert_includes alerts.map(&:user), @user
    assert_includes alerts.map(&:user), user2
  end

  test "only creates alerts for inventory items, not wishlist items" do
    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 130,  # 30% increase
      fetched_at: Time.current
    )

    # Create wishlist item (should not generate alert)
    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "wishlist",
      quantity: 1
    )

    alerts = @service.detect_price_changes

    assert_equal 0, alerts.count
  end

  # ---------------------------------------------------------------------------
  # Edge Cases
  # ---------------------------------------------------------------------------

  test "does not create alert when no previous price exists" do
    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: Time.current
    )

    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1
    )

    alerts = @service.detect_price_changes

    assert_equal 0, alerts.count
  end

  test "does not create alert when price is nil" do
    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_cents: nil,
      fetched_at: Time.current
    )

    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1
    )

    alerts = @service.detect_price_changes

    assert_equal 0, alerts.count
  end

  test "does not create duplicate alerts for same card within 24 hours" do
    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    CardPrice.create!(
      card_id: @card_id,
      usd_cents: 130,
      fetched_at: Time.current
    )

    CollectionItem.create!(
      user: @user,
      card_id: @card_id,
      collection_type: "inventory",
      quantity: 1
    )

    # Create existing alert from 1 hour ago
    PriceAlert.create!(
      user: @user,
      card_id: @card_id,
      alert_type: "price_increase",
      old_price_cents: 100,
      new_price_cents: 130,
      percentage_change: 30.0,
      created_at: 1.hour.ago
    )

    alerts = @service.detect_price_changes

    assert_equal 0, alerts.count
  end
end
