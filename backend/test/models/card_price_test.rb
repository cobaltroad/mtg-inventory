require "test_helper"

class CardPriceTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # RED Phase: Test CardPrice model validations and behavior
  # ---------------------------------------------------------------------------

  test "valid card price with all fields" do
    card_price = CardPrice.new(
      card_id: "test-uuid-123",
      usd_cents: 1050,
      usd_foil_cents: 2500,
      usd_etched_cents: 3000,
      fetched_at: Time.current
    )

    assert card_price.valid?
  end

  test "valid card price with only required fields" do
    card_price = CardPrice.new(
      card_id: "test-uuid-456",
      fetched_at: Time.current
    )

    assert card_price.valid?
  end

  test "invalid without card_id" do
    card_price = CardPrice.new(
      usd_cents: 1050,
      fetched_at: Time.current
    )

    refute card_price.valid?
    assert_includes card_price.errors[:card_id], "can't be blank"
  end

  test "invalid without fetched_at" do
    card_price = CardPrice.new(
      card_id: "test-uuid-789",
      usd_cents: 1050
    )

    refute card_price.valid?
    assert_includes card_price.errors[:fetched_at], "can't be blank"
  end

  test "usd_cents must be numeric if present" do
    card_price = CardPrice.new(
      card_id: "test-uuid-numeric",
      usd_cents: "not a number",
      fetched_at: Time.current
    )

    refute card_price.valid?
    assert_includes card_price.errors[:usd_cents], "is not a number"
  end

  test "usd_foil_cents must be numeric if present" do
    card_price = CardPrice.new(
      card_id: "test-uuid-numeric-foil",
      usd_foil_cents: "not a number",
      fetched_at: Time.current
    )

    refute card_price.valid?
    assert_includes card_price.errors[:usd_foil_cents], "is not a number"
  end

  test "usd_etched_cents must be numeric if present" do
    card_price = CardPrice.new(
      card_id: "test-uuid-numeric-etched",
      usd_etched_cents: "not a number",
      fetched_at: Time.current
    )

    refute card_price.valid?
    assert_includes card_price.errors[:usd_etched_cents], "is not a number"
  end

  test "price fields must be integers" do
    card_price = CardPrice.new(
      card_id: "test-uuid-integer",
      usd_cents: 10.5,
      fetched_at: Time.current
    )

    refute card_price.valid?
    assert_includes card_price.errors[:usd_cents], "must be an integer"
  end

  test "price fields can be nil" do
    card_price = CardPrice.new(
      card_id: "test-uuid-nil-prices",
      usd_cents: nil,
      usd_foil_cents: nil,
      usd_etched_cents: nil,
      fetched_at: Time.current
    )

    assert card_price.valid?
  end

  test "price fields must be greater than or equal to zero" do
    card_price = CardPrice.new(
      card_id: "test-uuid-negative",
      usd_cents: -100,
      fetched_at: Time.current
    )

    refute card_price.valid?
    assert_includes card_price.errors[:usd_cents], "must be greater than or equal to 0"
  end

  test "can save multiple prices for same card_id" do
    card_id = "test-uuid-multiple"

    price1 = CardPrice.create!(
      card_id: card_id,
      usd_cents: 1000,
      fetched_at: 2.days.ago
    )

    price2 = CardPrice.create!(
      card_id: card_id,
      usd_cents: 1200,
      fetched_at: 1.day.ago
    )

    assert_equal 2, CardPrice.where(card_id: card_id).count
  end

  # ---------------------------------------------------------------------------
  # Test scope/method to get latest price for a card
  # ---------------------------------------------------------------------------

  test "latest_for returns most recent price for a card" do
    card_id = "test-uuid-latest"

    old_price = CardPrice.create!(
      card_id: card_id,
      usd_cents: 1000,
      fetched_at: 3.days.ago
    )

    middle_price = CardPrice.create!(
      card_id: card_id,
      usd_cents: 1200,
      fetched_at: 2.days.ago
    )

    latest_price = CardPrice.create!(
      card_id: card_id,
      usd_cents: 1500,
      fetched_at: 1.day.ago
    )

    result = CardPrice.latest_for(card_id)

    assert_equal latest_price.id, result.id
    assert_equal 1500, result.usd_cents
  end

  test "latest_for returns nil when no prices exist for card" do
    result = CardPrice.latest_for("nonexistent-card")

    assert_nil result
  end

  test "latest_for ignores prices for other cards" do
    card_id_a = "test-uuid-a"
    card_id_b = "test-uuid-b"

    CardPrice.create!(
      card_id: card_id_a,
      usd_cents: 1000,
      fetched_at: 1.day.ago
    )

    price_b = CardPrice.create!(
      card_id: card_id_b,
      usd_cents: 2000,
      fetched_at: 1.hour.ago
    )

    result = CardPrice.latest_for(card_id_b)

    assert_equal price_b.id, result.id
    assert_equal 2000, result.usd_cents
  end

  # ---------------------------------------------------------------------------
  # Test database constraints
  # ---------------------------------------------------------------------------

  test "created_at is automatically set" do
    card_price = CardPrice.create!(
      card_id: "test-uuid-timestamps",
      fetched_at: Time.current
    )

    assert_not_nil card_price.created_at
  end

  test "stores timestamps with precision" do
    specific_time = Time.zone.parse("2024-01-15 14:30:45")

    card_price = CardPrice.create!(
      card_id: "test-uuid-precision",
      fetched_at: specific_time
    )

    card_price.reload
    assert_equal specific_time.to_i, card_price.fetched_at.to_i
  end
end
