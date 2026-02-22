require "test_helper"
require "webmock/minitest"

class CollectionItemDenormalizedFieldsTest < ActiveSupport::TestCase
  def setup
    User.delete_all
    CollectionItem.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
    WebMock.reset!

    # Use memory cache for testing
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  def teardown
    Rails.cache = @original_cache
  end

  def stub_scryfall_card_details(card_id, name: "Test Card", set: "TST", set_name: "Test Set", released_at: "2024-01-01")
    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/#{card_id}/)
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: set,
          set_name: set_name,
          collector_number: "1",
          released_at: released_at,
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/t/e/test.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ---------------------------------------------------------------------------
  # Test: Denormalized fields populated on create
  # ---------------------------------------------------------------------------

  test "populates denormalized fields from Scryfall on create" do
    card_id = "new_card_123"
    stub_scryfall_card_details(
      card_id,
      name: "Black Lotus",
      set: "LEA",
      set_name: "Limited Edition Alpha",
      released_at: "1993-08-05"
    )

    item = CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    assert_equal "Black Lotus", item.card_name
    assert_equal "Limited Edition Alpha", item.set_name
    assert_equal Date.parse("1993-08-05"), item.released_at
  end

  test "updates denormalized fields when card_id changes" do
    # Create with first card
    first_card = "first_card_456"
    stub_scryfall_card_details(
      first_card,
      name: "Original Card",
      set: "TST",
      set_name: "Test Set",
      released_at: "2020-01-01"
    )

    item = CollectionItem.create!(
      user: @user,
      card_id: first_card,
      collection_type: "inventory",
      quantity: 1
    )

    assert_equal "Original Card", item.card_name

    # Update to second card
    second_card = "second_card_789"
    stub_scryfall_card_details(
      second_card,
      name: "Updated Card",
      set: "NEW",
      set_name: "New Set",
      released_at: "2024-06-15"
    )

    item.update!(card_id: second_card)

    assert_equal "Updated Card", item.card_name
    assert_equal "New Set", item.set_name
    assert_equal Date.parse("2024-06-15"), item.released_at
  end

  test "does not refetch when updating quantity only" do
    card_id = "quantity_test_card"
    stub_scryfall_card_details(card_id, name: "Quantity Test Card")

    item = CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    # Clear any stubs - if we try to fetch again, it will fail
    WebMock.reset!

    # Update quantity - should not fetch from Scryfall
    assert_nothing_raised do
      item.update!(quantity: 5)
    end

    assert_equal 5, item.quantity
    assert_equal "Quantity Test Card", item.card_name  # Should still be set
  end

  # ---------------------------------------------------------------------------
  # Test: Graceful error handling
  # ---------------------------------------------------------------------------

  test "handles Scryfall API errors gracefully during create" do
    card_id = "error_card_999"
    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/#{card_id}/)
      .to_return(status: 500, body: "Internal Server Error")

    # Should still create the item even if denormalization fails
    item = CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    assert item.persisted?
    assert_nil item.card_name
    assert_nil item.set_name
    assert_nil item.released_at
  end

  test "handles network timeout during denormalization" do
    card_id = "timeout_card_000"
    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/#{card_id}/)
      .to_timeout

    # Should still create the item
    item = CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    assert item.persisted?
    assert_nil item.card_name
  end

  # ---------------------------------------------------------------------------
  # Test: Backward compatibility
  # ---------------------------------------------------------------------------

  test "does not require denormalized fields to be present" do
    # Manually create item bypassing callbacks (simulating existing data)
    item = CollectionItem.new(
      user: @user,
      card_id: "backward_compat_card",
      collection_type: "inventory",
      quantity: 1
    )

    # Should be valid without denormalized fields
    assert item.valid?
  end

  test "allows manual setting of denormalized fields" do
    # Stub needed even though we provide metadata, because sync runs before values are assigned
    stub_scryfall_card_details("manual_card_123", name: "API Card")

    item = CollectionItem.create!(
      user: @user,
      card_id: "manual_card_123",
      collection_type: "inventory",
      quantity: 1,
      card_name: "Manually Set Name",
      set_name: "Manually Set Set",
      released_at: Date.parse("2025-01-01")
    )

    assert_equal "Manually Set Name", item.card_name
    assert_equal "Manually Set Set", item.set_name
    assert_equal Date.parse("2025-01-01"), item.released_at
  end

  # ---------------------------------------------------------------------------
  # Test: Performance - uses cache
  # ---------------------------------------------------------------------------

  test "uses cached card details to avoid redundant API calls" do
    card_id = "cached_card_555"
    stub_scryfall_card_details(card_id, name: "Cached Card")

    # First creation should hit API
    item1 = CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    assert_equal "Cached Card", item1.card_name

    # Remove stub - if cache works, no API call needed
    WebMock.reset!

    # Second creation with same card_id should use cache
    other_user = User.create!(email: "other@example.com", name: "Other User")
    item2 = CollectionItem.create!(
      user: other_user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    assert_equal "Cached Card", item2.card_name
  end
end
