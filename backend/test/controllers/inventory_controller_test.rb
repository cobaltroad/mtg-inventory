require "test_helper"
require "webmock/minitest"

class InventoryControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Setup -- ensure the seeded default user exists; all requests will be
  # scoped to that user via ApplicationController#current_user.
  # ---------------------------------------------------------------------------
  setup do
    CollectionItem.delete_all
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
    WebMock.reset!

    # Use memory store for cache testing instead of null store
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    # Restore original cache
    Rails.cache = @original_cache
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  # Stubs Scryfall API to validate a card ID
  def stub_valid_card(card_id)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: { id: card_id, name: "Test Card" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stubs Scryfall API to return 404 for invalid card
  def stub_invalid_card(card_id)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 404, body: '{"object":"error","code":"not_found"}')
  end

  # Stubs Scryfall API to return card details
  def stub_scryfall_card_details(card_id, name: "Black Lotus")
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: "LEA",
          set_name: "Limited Edition Alpha",
          collector_number: "234",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ---------------------------------------------------------------------------
  # #index -- returns only current_user's inventory items
  # ---------------------------------------------------------------------------
  test "GET /api/inventory returns only current user's inventory items" do
    CollectionItem.create!(user: @user, card_id: "my_card", collection_type: "inventory", quantity: 2)

    other_user = User.create!(email: "other@example.com", name: "Other")
    CollectionItem.create!(user: other_user, card_id: "their_card", collection_type: "inventory", quantity: 1)

    stub_scryfall_card_details("my_card", name: "My Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size
    assert_equal "my_card", items.first["card_id"]
  end

  test "GET /api/inventory does not return wishlist items" do
    CollectionItem.create!(user: @user, card_id: "inv_card", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "wish_card", collection_type: "wishlist", quantity: 1)

    stub_scryfall_card_details("inv_card", name: "Inventory Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size
    assert_equal "inv_card", items.first["card_id"]
  end

  # ---------------------------------------------------------------------------
  # #index with card details -- returns enriched inventory with Scryfall data
  # ---------------------------------------------------------------------------
  test "GET /api/inventory includes card details from Scryfall API" do
    CollectionItem.create!(user: @user, card_id: "uuid-123", collection_type: "inventory", quantity: 3)

    stub_scryfall_card_details("uuid-123")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    item = items.first
    assert_equal "uuid-123", item["card_id"]
    assert_equal 3, item["quantity"]
    assert_equal "Black Lotus", item["card_name"]
    assert_equal "LEA", item["set"]
    assert_equal "Limited Edition Alpha", item["set_name"]
    assert_equal "234", item["collector_number"]
    assert_equal "https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg", item["image_url"]
  end

  test "GET /api/inventory returns items sorted alphabetically by card name" do
    CollectionItem.create!(user: @user, card_id: "uuid-zzz", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-aaa", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-mmm", collection_type: "inventory", quantity: 1)

    stub_scryfall_card_details("uuid-zzz", name: "Zombie Token")
    stub_scryfall_card_details("uuid-aaa", name: "Ancient Tomb")
    stub_scryfall_card_details("uuid-mmm", name: "Mox Pearl")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 3, items.size

    # Verify alphabetical order
    assert_equal "Ancient Tomb", items[0]["card_name"]
    assert_equal "Mox Pearl", items[1]["card_name"]
    assert_equal "Zombie Token", items[2]["card_name"]
  end

  test "GET /api/inventory handles cards with missing Scryfall data gracefully" do
    CollectionItem.create!(user: @user, card_id: "uuid-valid", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-missing", collection_type: "inventory", quantity: 2)

    stub_scryfall_card_details("uuid-valid")
    stub_request(:get, "https://api.scryfall.com/cards/uuid-missing")
      .to_return(status: 404, body: '{"object":"error","code":"not_found"}')

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)

    # Should only return items with valid card data
    assert_equal 1, items.size
    assert_equal "uuid-valid", items.first["card_id"]
    assert_equal "Black Lotus", items.first["card_name"]
  end

  test "GET /api/inventory includes enhanced tracking fields when present" do
    CollectionItem.create!(
      user: @user,
      card_id: "uuid-enhanced",
      collection_type: "inventory",
      quantity: 2,
      acquired_date: Date.parse("2025-12-15"),
      acquired_price_cents: 1250,
      treatment: "Foil",
      language: "Japanese"
    )

    stub_scryfall_card_details("uuid-enhanced")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    item = items.first
    assert_equal "uuid-enhanced", item["card_id"]
    assert_equal 2, item["quantity"]
    assert_equal "2025-12-15", item["acquired_date"]
    assert_equal 1250, item["acquired_price_cents"]
    assert_equal "Foil", item["treatment"]
    assert_equal "Japanese", item["language"]
    assert_equal "Black Lotus", item["card_name"]
  end

  test "GET /api/inventory returns empty array when inventory is empty" do
    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 0, items.size
  end

  test "GET /api/inventory uses cached card details to minimize API calls" do
    CollectionItem.create!(user: @user, card_id: "uuid-cached", collection_type: "inventory", quantity: 1)

    stub = stub_scryfall_card_details("uuid-cached")

    # First request should hit Scryfall API
    get api_path("/inventory")
    assert_response :success

    # Second request should use cached data
    get api_path("/inventory")
    assert_response :success

    # Verify API was only called once due to caching
    assert_requested stub, times: 1
  end

  # ---------------------------------------------------------------------------
  # #create -- adds item or increments quantity on duplicate
  # ---------------------------------------------------------------------------
  test "POST /api/inventory creates a new inventory item" do
    stub_valid_card("new_card")

    post api_path("/inventory"), params: { card_id: "new_card", quantity: 3 }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "new_card", body["card_id"]
    assert_equal "inventory", body["collection_type"]
    assert_equal 3, body["quantity"]
    assert_equal @user.id, body["user_id"]
  end

  test "POST /api/inventory increments quantity when card already exists in inventory" do
    CollectionItem.create!(user: @user, card_id: "existing_card", collection_type: "inventory", quantity: 2)

    stub_valid_card("existing_card")

    post api_path("/inventory"), params: { card_id: "existing_card", quantity: 3 }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "existing_card", body["card_id"]
    assert_equal 5, body["quantity"]

    # Only one row should exist
    assert_equal 1, CollectionItem.where(user: @user, card_id: "existing_card", collection_type: "inventory").count
  end

  test "POST /api/inventory returns unprocessable_entity for missing card_id" do
    post api_path("/inventory"), params: { quantity: 1 }, as: :json

    assert_response :unprocessable_entity
  end

  test "POST /api/inventory returns unprocessable_entity for zero quantity" do
    stub_valid_card("bad_qty")

    post api_path("/inventory"), params: { card_id: "bad_qty", quantity: 0 }, as: :json

    assert_response :unprocessable_entity
  end

  test "POST /api/inventory validates card via Scryfall before persisting" do
    stub_valid_card("sdk_valid_card")

    post api_path("/inventory"), params: { card_id: "sdk_valid_card", quantity: 1 }, as: :json

    assert_response :created
    assert CollectionItem.exists?(user: @user, card_id: "sdk_valid_card", collection_type: "inventory")
  end

  test "POST /api/inventory returns 422 when card ID is not found in Scryfall" do
    stub_invalid_card("nonexistent_card")

    post api_path("/inventory"), params: { card_id: "nonexistent_card", quantity: 1 }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["error"], "Card not found"
    assert_equal 0, CollectionItem.where(user: @user, card_id: "nonexistent_card").count
  end

  # ---------------------------------------------------------------------------
  # #update -- updates quantity on an existing item (Issue #40)
  # ---------------------------------------------------------------------------
  test "PATCH /api/inventory/:id updates quantity and returns updated item" do
    item = CollectionItem.create!(user: @user, card_id: "update_card", collection_type: "inventory", quantity: 1)

    stub_request(:get, "https://api.scryfall.com/cards/update_card")
      .to_return(
        status: 200,
        body: {
          id: "update_card",
          name: "Updated Card",
          set: "upd",
          set_name: "Update Set",
          collector_number: "42",
          released_at: "2024-01-01",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/u/p/updated.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    patch api_path("/inventory/#{item.id}"), params: { quantity: 5 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 5, body["quantity"]
    assert_equal "update_card", body["card_id"]
    assert_equal "Updated Card", body["card_name"]
    assert_equal "upd", body["set"]
    assert_equal "Update Set", body["set_name"]
    assert_equal "inventory", body["collection_type"]
    assert_equal @user.id, body["user_id"]

    # Verify database was updated
    item.reload
    assert_equal 5, item.quantity
    assert_equal 1, CollectionItem.where(user: @user, card_id: "update_card", collection_type: "inventory").count
  end

  test "PATCH /api/inventory/:id accepts quantity of 1 (minimum valid)" do
    item = CollectionItem.create!(user: @user, card_id: "min_qty_card", collection_type: "inventory", quantity: 5)

    stub_request(:get, "https://api.scryfall.com/cards/min_qty_card")
      .to_return(
        status: 200,
        body: {
          id: "min_qty_card",
          name: "Min Quantity Card",
          set: "min",
          set_name: "Min Set",
          collector_number: "1",
          released_at: "2024-01-01",
          image_uris: { normal: "https://cards.scryfall.io/normal/front/m/i/min.jpg" }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    patch api_path("/inventory/#{item.id}"), params: { quantity: 1 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["quantity"]
  end

  test "PATCH /api/inventory/:id accepts quantity of 999 (maximum valid)" do
    item = CollectionItem.create!(user: @user, card_id: "max_qty_card", collection_type: "inventory", quantity: 1)

    stub_request(:get, "https://api.scryfall.com/cards/max_qty_card")
      .to_return(
        status: 200,
        body: {
          id: "max_qty_card",
          name: "Max Quantity Card",
          set: "max",
          set_name: "Max Set",
          collector_number: "999",
          released_at: "2024-01-01",
          image_uris: { normal: "https://cards.scryfall.io/normal/front/m/a/max.jpg" }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    patch api_path("/inventory/#{item.id}"), params: { quantity: 999 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 999, body["quantity"]
  end

  test "PATCH /api/inventory/:id returns 422 for quantity of 0" do
    item = CollectionItem.create!(user: @user, card_id: "zero_qty_card", collection_type: "inventory", quantity: 5)

    patch api_path("/inventory/#{item.id}"), params: { quantity: 0 }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(" "), "greater than 0"

    # Verify quantity was not changed
    item.reload
    assert_equal 5, item.quantity
  end

  test "PATCH /api/inventory/:id returns 422 for negative quantity" do
    item = CollectionItem.create!(user: @user, card_id: "negative_qty_card", collection_type: "inventory", quantity: 3)

    patch api_path("/inventory/#{item.id}"), params: { quantity: -1 }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(" "), "greater than 0"

    # Verify quantity was not changed
    item.reload
    assert_equal 3, item.quantity
  end

  test "PATCH /api/inventory/:id returns 422 for quantity greater than 999" do
    item = CollectionItem.create!(user: @user, card_id: "huge_qty_card", collection_type: "inventory", quantity: 1)

    patch api_path("/inventory/#{item.id}"), params: { quantity: 1000 }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(" "), "less than or equal to 999"

    # Verify quantity was not changed
    item.reload
    assert_equal 1, item.quantity
  end

  test "PATCH /api/inventory/:id returns 404 for non-existent item" do
    patch api_path("/inventory/99999"), params: { quantity: 5 }, as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Not found", body["error"]
  end

  test "PATCH /api/inventory/:id returns 404 for another user's item" do
    other_user = User.create!(email: "other_update@example.com", name: "Other")
    item = CollectionItem.create!(user: other_user, card_id: "other_card", collection_type: "inventory", quantity: 1)

    patch api_path("/inventory/#{item.id}"), params: { quantity: 10 }, as: :json

    assert_response :not_found

    # Verify other user's item was not changed
    item.reload
    assert_equal 1, item.quantity
  end

  test "PATCH /api/inventory/:id preserves other fields when updating quantity" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "preserve_fields_card",
      collection_type: "inventory",
      quantity: 2,
      acquired_date: Date.parse("2025-01-15"),
      acquired_price_cents: 1500,
      treatment: "Foil",
      language: "Japanese"
    )

    stub_request(:get, "https://api.scryfall.com/cards/preserve_fields_card")
      .to_return(
        status: 200,
        body: {
          id: "preserve_fields_card",
          name: "Preserve Fields Card",
          set: "pre",
          set_name: "Preserve Set",
          collector_number: "100",
          released_at: "2024-01-01",
          image_uris: { normal: "https://cards.scryfall.io/normal/front/p/r/preserve.jpg" }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    patch api_path("/inventory/#{item.id}"), params: { quantity: 7 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 7, body["quantity"]
    assert_equal "2025-01-15", body["acquired_date"]
    assert_equal 1500, body["acquired_price_cents"]
    assert_equal "Foil", body["treatment"]
    assert_equal "Japanese", body["language"]
  end

  # ---------------------------------------------------------------------------
  # #destroy -- removes item (Issue #40)
  # ---------------------------------------------------------------------------
  test "DELETE /api/inventory/:id removes the item and returns 204 No Content" do
    item = CollectionItem.create!(user: @user, card_id: "delete_card", collection_type: "inventory", quantity: 1)

    delete api_path("/inventory/#{item.id}")

    assert_response :no_content
    assert response.body.blank?, "Response body should be empty for 204 No Content"
    assert_equal 0, CollectionItem.where(id: item.id).count
  end

  test "DELETE /api/inventory/:id removes item with all associated data" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "delete_full_card",
      collection_type: "inventory",
      quantity: 5,
      acquired_date: Date.parse("2025-01-10"),
      acquired_price_cents: 2000,
      treatment: "Foil",
      language: "German"
    )
    item_id = item.id

    delete api_path("/inventory/#{item_id}")

    assert_response :no_content
    assert_equal 0, CollectionItem.where(id: item_id).count
  end

  test "DELETE /api/inventory/:id returns 404 for non-existent item" do
    delete api_path("/inventory/99999")

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Not found", body["error"]
  end

  test "DELETE /api/inventory/:id returns 404 for another user's item" do
    other_user = User.create!(email: "other_delete@example.com", name: "Other")
    item = CollectionItem.create!(user: other_user, card_id: "cant_delete", collection_type: "inventory", quantity: 1)

    delete api_path("/inventory/#{item.id}")

    assert_response :not_found
    assert_equal 1, CollectionItem.where(id: item.id).count
  end

  test "DELETE /api/inventory/:id does not affect other user's items" do
    # Current user's item
    my_item = CollectionItem.create!(user: @user, card_id: "my_delete_card", collection_type: "inventory", quantity: 2)

    # Another user with same card
    other_user = User.create!(email: "other_user@example.com", name: "Other User")
    other_item = CollectionItem.create!(user: other_user, card_id: "my_delete_card", collection_type: "inventory", quantity: 3)

    delete api_path("/inventory/#{my_item.id}")

    assert_response :no_content

    # My item should be deleted
    assert_equal 0, CollectionItem.where(id: my_item.id).count

    # Other user's item should still exist
    assert_equal 1, CollectionItem.where(id: other_item.id).count
    other_item.reload
    assert_equal 3, other_item.quantity
  end

  test "DELETE /api/inventory/:id does not affect current user's wishlist items" do
    inventory_item = CollectionItem.create!(user: @user, card_id: "shared_card", collection_type: "inventory", quantity: 1)
    wishlist_item = CollectionItem.create!(user: @user, card_id: "shared_card", collection_type: "wishlist", quantity: 2)

    delete api_path("/inventory/#{inventory_item.id}")

    assert_response :no_content

    # Inventory item should be deleted
    assert_equal 0, CollectionItem.where(id: inventory_item.id).count

    # Wishlist item should still exist
    assert_equal 1, CollectionItem.where(id: wishlist_item.id).count
    wishlist_item.reload
    assert_equal 2, wishlist_item.quantity
  end

  # ---------------------------------------------------------------------------
  # move_from_wishlist -- moves item from wishlist to inventory
  # ---------------------------------------------------------------------------
  test "POST /api/inventory/move_from_wishlist moves wishlist item to inventory" do
    wish_item = CollectionItem.create!(user: @user, card_id: "move_card", collection_type: "wishlist", quantity: 4)

    post api_path("/inventory/move_from_wishlist"), params: { card_id: "move_card" }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "move_card", body["card_id"]
    assert_equal "inventory", body["collection_type"]
    assert_equal 4, body["quantity"]

    # Wishlist row must be gone
    assert_equal 0, CollectionItem.where(user: @user, card_id: "move_card", collection_type: "wishlist").count
    # Inventory row must exist
    assert_equal 1, CollectionItem.where(user: @user, card_id: "move_card", collection_type: "inventory").count
  end

  test "POST /api/inventory/move_from_wishlist returns not_found when card not in wishlist" do
    post api_path("/inventory/move_from_wishlist"), params: { card_id: "nonexistent" }, as: :json

    assert_response :not_found
  end

  # ---------------------------------------------------------------------------
  # Error handling for missing default user
  # ---------------------------------------------------------------------------
  test "POST /api/inventory returns clear error when default user is missing from database" do
    User.delete_all
    stub_valid_card("test_card")

    post api_path("/inventory"), params: { card_id: "test_card", quantity: 1 }, as: :json

    assert_response :internal_server_error
    body = JSON.parse(response.body)
    assert_includes body["error"], "default user"
    assert_includes body["error"], "was not found"
    assert_includes body["error"], "db:seed"
  end

  # ---------------------------------------------------------------------------
  # Enhanced tracking fields (Story #28)
  # ---------------------------------------------------------------------------

  # Scenario 1: Create inventory with all enhanced fields
  test "POST /api/inventory with all enhanced fields creates item with all values" do
    stub_valid_card("enhanced_card")

    post api_path("/inventory"), params: {
      card_id: "enhanced_card",
      quantity: 2,
      acquired_date: "2025-12-15",
      acquired_price_cents: 1250,
      treatment: "Foil",
      language: "Japanese"
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "enhanced_card", body["card_id"]
    assert_equal 2, body["quantity"]
    assert_equal "2025-12-15", body["acquired_date"]
    assert_equal 1250, body["acquired_price_cents"]
    assert_equal "Foil", body["treatment"]
    assert_equal "Japanese", body["language"]

    # Verify persistence
    item = CollectionItem.find_by(user: @user, card_id: "enhanced_card")
    assert_equal 1250, item.acquired_price_cents
    assert_equal "Foil", item.treatment
    assert_equal "Japanese", item.language
    assert_equal Date.parse("2025-12-15"), item.acquired_date
  end

  # Scenario 1b: Create inventory with price parameter (decimal conversion)
  test "POST /api/inventory with price parameter converts to acquired_price_cents" do
    stub_valid_card("price_card")

    post api_path("/inventory"), params: {
      card_id: "price_card",
      quantity: 1,
      price: 12.50
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "price_card", body["card_id"]
    assert_equal 1250, body["acquired_price_cents"]

    # Verify persistence
    item = CollectionItem.find_by(user: @user, card_id: "price_card")
    assert_equal 1250, item.acquired_price_cents
  end

  # Scenario 2: Create inventory with partial enhanced fields (defaults applied)
  test "POST /api/inventory with only price uses defaults for other fields" do
    stub_valid_card("partial_card")

    post api_path("/inventory"), params: {
      card_id: "partial_card",
      quantity: 1,
      price: 10.00
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "partial_card", body["card_id"]
    assert_equal 1, body["quantity"]
    assert_equal 1000, body["acquired_price_cents"]
    assert_equal Date.today.to_s, body["acquired_date"]
    assert_equal "Normal", body["treatment"]
    assert_equal "English", body["language"]

    # Verify persistence
    item = CollectionItem.find_by(user: @user, card_id: "partial_card")
    assert_equal 1000, item.acquired_price_cents
    assert_equal "Normal", item.treatment
    assert_equal "English", item.language
    assert_equal Date.today, item.acquired_date
  end

  # Scenario 3: Create inventory with no enhanced fields (backward compatibility)
  test "POST /api/inventory with no enhanced fields maintains backward compatibility" do
    stub_valid_card("legacy_card")

    post api_path("/inventory"), params: {
      card_id: "legacy_card",
      quantity: 3
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "legacy_card", body["card_id"]
    assert_equal 3, body["quantity"]
    assert_nil body["acquired_date"]
    assert_nil body["acquired_price_cents"]
    assert_nil body["treatment"]
    assert_nil body["language"]

    # Verify persistence
    item = CollectionItem.find_by(user: @user, card_id: "legacy_card")
    assert_nil item.acquired_price_cents
    assert_nil item.treatment
    assert_nil item.language
    assert_nil item.acquired_date
  end

  # Scenario 4: Validation errors return clear messages
  test "POST /api/inventory with negative price returns 422 with error message" do
    stub_valid_card("bad_price_card")

    post api_path("/inventory"), params: {
      card_id: "bad_price_card",
      quantity: 1,
      acquired_price_cents: -1000
    }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(" "), "must be greater than or equal to 0"
  end

  test "POST /api/inventory with future date returns 422 with error message" do
    stub_valid_card("future_date_card")
    future_date = (Date.today + 1).to_s

    post api_path("/inventory"), params: {
      card_id: "future_date_card",
      quantity: 1,
      acquired_date: future_date
    }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(" "), "cannot be in the future"
  end

  test "POST /api/inventory with invalid treatment returns 422 with error message" do
    stub_valid_card("bad_treatment_card")

    post api_path("/inventory"), params: {
      card_id: "bad_treatment_card",
      quantity: 1,
      treatment: "SuperUltraFoil"
    }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(" "), "Treatment"
  end

  test "POST /api/inventory with invalid language returns 422 with error message" do
    stub_valid_card("bad_language_card")

    post api_path("/inventory"), params: {
      card_id: "bad_language_card",
      quantity: 1,
      language: "Klingon"
    }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(" "), "Language"
  end

  # Scenario 5: Upsert behavior preserves enhanced fields
  test "POST /api/inventory upsert preserves existing enhanced fields" do
    CollectionItem.create!(
      user: @user,
      card_id: "existing_enhanced",
      collection_type: "inventory",
      quantity: 1,
      acquired_price_cents: 500,
      treatment: "Foil",
      language: "German",
      acquired_date: Date.parse("2025-01-01")
    )

    stub_valid_card("existing_enhanced")

    post api_path("/inventory"), params: {
      card_id: "existing_enhanced",
      quantity: 2
    }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "existing_enhanced", body["card_id"]
    assert_equal 3, body["quantity"] # 1 + 2

    # Verify existing enhanced fields are preserved
    assert_equal 500, body["acquired_price_cents"]
    assert_equal "Foil", body["treatment"]
    assert_equal "German", body["language"]
    assert_equal "2025-01-01", body["acquired_date"]

    # Verify only one record exists
    assert_equal 1, CollectionItem.where(user: @user, card_id: "existing_enhanced", collection_type: "inventory").count
  end

  # ---------------------------------------------------------------------------
  # Image caching integration tests (Story #44)
  # ---------------------------------------------------------------------------

  test "POST /api/inventory enqueues background job to cache card image" do
    stub_scryfall_card_details("cache_job_card", name: "Cache Test Card")

    assert_enqueued_with(job: CacheCardImageJob) do
      post api_path("/inventory"), params: { card_id: "cache_job_card", quantity: 1 }, as: :json
    end

    assert_response :created
  end

  test "POST /api/inventory enqueues job with correct collection item ID and image URL" do
    card_id = "cache_with_url"
    image_url = "https://cards.scryfall.io/normal/front/t/e/test.jpg"

    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Test Card",
          image_uris: { normal: image_url }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    post api_path("/inventory"), params: { card_id: card_id, quantity: 1 }, as: :json
    assert_response :created

    item = CollectionItem.find_by(card_id: card_id, user: @user, collection_type: "inventory")
    assert_not_nil item

    assert_enqueued_with(job: CacheCardImageJob, args: [item.id, image_url])
  end

  test "POST /api/inventory does not enqueue job when card has no image URL" do
    card_id = "no_image_card"

    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Test Card Without Image"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_no_enqueued_jobs do
      post api_path("/inventory"), params: { card_id: card_id, quantity: 1 }, as: :json
    end

    assert_response :created
  end

  test "POST /api/inventory does not fail if job enqueue fails" do
    stub_valid_card("job_fail_card")

    # Stub job to raise error
    CacheCardImageJob.stub(:perform_later, ->(*_args) { raise "Job system down" }) do
      post api_path("/inventory"), params: { card_id: "job_fail_card", quantity: 1 }, as: :json
    end

    # Card should still be created
    assert_response :created
    assert CollectionItem.exists?(card_id: "job_fail_card", user: @user, collection_type: "inventory")
  end

  test "POST /api/inventory on upsert enqueues job only once for new item" do
    stub_scryfall_card_details("upsert_cache_card", name: "Upsert Test Card")

    # First request - creates new item
    assert_enqueued_jobs 1, only: CacheCardImageJob do
      post api_path("/inventory"), params: { card_id: "upsert_cache_card", quantity: 1 }, as: :json
    end

    # Second request - updates existing item, should still enqueue (in case previous job failed)
    assert_enqueued_jobs 1, only: CacheCardImageJob do
      post api_path("/inventory"), params: { card_id: "upsert_cache_card", quantity: 2 }, as: :json
    end
  end

  test "background job successfully caches image after inventory creation" do
    card_id = "integration_cache_test"
    image_url = "https://cards.scryfall.io/normal/front/t/e/test.jpg"

    # Stub card validation
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Integration Test Card",
          image_uris: { normal: image_url }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub image download
    jpeg_data = "\xFF\xD8\xFF\xE0\x00\x10JFIF".b
    stub_request(:get, image_url)
      .to_return(
        status: 200,
        body: jpeg_data,
        headers: { "Content-Type" => "image/jpeg" }
      )

    # Create inventory item
    post api_path("/inventory"), params: { card_id: card_id, quantity: 1 }, as: :json
    assert_response :created

    # Perform enqueued jobs
    perform_enqueued_jobs

    # Verify image was cached
    item = CollectionItem.find_by(card_id: card_id, user: @user, collection_type: "inventory")
    assert_not_nil item
    assert item.cached_image.attached?, "Image should be cached after job runs"
  end

  test "inventory creation succeeds even when image caching job fails" do
    card_id = "cache_fail_card"
    image_url = "https://cards.scryfall.io/normal/front/fail/fail.jpg"

    # Stub card validation
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Cache Fail Card",
          image_uris: { normal: image_url }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub image download to fail
    stub_request(:get, image_url)
      .to_raise(SocketError.new("Connection failed"))

    # Create inventory item
    post api_path("/inventory"), params: { card_id: card_id, quantity: 1 }, as: :json
    assert_response :created

    # Perform enqueued jobs (should not raise exception)
    assert_nothing_raised do
      perform_enqueued_jobs
    end

    # Verify card was still added to inventory
    item = CollectionItem.find_by(card_id: card_id, user: @user, collection_type: "inventory")
    assert_not_nil item
    refute item.cached_image.attached?, "Image should not be cached when download fails"
  end

  # ---------------------------------------------------------------------------
  # Cached image URL tests (Story #44)
  # ---------------------------------------------------------------------------

  test "GET /api/inventory returns local storage URL when image is cached" do
    card_id = "cached_image_card"
    scryfall_url = "https://cards.scryfall.io/normal/front/c/c/cached.jpg"

    # Create inventory item with cached image
    item = CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    # Attach a cached image
    item.cached_image.attach(
      io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
      filename: "#{card_id}.jpg",
      content_type: "image/jpeg"
    )

    # Stub Scryfall card details
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Cached Card",
          set: "TST",
          set_name: "Test Set",
          collector_number: "1",
          image_uris: { normal: scryfall_url }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    # Should return local storage URL, not Scryfall URL
    refute_equal scryfall_url, items.first["image_url"], "Should not return Scryfall URL when cached"
    assert items.first["image_url"].include?("rails/active_storage"), "Should return Active Storage URL"
    assert_equal true, items.first["image_cached"], "Should indicate image is cached"
  end

  test "GET /api/inventory returns Scryfall URL when image is not cached" do
    card_id = "uncached_image_card"
    scryfall_url = "https://cards.scryfall.io/normal/front/u/u/uncached.jpg"

    # Create inventory item without cached image
    CollectionItem.create!(
      user: @user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    # Stub Scryfall card details
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Uncached Card",
          set: "TST",
          set_name: "Test Set",
          collector_number: "2",
          image_uris: { normal: scryfall_url }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    # Should return Scryfall URL as fallback
    assert_equal scryfall_url, items.first["image_url"], "Should return Scryfall URL when not cached"
    assert_equal false, items.first["image_cached"], "Should indicate image is not cached"
  end

  test "GET /api/inventory handles mixed cached and uncached images" do
    # Card with cached image
    cached_card_id = "cached_mix"
    cached_item = CollectionItem.create!(
      user: @user,
      card_id: cached_card_id,
      collection_type: "inventory",
      quantity: 1
    )
    cached_item.cached_image.attach(
      io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
      filename: "#{cached_card_id}.jpg",
      content_type: "image/jpeg"
    )
    stub_scryfall_card_details(cached_card_id, name: "Cached Mix Card")

    # Card without cached image
    uncached_card_id = "uncached_mix"
    CollectionItem.create!(
      user: @user,
      card_id: uncached_card_id,
      collection_type: "inventory",
      quantity: 1
    )
    stub_scryfall_card_details(uncached_card_id, name: "Uncached Mix Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 2, items.size

    cached_item_response = items.find { |i| i["card_id"] == cached_card_id }
    uncached_item_response = items.find { |i| i["card_id"] == uncached_card_id }

    assert cached_item_response["image_cached"], "Cached item should be marked as cached"
    refute uncached_item_response["image_cached"], "Uncached item should not be marked as cached"
  end

  # ---------------------------------------------------------------------------
  # #index with released_at field (Story #39)
  # ---------------------------------------------------------------------------
  test "GET /api/inventory includes released_at field for sorting by release date" do
    CollectionItem.create!(user: @user, card_id: "uuid-release", collection_type: "inventory", quantity: 1)

    stub_request(:get, "https://api.scryfall.com/cards/uuid-release")
      .to_return(
        status: 200,
        body: {
          id: "uuid-release",
          name: "Test Card",
          set: "M21",
          set_name: "Core Set 2021",
          collector_number: "100",
          released_at: "2020-07-03",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/t/e/test.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    item = items.first
    assert_equal "uuid-release", item["card_id"]
    assert_equal "2020-07-03", item["released_at"], "Should include released_at field from Scryfall"
  end

  test "GET /api/inventory includes created_at field for sorting by date added" do
    # Create items at different times
    first_item = CollectionItem.create!(
      user: @user,
      card_id: "uuid-first",
      collection_type: "inventory",
      quantity: 1,
      created_at: 3.days.ago
    )
    second_item = CollectionItem.create!(
      user: @user,
      card_id: "uuid-second",
      collection_type: "inventory",
      quantity: 1,
      created_at: 1.day.ago
    )

    stub_scryfall_card_details("uuid-first", name: "First Card")
    stub_scryfall_card_details("uuid-second", name: "Second Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 2, items.size

    # Verify both items have created_at timestamps
    items.each do |item|
      assert_not_nil item["created_at"], "Should include created_at field for sorting by date added"
      assert item["created_at"].is_a?(String), "created_at should be a string (ISO8601 format)"
    end

    # Find items by card_id
    first_item_response = items.find { |i| i["card_id"] == "uuid-first" }
    second_item_response = items.find { |i| i["card_id"] == "uuid-second" }

    # Verify the timestamps match the created items
    assert_equal first_item.created_at.iso8601(3), first_item_response["created_at"]
    assert_equal second_item.created_at.iso8601(3), second_item_response["created_at"]
  end

  test "GET /api/inventory includes all fields required for filtering and sorting" do
    CollectionItem.create!(
      user: @user,
      card_id: "uuid-complete",
      collection_type: "inventory",
      quantity: 5,
      created_at: 2.days.ago
    )

    stub_request(:get, "https://api.scryfall.com/cards/uuid-complete")
      .to_return(
        status: 200,
        body: {
          id: "uuid-complete",
          name: "Complete Test Card",
          set: "XYZ",
          set_name: "Test Expansion",
          collector_number: "42",
          released_at: "2021-05-15",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/c/c/complete.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    item = items.first
    # Fields required for filtering
    assert_not_nil item["set"], "Should include set for filtering"
    assert_not_nil item["set_name"], "Should include set_name for filtering"

    # Fields required for sorting
    assert_not_nil item["card_name"], "Should include card_name for sorting by name"
    assert_not_nil item["quantity"], "Should include quantity for sorting by quantity"
    assert_not_nil item["released_at"], "Should include released_at for sorting by release date"
    assert_not_nil item["created_at"], "Should include created_at for sorting by date added"

    # Verify actual values
    assert_equal "Complete Test Card", item["card_name"]
    assert_equal "XYZ", item["set"]
    assert_equal "Test Expansion", item["set_name"]
    assert_equal 5, item["quantity"]
    assert_equal "2021-05-15", item["released_at"]
  end

  # ---------------------------------------------------------------------------
  # #index with price enrichment -- includes market value data
  # ---------------------------------------------------------------------------
  test "GET /api/inventory includes price data for normal cards" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "priced_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Normal"
    )

    CardPrice.create!(
      card_id: "priced_card",
      fetched_at: 1.hour.ago,
      usd_cents: 250,
      usd_foil_cents: 500
    )

    stub_scryfall_card_details("priced_card", name: "Priced Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    item = items.first
    assert_equal 250, item["unit_price_cents"]
    assert_equal 250, item["total_price_cents"]
    assert_not_nil item["price_updated_at"]
  end

  test "GET /api/inventory includes foil price for foil cards" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "foil_card",
      collection_type: "inventory",
      quantity: 2,
      treatment: "Foil"
    )

    CardPrice.create!(
      card_id: "foil_card",
      fetched_at: 2.hours.ago,
      usd_cents: 300,
      usd_foil_cents: 800
    )

    stub_scryfall_card_details("foil_card", name: "Foil Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    item = items.first

    assert_equal 800, item["unit_price_cents"]
    assert_equal 1600, item["total_price_cents"]
  end

  test "GET /api/inventory uses fallback price when foil price is nil" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "foil_fallback_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Foil"
    )

    CardPrice.create!(
      card_id: "foil_fallback_card",
      fetched_at: 1.hour.ago,
      usd_cents: 150,
      usd_foil_cents: nil
    )

    stub_scryfall_card_details("foil_fallback_card", name: "Foil Fallback")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    item = items.first

    assert_equal 150, item["unit_price_cents"]
    assert_equal 150, item["total_price_cents"]
  end

  test "GET /api/inventory includes etched price for etched cards" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "etched_card",
      collection_type: "inventory",
      quantity: 3,
      treatment: "Etched"
    )

    CardPrice.create!(
      card_id: "etched_card",
      fetched_at: 1.hour.ago,
      usd_cents: 200,
      usd_etched_cents: 450
    )

    stub_scryfall_card_details("etched_card", name: "Etched Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    item = items.first

    assert_equal 450, item["unit_price_cents"]
    assert_equal 1350, item["total_price_cents"]
  end

  test "GET /api/inventory uses fallback price when etched price is nil" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "etched_fallback_card",
      collection_type: "inventory",
      quantity: 1,
      treatment: "Etched"
    )

    CardPrice.create!(
      card_id: "etched_fallback_card",
      fetched_at: 1.hour.ago,
      usd_cents: 180,
      usd_etched_cents: nil
    )

    stub_scryfall_card_details("etched_fallback_card", name: "Etched Fallback")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    item = items.first

    assert_equal 180, item["unit_price_cents"]
    assert_equal 180, item["total_price_cents"]
  end

  test "GET /api/inventory returns null prices when no price data exists" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "no_price_card",
      collection_type: "inventory",
      quantity: 1
    )

    stub_scryfall_card_details("no_price_card", name: "No Price Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    item = items.first

    assert_nil item["unit_price_cents"]
    assert_nil item["total_price_cents"]
    assert_nil item["price_updated_at"]
  end

  test "GET /api/inventory calculates total price correctly for multiple copies" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "multi_card",
      collection_type: "inventory",
      quantity: 5,
      treatment: "Normal"
    )

    CardPrice.create!(
      card_id: "multi_card",
      fetched_at: 1.hour.ago,
      usd_cents: 125
    )

    stub_scryfall_card_details("multi_card", name: "Multi Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    item = items.first

    assert_equal 125, item["unit_price_cents"]
    assert_equal 625, item["total_price_cents"]
  end

  test "GET /api/inventory uses most recent price when multiple prices exist" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "historic_price_card",
      collection_type: "inventory",
      quantity: 1
    )

    # Older price
    CardPrice.create!(
      card_id: "historic_price_card",
      fetched_at: 7.days.ago,
      usd_cents: 100
    )

    # Newer price (should be used)
    CardPrice.create!(
      card_id: "historic_price_card",
      fetched_at: 1.hour.ago,
      usd_cents: 175
    )

    stub_scryfall_card_details("historic_price_card", name: "Historic Price Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    item = items.first

    assert_equal 175, item["unit_price_cents"]
  end

  test "GET /api/inventory includes price_updated_at timestamp" do
    item = CollectionItem.create!(
      user: @user,
      card_id: "timestamp_card",
      collection_type: "inventory",
      quantity: 1
    )

    fetched_time = 3.hours.ago
    CardPrice.create!(
      card_id: "timestamp_card",
      fetched_at: fetched_time,
      usd_cents: 200
    )

    stub_scryfall_card_details("timestamp_card", name: "Timestamp Card")

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    item = items.first

    assert_not_nil item["price_updated_at"]
    # Compare timestamps (allowing for small time differences due to test execution)
    parsed_time = Time.parse(item["price_updated_at"])
    assert_in_delta fetched_time.to_i, parsed_time.to_i, 1
  end

  private

end
