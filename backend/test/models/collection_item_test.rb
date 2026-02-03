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
  # Scenario 5 & 6: treatment validations
  # ---------------------------------------------------------------------------
  test "is valid with all treatment options" do
    CollectionItem::TREATMENT_OPTIONS.each do |treatment|
      item = CollectionItem.new(
        user: @user,
        card_id: "abc123-#{treatment.parameterize}",
        collection_type: "inventory",
        quantity: 1,
        treatment: treatment
      )
      assert item.valid?, "#{treatment} should be valid but got: #{item.errors.full_messages.inspect}"
    end
  end

  test "is valid with nil treatment" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      treatment: nil
    )
    assert item.valid?, item.errors.full_messages.inspect
  end

  test "is invalid with unrecognized treatment" do
    item = CollectionItem.new(
      user: @user,
      card_id: "abc123",
      collection_type: "inventory",
      quantity: 1,
      treatment: "InvalidTreatment"
    )
    assert item.invalid?
    assert_includes item.errors[:treatment], "is not included in the list"
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
end
