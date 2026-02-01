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
end
