require "test_helper"

class CollectionItemTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Setup -- create a user that every model test can reference.
  # ---------------------------------------------------------------------------
  setup do
    @user = User.create!(email: "model_test@example.com", name: "Model Test User")
  end

  # ---------------------------------------------------------------------------
  # Presence validations
  # ---------------------------------------------------------------------------
  test "is valid with all required attributes" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is invalid without card_id" do
    item = CollectionItem.new(
      user: @user,
      card_id: "",
      collection_type: "inventory",
      quantity: 1
    )
    assert item.invalid?
    assert_includes item.errors[:card_id], "can't be blank"
  end

  test "is invalid without collection_type" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "",
      quantity: 1
    )
    assert item.invalid?
    assert_includes item.errors[:collection_type], "can't be blank"
  end

  test "is invalid without user_id" do
    item = CollectionItem.new(
      user: nil,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1
    )
    assert item.invalid?
    assert_includes item.errors[:user], "must exist"
  end

  test "is invalid without quantity" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: nil
    )
    assert item.invalid?
    assert_includes item.errors[:quantity], "can't be blank"
  end

  # ---------------------------------------------------------------------------
  # Quantity must be a positive integer
  # ---------------------------------------------------------------------------
  test "is invalid when quantity is zero" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 0
    )
    assert item.invalid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end

  test "is invalid when quantity is negative" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: -3
    )
    assert item.invalid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end

  test "is valid when quantity is 1" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # collection_type must be "inventory" or "wishlist"
  # ---------------------------------------------------------------------------
  test "is valid with collection_type inventory" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is valid with collection_type wishlist" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "wishlist",
      quantity: 2
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is invalid with an unrecognized collection_type" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "tradelist",
      quantity: 1
    )
    assert item.invalid?
    assert_includes item.errors[:collection_type], "is not included in the list"
  end

  # ---------------------------------------------------------------------------
  # Unique index on [user_id, card_id, collection_type]
  # ---------------------------------------------------------------------------
  test "does not allow duplicate user_id + card_id + collection_type" do
    CollectionItem.create!(
      user: @user,
      card_id: "unique_card",
      collection_type: "inventory",
      quantity: 1
    )

    duplicate = CollectionItem.new(
      user: @user,
      card_id: "unique_card",
      collection_type: "inventory",
      quantity: 1
    )
    assert duplicate.invalid?
    assert_includes duplicate.errors[:card_id], "has already been taken"
  end

  test "allows same card_id with different collection_type for same user" do
    CollectionItem.create!(
      user: @user,
      card_id: "multi_card",
      collection_type: "inventory",
      quantity: 1
    )

    wishlist_item = CollectionItem.new(
      user: @user,
      card_id: "multi_card",
      collection_type: "wishlist",
      quantity: 1
    )
    assert wishlist_item.valid?, wishlist_item.errors.full_messages.inspect
  end

  test "allows same card_id and collection_type for different users" do
    other_user = User.create!(email: "other_model@example.com", name: "Other User")

    CollectionItem.create!(
      user: @user,
      card_id: "shared_card",
      collection_type: "inventory",
      quantity: 1
    )

    other_item = CollectionItem.new(
      user: other_user,
      card_id: "shared_card",
      collection_type: "inventory",
      quantity: 1
    )
    assert other_item.valid?, other_item.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # Scenario 1 & 2: acquired_price_cents validations
  # ---------------------------------------------------------------------------
  test "is valid with acquired_price_cents of zero" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_price_cents: 0
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is valid with positive acquired_price_cents" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_price_cents: 99999
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is valid with nil acquired_price_cents" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_price_cents: nil
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is invalid with negative acquired_price_cents" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_price_cents: -1
    )
    assert item.invalid?
    assert_includes item.errors[:acquired_price_cents], "must be greater than or equal to 0"
  end

  test "is invalid with non-integer acquired_price_cents" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_price_cents: 99.99
    )
    assert item.invalid?
    assert_includes item.errors[:acquired_price_cents], "must be an integer"
  end

  # ---------------------------------------------------------------------------
  # Scenario 3 & 4: acquired_date validations
  # ---------------------------------------------------------------------------
  test "is valid with acquired_date of today" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_date: Date.today
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is valid with acquired_date in the past" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_date: 1.year.ago.to_date
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is valid with nil acquired_date" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_date: nil
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is invalid with acquired_date in the future" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      acquired_date: 1.day.from_now.to_date
    )
    assert item.invalid?
    assert_includes item.errors[:acquired_date], "cannot be in the future"
  end

  # ---------------------------------------------------------------------------
  # Scenario 5 & 6: finish validations (updated from treatment)
  # ---------------------------------------------------------------------------
  test "is valid with all finish options" do
    CollectionItem::FINISH_TYPES.each do |finish|
      item = CollectionItem.new(
        user: @user,
        card_id: "abc123-#{finish.parameterize}",
        collection_type: "inventory",
        quantity: 1,
        finish: finish
      )
      assert item.valid?, "#{finish} should be valid but got: #{item.errors.full_messages.inspect}"
    end
  end

  test "is valid with nil finish" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      finish: nil
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is invalid with unrecognized finish" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      finish: "InvalidFinish"
    )
    assert item.invalid?
    assert_includes item.errors[:finish], "is not included in the list"
  end

  test "is invalid with old treatment values" do
    # Old values like "Normal", "Foil" (capitalized), "Showcase" should be rejected
    old_values = ["Normal", "Foil", "Etched", "Showcase", "Extended Art"]
    old_values.each do |value|
      item = CollectionItem.new(
        user: @user,
        card_id: "abc123-#{value.parameterize}",
        collection_type: "inventory",
        quantity: 1,
        finish: value
      )
      assert item.invalid?, "#{value} should be invalid (old treatment value)"
      assert_includes item.errors[:finish], "is not included in the list"
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 7 & 8: language validations
  # ---------------------------------------------------------------------------
  test "is valid with all language options" do
    CollectionItem::LANGUAGE_OPTIONS.each do |language|
      item = CollectionItem.new(
        user: @user,
        card_id: "abc123-#{language.parameterize}",
        collection_type: "inventory",
        quantity: 1,
        language: language
      )
      assert item.valid?, "#{language} should be valid but got: #{item.errors.full_messages.inspect}"
    end
  end

  test "is valid with nil language" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      language: nil
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is invalid with unrecognized language" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      language: "InvalidLanguage"
    )
    assert item.invalid?
    assert_includes item.errors[:language], "is not included in the list"
  end

  # ---------------------------------------------------------------------------
  # Price enrichment methods
  # ---------------------------------------------------------------------------
  test "latest_price returns the most recent CardPrice for the card" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "price_test_card",
      collection_type: "inventory",
      quantity: 1
    )

    # Create older price
    old_price = CardPrice.create!(
      card_id: "price_test_card",
      fetched_at: 2.days.ago,
      usd_cents: 100
    )

    # Create newer price
    new_price = CardPrice.create!(
      card_id: "price_test_card",
      fetched_at: 1.day.ago,
      usd_cents: 150
    )

    assert_equal new_price.id, item.latest_price.id
  end

  test "latest_price returns nil when no prices exist" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "no_price_card",
      collection_type: "inventory",
      quantity: 1
    )

    assert_nil item.latest_price
  end

  test "unit_price_cents returns usd_cents for nonfoil finish" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "nonfoil_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil"
    )

    CardPrice.create!(
      card_id: "nonfoil_card",
      fetched_at: 1.day.ago,
      usd_cents: 200,
      usd_foil_cents: 500
    )

    assert_equal 200, item.unit_price_cents
  end

  test "unit_price_cents returns usd_cents for nil finish" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "nil_finish_card",
      collection_type: "inventory",
      quantity: 1,
      finish: nil
    )

    CardPrice.create!(
      card_id: "nil_finish_card",
      fetched_at: 1.day.ago,
      usd_cents: 300,
      usd_foil_cents: 600
    )

    assert_equal 300, item.unit_price_cents
  end

  test "unit_price_cents returns usd_foil_cents for foil finish" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "foil_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    CardPrice.create!(
      card_id: "foil_card",
      fetched_at: 1.day.ago,
      usd_cents: 200,
      usd_foil_cents: 500
    )

    assert_equal 500, item.unit_price_cents
  end

  test "unit_price_cents falls back to usd_cents when foil price is nil" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "foil_fallback_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    CardPrice.create!(
      card_id: "foil_fallback_card",
      fetched_at: 1.day.ago,
      usd_cents: 200,
      usd_foil_cents: nil
    )

    assert_equal 200, item.unit_price_cents
  end

  test "unit_price_cents returns usd_etched_cents for etched finish" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "etched_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "etched"
    )

    CardPrice.create!(
      card_id: "etched_card",
      fetched_at: 1.day.ago,
      usd_cents: 200,
      usd_etched_cents: 400
    )

    assert_equal 400, item.unit_price_cents
  end

  test "unit_price_cents falls back to usd_cents when etched price is nil" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "etched_fallback_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "etched"
    )

    CardPrice.create!(
      card_id: "etched_fallback_card",
      fetched_at: 1.day.ago,
      usd_cents: 200,
      usd_etched_cents: nil
    )

    assert_equal 200, item.unit_price_cents
  end

  test "unit_price_cents returns nil when no price data exists" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "no_price_data_card",
      collection_type: "inventory",
      quantity: 1
    )

    assert_nil item.unit_price_cents
  end

  test "unit_price_cents returns nil when price exists but all price fields are nil" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "all_nil_prices_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    CardPrice.create!(
      card_id: "all_nil_prices_card",
      fetched_at: 1.day.ago,
      usd_cents: nil,
      usd_foil_cents: nil,
      usd_etched_cents: nil
    )

    assert_nil item.unit_price_cents
  end

  test "total_price_cents returns unit price multiplied by quantity" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "total_price_card",
      collection_type: "inventory",
      quantity: 4,
      finish: "nonfoil"
    )

    CardPrice.create!(
      card_id: "total_price_card",
      fetched_at: 1.day.ago,
      usd_cents: 250
    )

    assert_equal 1000, item.total_price_cents
  end

  test "total_price_cents returns nil when unit price is nil" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "no_total_price_card",
      collection_type: "inventory",
      quantity: 3
    )

    assert_nil item.total_price_cents
  end

  test "total_price_cents handles quantity of 1" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "single_card",
      collection_type: "inventory",
      quantity: 1
    )

    CardPrice.create!(
      card_id: "single_card",
      fetched_at: 1.day.ago,
      usd_cents: 350
    )

    assert_equal 350, item.total_price_cents
  end
end
