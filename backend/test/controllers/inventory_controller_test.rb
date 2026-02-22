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

  # Helper to extract items array from paginated response
  def parse_inventory_response
    body = JSON.parse(response.body)
    # If response has pagination metadata, extract items array
    if body.is_a?(Hash) && body.key?("items")
      body["items"]
    else
      # Fallback for non-paginated responses (shouldn't happen after refactor)
      body
    end
  end

  # Stubs Scryfall API to validate a card ID
  def stub_valid_card(card_id)
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
      .to_return(
        status: 200,
        body: { id: card_id, name: "Test Card" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stubs Scryfall API to return 404 for invalid card
  def stub_invalid_card(card_id)
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
      .to_return(status: 404, body: '{"object":"error","code":"not_found"}')
  end

  # Stubs Scryfall API to return card details
  def stub_scryfall_card_details(card_id, name: "Black Lotus")
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
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

  def stub_scryfall_special_finish(card_id, name: "Special Card", promo_types: [])
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: "SLD",
          set_name: "Secret Lair Drop",
          collector_number: "1",
          finishes: [ "foil" ],
          promo_types: promo_types,
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/s/s/special.jpg"
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
    items = parse_inventory_response
    assert_equal 1, items.size
    assert_equal "my_card", items.first["card_id"]
  end

  test "GET /api/inventory does not return wishlist items" do
    CollectionItem.create!(user: @user, card_id: "inv_card", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "wish_card", collection_type: "wishlist", quantity: 1)

    stub_scryfall_card_details("inv_card", name: "Inventory Card")

    get api_path("/inventory")

    assert_response :success
    items = parse_inventory_response
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
    items = parse_inventory_response
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
    items = parse_inventory_response
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
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-missing")
      .to_return(status: 404, body: '{"object":"error","code":"not_found"}')

    get api_path("/inventory")

    assert_response :success
    items = parse_inventory_response

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
      finish: "foil",
      language: "Japanese"
    )

    stub_scryfall_card_details("uuid-enhanced")

    get api_path("/inventory")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size

    item = items.first
    assert_equal "uuid-enhanced", item["card_id"]
    assert_equal 2, item["quantity"]
    assert_equal "2025-12-15", item["acquired_date"]
    assert_equal 1250, item["acquired_price_cents"]
    assert_equal "foil", item["finish"]
    assert_equal "Japanese", item["language"]
    assert_equal "Black Lotus", item["card_name"]
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Test that promo_types are included in inventory response
  # ---------------------------------------------------------------------------
  test "GET /api/inventory includes promo_types for special finish cards" do
    CollectionItem.create!(
      user: @user,
      card_id: "uuid-halofoil",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    stub_scryfall_special_finish("uuid-halofoil", name: "Utvara Hellkite", promo_types: [ "halofoil" ])

    get api_path("/inventory")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size

    item = items.first
    assert_equal "uuid-halofoil", item["card_id"]
    assert_equal "Utvara Hellkite", item["card_name"]
    assert_equal "foil", item["finish"]
    assert_equal [ "halofoil" ], item["promo_types"]
  end

  test "GET /api/inventory returns empty promo_types array when not present" do
    CollectionItem.create!(
      user: @user,
      card_id: "uuid-normal",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil"
    )

    stub_scryfall_card_details("uuid-normal")

    get api_path("/inventory")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size

    item = items.first
    assert_equal "uuid-normal", item["card_id"]
    assert_equal [], item["promo_types"]
  end

  test "GET /api/inventory returns empty array when inventory is empty" do
    get api_path("/inventory")

    assert_response :success
    items = parse_inventory_response
    assert_equal 0, items.size
  end

  test "GET /api/inventory uses cached card details to minimize API calls" do
    stub = stub_scryfall_card_details("uuid-cached")

    # Create item with denormalized fields populated to skip sync_card_metadata callback
    CollectionItem.create!(
      user: @user,
      card_id: "uuid-cached",
      collection_type: "inventory",
      quantity: 1,
      card_name: "Black Lotus",
      set_name: "Limited Edition Alpha",
      released_at: Date.parse("1993-08-05")
    )

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

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/update_card")
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

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/min_qty_card")
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

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/max_qty_card")
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
      finish: "foil",
      language: "Japanese"
    )

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/preserve_fields_card")
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
    assert_equal "foil", body["finish"]
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
      finish: "foil",
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

  test "POST /api/inventory/move_from_wishlist accepts acquired_date and acquired_price parameters" do
    wish_item = CollectionItem.create!(user: @user, card_id: "move_with_params", collection_type: "wishlist", quantity: 2)

    post api_path("/inventory/move_from_wishlist"), params: {
      card_id: "move_with_params",
      acquired_date: "2026-02-10",
      acquired_price_cents: 1500
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "move_with_params", body["card_id"]
    assert_equal "inventory", body["collection_type"]
    assert_equal 2, body["quantity"]
    assert_equal "2026-02-10", body["acquired_date"]
    assert_equal 1500, body["acquired_price_cents"]

    # Wishlist row must be gone
    assert_equal 0, CollectionItem.where(user: @user, card_id: "move_with_params", collection_type: "wishlist").count
  end

  test "POST /api/inventory/move_from_wishlist validates required acquired_date parameter" do
    wish_item = CollectionItem.create!(user: @user, card_id: "move_no_date", collection_type: "wishlist", quantity: 1)

    post api_path("/inventory/move_from_wishlist"), params: {
      card_id: "move_no_date",
      acquired_price_cents: 1000
    }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["error"], "acquired_date"

    # Wishlist item should still exist
    assert_equal 1, CollectionItem.where(user: @user, card_id: "move_no_date", collection_type: "wishlist").count
  end

  test "POST /api/inventory/move_from_wishlist validates required acquired_price parameter" do
    wish_item = CollectionItem.create!(user: @user, card_id: "move_no_price", collection_type: "wishlist", quantity: 1)

    post api_path("/inventory/move_from_wishlist"), params: {
      card_id: "move_no_price",
      acquired_date: "2026-02-10"
    }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["error"], "acquired_price"

    # Wishlist item should still exist
    assert_equal 1, CollectionItem.where(user: @user, card_id: "move_no_price", collection_type: "wishlist").count
  end

  test "POST /api/inventory/move_from_wishlist increments quantity when card already in inventory" do
    CollectionItem.create!(user: @user, card_id: "existing_inv", collection_type: "inventory", quantity: 3, acquired_date: Date.parse("2026-01-01"), acquired_price_cents: 1000)
    CollectionItem.create!(user: @user, card_id: "existing_inv", collection_type: "wishlist", quantity: 2)

    post api_path("/inventory/move_from_wishlist"), params: {
      card_id: "existing_inv",
      acquired_date: "2026-02-10",
      acquired_price_cents: 1500
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "existing_inv", body["card_id"]
    assert_equal "inventory", body["collection_type"]
    assert_equal 5, body["quantity"] # 3 + 2

    # Wishlist row must be gone
    assert_equal 0, CollectionItem.where(user: @user, card_id: "existing_inv", collection_type: "wishlist").count
    # Only one inventory row should exist
    assert_equal 1, CollectionItem.where(user: @user, card_id: "existing_inv", collection_type: "inventory").count
  end

  test "POST /api/inventory/move_from_wishlist rolls back on error" do
    wish_item = CollectionItem.create!(user: @user, card_id: "rollback_test", collection_type: "wishlist", quantity: 1)

    post api_path("/inventory/move_from_wishlist"), params: {
      card_id: "rollback_test",
      acquired_date: (Date.today + 1).to_s, # Future date - invalid
      acquired_price_cents: 1000
    }, as: :json

    assert_response :unprocessable_entity

    # Wishlist item should still exist (transaction rolled back)
    assert_equal 1, CollectionItem.where(user: @user, card_id: "rollback_test", collection_type: "wishlist").count
    # No inventory item should be created
    assert_equal 0, CollectionItem.where(user: @user, card_id: "rollback_test", collection_type: "inventory").count
  end

  test "POST /api/inventory/move_from_wishlist accepts optional finish and language parameters" do
    wish_item = CollectionItem.create!(user: @user, card_id: "move_with_optional", collection_type: "wishlist", quantity: 1)

    post api_path("/inventory/move_from_wishlist"), params: {
      card_id: "move_with_optional",
      acquired_date: "2026-02-10",
      acquired_price_cents: 2000,
      finish: "foil",
      language: "Japanese"
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "foil", body["finish"]
    assert_equal "Japanese", body["language"]
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
      finish: "foil",
      language: "Japanese"
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "enhanced_card", body["card_id"]
    assert_equal 2, body["quantity"]
    assert_equal "2025-12-15", body["acquired_date"]
    assert_equal 1250, body["acquired_price_cents"]
    assert_equal "foil", body["finish"]
    assert_equal "Japanese", body["language"]

    # Verify persistence
    item = CollectionItem.find_by(user: @user, card_id: "enhanced_card")
    assert_equal 1250, item.acquired_price_cents
    assert_equal "foil", item.finish
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
    assert_equal "nonfoil", body["finish"]
    assert_equal "English", body["language"]

    # Verify persistence
    item = CollectionItem.find_by(user: @user, card_id: "partial_card")
    assert_equal 1000, item.acquired_price_cents
    assert_equal "nonfoil", item.finish
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
    assert_nil body["finish"]
    assert_nil body["language"]

    # Verify persistence
    item = CollectionItem.find_by(user: @user, card_id: "legacy_card")
    assert_nil item.acquired_price_cents
    assert_nil item.finish
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

  test "POST /api/inventory with invalid finish returns 422 with error message" do
    stub_valid_card("bad_finish_card")

    post api_path("/inventory"), params: {
      card_id: "bad_finish_card",
      quantity: 1,
      finish: "SuperUltraFoil"
    }, as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(" "), "Finish"
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
      finish: "foil",
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
    assert_equal "foil", body["finish"]
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

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
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

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
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
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
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
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
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
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
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
    items = parse_inventory_response
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
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/#{card_id}")
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
    items = parse_inventory_response
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
    items = parse_inventory_response
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

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-release")
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
    items = parse_inventory_response
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
    items = parse_inventory_response
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

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-complete")
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
    items = parse_inventory_response
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
      finish: "nonfoil"
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
    items = parse_inventory_response
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
      finish: "foil"
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
    items = parse_inventory_response
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
      finish: "foil"
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
    items = parse_inventory_response
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
      finish: "etched"
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
    items = parse_inventory_response
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
      finish: "etched"
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
    items = parse_inventory_response
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
    items = parse_inventory_response
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
      finish: "nonfoil"
    )

    CardPrice.create!(
      card_id: "multi_card",
      fetched_at: 1.hour.ago,
      usd_cents: 125
    )

    stub_scryfall_card_details("multi_card", name: "Multi Card")

    get api_path("/inventory")

    assert_response :success
    items = parse_inventory_response
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
    items = parse_inventory_response
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
    items = parse_inventory_response
    item = items.first

    assert_not_nil item["price_updated_at"]
    # Compare timestamps (allowing for small time differences due to test execution)
    parsed_time = Time.parse(item["price_updated_at"])
    assert_in_delta fetched_time.to_i, parsed_time.to_i, 1
  end

  # ---------------------------------------------------------------------------
  # N+1 Query Optimization Tests (Issue #154)
  # ---------------------------------------------------------------------------

  test "GET /api/inventory uses eager loading to prevent N+1 queries" do
    # Create 20 inventory items with cached images and price data
    20.times do |i|
      item = CollectionItem.create!(
        user: @user,
        card_id: "eager_card_#{i}",
        collection_type: "inventory",
        quantity: 1,
        finish: "nonfoil"
      )

      # Attach cached image to each item
      item.cached_image.attach(
        io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
        filename: "card_#{i}.jpg",
        content_type: "image/jpeg"
      )

      # Create price data for each card
      CardPrice.create!(
        card_id: "eager_card_#{i}",
        fetched_at: 1.hour.ago,
        usd_cents: 100 + i
      )

      # Stub Scryfall API for each card
      stub_scryfall_card_details("eager_card_#{i}", name: "Test Card #{i}")
    end

    # Count queries during the request
    queries = track_queries do
      get api_path("/inventory")
    end

    assert_response :success
    items = parse_inventory_response
    assert_equal 20, items.size

    # With eager loading, we should have:
    # 1. SELECT collection_items with includes
    # 2. SELECT active_storage_attachments (eager loaded)
    # 3. SELECT active_storage_blobs (eager loaded)
    # 4-23. SELECT card details from Scryfall cache (one per card - external API, not DB)
    # Total DB queries should be <= 10 (accounting for schema queries, etc.)

    db_queries = queries.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }

    # With N+1, this would be 60+ queries (20 items × 3 queries each)
    # With eager loading, should be < 10 queries
    assert db_queries.size < 10,
           "Expected fewer than 10 DB queries with eager loading, but got #{db_queries.size}.\nQueries:\n#{db_queries.join("\n")}"
  end

  test "GET /api/inventory query count remains constant regardless of inventory size" do
    # Test with 5 items
    5.times do |i|
      item = CollectionItem.create!(
        user: @user,
        card_id: "size_test_5_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      item.cached_image.attach(
        io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
        filename: "card_#{i}.jpg",
        content_type: "image/jpeg"
      )
      CardPrice.create!(card_id: "size_test_5_#{i}", fetched_at: 1.hour.ago, usd_cents: 100)
      stub_scryfall_card_details("size_test_5_#{i}", name: "Card #{i}")
    end

    queries_5 = track_queries do
      get api_path("/inventory")
    end
    db_queries_5 = queries_5.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }.size

    # Clean up and test with 50 items
    CollectionItem.delete_all
    50.times do |i|
      item = CollectionItem.create!(
        user: @user,
        card_id: "size_test_50_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      item.cached_image.attach(
        io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
        filename: "card_#{i}.jpg",
        content_type: "image/jpeg"
      )
      CardPrice.create!(card_id: "size_test_50_#{i}", fetched_at: 1.hour.ago, usd_cents: 100)
      stub_scryfall_card_details("size_test_50_#{i}", name: "Card #{i}")
    end

    queries_50 = track_queries do
      get api_path("/inventory")
    end
    db_queries_50 = queries_50.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }.size

    # Query count should be the same (O(1)) regardless of collection size
    # Allow small variance for potential caching differences
    assert_in_delta db_queries_5, db_queries_50, 2,
           "Query count should remain constant. 5 items: #{db_queries_5}, 50 items: #{db_queries_50}"
  end

  test "GET /api/inventory eager loading works with empty inventory" do
    # Ensure no errors when inventory is empty
    queries = track_queries do
      get api_path("/inventory")
    end

    assert_response :success
    items = parse_inventory_response
    assert_equal 0, items.size

    # Should still use eager loading query structure even with no results
    # Stats calculation adds 2 queries (most_valuable_card, most_collected_set)
    db_queries = queries.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }
    assert db_queries.size < 8,
           "Empty inventory should require minimal queries, got #{db_queries.size}"
  end

  test "GET /api/inventory eager loads cached_image attachments and blobs" do
    # Create items with and without cached images
    item_with_cache = CollectionItem.create!(
      user: @user,
      card_id: "cached_test",
      collection_type: "inventory",
      quantity: 1
    )
    item_with_cache.cached_image.attach(
      io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
      filename: "cached.jpg",
      content_type: "image/jpeg"
    )

    item_without_cache = CollectionItem.create!(
      user: @user,
      card_id: "uncached_test",
      collection_type: "inventory",
      quantity: 1
    )

    stub_scryfall_card_details("cached_test", name: "Cached Card")
    stub_scryfall_card_details("uncached_test", name: "Uncached Card")

    queries = track_queries do
      get api_path("/inventory")
    end

    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size

    # Verify that ActiveStorage associations were eager loaded
    # Should not see individual SELECT queries for attachments or blobs per item
    attachment_queries = queries.select { |q| q.match?(/SELECT.*active_storage_attachments/i) }
    blob_queries = queries.select { |q| q.match?(/SELECT.*active_storage_blobs/i) }

    # With eager loading, should have at most 1 query for attachments and 1 for blobs
    assert attachment_queries.size <= 1,
           "Expected at most 1 query for attachments, got #{attachment_queries.size}"
    assert blob_queries.size <= 1,
           "Expected at most 1 query for blobs, got #{blob_queries.size}"
  end

  test "GET /api/inventory achieves 60% query reduction compared to N+1 pattern" do
    # Baseline: Create 20 items to establish expected query count
    20.times do |i|
      item = CollectionItem.create!(
        user: @user,
        card_id: "baseline_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      item.cached_image.attach(
        io: StringIO.new("\xFF\xD8\xFF\xE0\x00\x10JFIF".b),
        filename: "card_#{i}.jpg",
        content_type: "image/jpeg"
      )
      CardPrice.create!(card_id: "baseline_#{i}", fetched_at: 1.hour.ago, usd_cents: 100)
      stub_scryfall_card_details("baseline_#{i}", name: "Card #{i}")
    end

    queries = track_queries do
      get api_path("/inventory")
    end

    assert_response :success

    db_queries = queries.select { |q| q.match?(/SELECT.*FROM/i) && !q.match?(/sqlite_master|PRAGMA/) }

    # N+1 pattern would produce approximately:
    # - 1 query for collection_items
    # - 20 queries for active_storage_attachments (1 per item)
    # - 20 queries for active_storage_blobs (1 per item)
    # Total: ~41 queries
    #
    # With eager loading, we should have ~4 queries (60% reduction target):
    # - 1 for collection_items with includes
    # - 1 for active_storage_attachments
    # - 1 for active_storage_blobs
    # - A few for internal Rails queries

    n_plus_1_expected = 41
    target_query_count = n_plus_1_expected * 0.4  # 60% reduction = 40% remaining

    assert db_queries.size <= target_query_count,
           "Expected #{target_query_count} or fewer queries (60% reduction from #{n_plus_1_expected}), " \
           "but got #{db_queries.size} queries"
  end

  # ---------------------------------------------------------------------------
  # #index with sorting -- global sort before pagination (Issue #163)
  # ---------------------------------------------------------------------------

  test "GET /api/inventory with sort parameter sorts by card name ascending" do
    CollectionItem.create!(user: @user, card_id: "uuid-zzz", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-aaa", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-mmm", collection_type: "inventory", quantity: 1)

    stub_scryfall_card_details("uuid-zzz", name: "Zombie Token")
    stub_scryfall_card_details("uuid-aaa", name: "Ancient Tomb")
    stub_scryfall_card_details("uuid-mmm", name: "Mox Pearl")

    get api_path("/inventory?sort=name-asc")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "Ancient Tomb", items[0]["card_name"]
    assert_equal "Mox Pearl", items[1]["card_name"]
    assert_equal "Zombie Token", items[2]["card_name"]
    assert_equal "name-asc", body["sort"]
  end

  test "GET /api/inventory with sort parameter sorts by card name descending" do
    CollectionItem.create!(user: @user, card_id: "uuid-zzz", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-aaa", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-mmm", collection_type: "inventory", quantity: 1)

    stub_scryfall_card_details("uuid-zzz", name: "Zombie Token")
    stub_scryfall_card_details("uuid-aaa", name: "Ancient Tomb")
    stub_scryfall_card_details("uuid-mmm", name: "Mox Pearl")

    get api_path("/inventory?sort=name-desc")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "Zombie Token", items[0]["card_name"]
    assert_equal "Mox Pearl", items[1]["card_name"]
    assert_equal "Ancient Tomb", items[2]["card_name"]
    assert_equal "name-desc", body["sort"]
  end

  test "GET /api/inventory with sort parameter sorts by set name ascending" do
    CollectionItem.create!(user: @user, card_id: "uuid-1", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-2", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-3", collection_type: "inventory", quantity: 1)

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-1")
      .to_return(status: 200, body: { id: "uuid-1", name: "Card 1", set: "ZNR", set_name: "Zendikar Rising", collector_number: "1", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-2")
      .to_return(status: 200, body: { id: "uuid-2", name: "Card 2", set: "AFR", set_name: "Adventures in the Forgotten Realms", collector_number: "2", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-3")
      .to_return(status: 200, body: { id: "uuid-3", name: "Card 3", set: "MID", set_name: "Midnight Hunt", collector_number: "3", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })

    get api_path("/inventory?sort=set-asc")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "Adventures in the Forgotten Realms", items[0]["set_name"]
    assert_equal "Midnight Hunt", items[1]["set_name"]
    assert_equal "Zendikar Rising", items[2]["set_name"]
    assert_equal "set-asc", body["sort"]
  end

  test "GET /api/inventory with sort parameter sorts by release date newest first" do
    CollectionItem.create!(user: @user, card_id: "uuid-old", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-new", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-mid", collection_type: "inventory", quantity: 1)

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-old")
      .to_return(status: 200, body: { id: "uuid-old", name: "Old Card", set: "LEA", set_name: "Alpha", collector_number: "1", released_at: "1993-08-05", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-new")
      .to_return(status: 200, body: { id: "uuid-new", name: "New Card", set: "BRO", set_name: "Brothers War", collector_number: "2", released_at: "2022-11-18", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-mid")
      .to_return(status: 200, body: { id: "uuid-mid", name: "Mid Card", set: "M21", set_name: "Core 2021", collector_number: "3", released_at: "2020-07-03", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })

    get api_path("/inventory?sort=release-newest")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "New Card", items[0]["card_name"]
    assert_equal "Mid Card", items[1]["card_name"]
    assert_equal "Old Card", items[2]["card_name"]
    assert_equal "release-newest", body["sort"]
  end

  test "GET /api/inventory with sort parameter sorts by release date oldest first" do
    # Supply all metadata fields directly to bypass the Scryfall API callback,
    # avoiding parallel test interference on shared card IDs.
    CollectionItem.create!(user: @user, card_id: "uuid-old", collection_type: "inventory", quantity: 1,
                           card_name: "Old Card", set_name: "Alpha", released_at: "1993-08-05")
    CollectionItem.create!(user: @user, card_id: "uuid-new", collection_type: "inventory", quantity: 1,
                           card_name: "New Card", set_name: "Brothers War", released_at: "2022-11-18")
    CollectionItem.create!(user: @user, card_id: "uuid-mid", collection_type: "inventory", quantity: 1,
                           card_name: "Mid Card", set_name: "Core 2021", released_at: "2020-07-03")

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-old")
      .to_return(status: 200, body: { id: "uuid-old", name: "Old Card", set: "LEA", set_name: "Alpha", collector_number: "1", released_at: "1993-08-05", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-new")
      .to_return(status: 200, body: { id: "uuid-new", name: "New Card", set: "BRO", set_name: "Brothers War", collector_number: "2", released_at: "2022-11-18", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-mid")
      .to_return(status: 200, body: { id: "uuid-mid", name: "Mid Card", set: "M21", set_name: "Core 2021", collector_number: "3", released_at: "2020-07-03", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })

    get api_path("/inventory?sort=release-oldest")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "Old Card", items[0]["card_name"]
    assert_equal "Mid Card", items[1]["card_name"]
    assert_equal "New Card", items[2]["card_name"]
    assert_equal "release-oldest", body["sort"]
  end

  test "GET /api/inventory with sort parameter sorts by value highest first" do
    # Supply all metadata fields directly to bypass the Scryfall API callback,
    # avoiding parallel test interference on shared card IDs.
    item1 = CollectionItem.create!(user: @user, card_id: "uuid-cheap", collection_type: "inventory", quantity: 1, finish: "nonfoil",
                                   card_name: "Cheap Card", set_name: "Test Set", released_at: "2020-01-01")
    item2 = CollectionItem.create!(user: @user, card_id: "uuid-expensive", collection_type: "inventory", quantity: 2, finish: "nonfoil",
                                   card_name: "Expensive Card", set_name: "Test Set", released_at: "2020-01-01")
    item3 = CollectionItem.create!(user: @user, card_id: "uuid-medium", collection_type: "inventory", quantity: 1, finish: "nonfoil",
                                   card_name: "Medium Card", set_name: "Test Set", released_at: "2020-01-01")

    CardPrice.create!(card_id: "uuid-cheap", fetched_at: 1.hour.ago, usd_cents: 50)
    CardPrice.create!(card_id: "uuid-expensive", fetched_at: 1.hour.ago, usd_cents: 1000)
    CardPrice.create!(card_id: "uuid-medium", fetched_at: 1.hour.ago, usd_cents: 500)

    stub_scryfall_card_details("uuid-cheap", name: "Cheap Card")
    stub_scryfall_card_details("uuid-expensive", name: "Expensive Card")
    stub_scryfall_card_details("uuid-medium", name: "Medium Card")

    get api_path("/inventory?sort=value-high")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    # Expensive card: 2 × 1000 = 2000 cents
    # Medium card: 1 × 500 = 500 cents
    # Cheap card: 1 × 50 = 50 cents
    assert_equal "Expensive Card", items[0]["card_name"]
    assert_equal 2000, items[0]["total_price_cents"]
    assert_equal "Medium Card", items[1]["card_name"]
    assert_equal 500, items[1]["total_price_cents"]
    assert_equal "Cheap Card", items[2]["card_name"]
    assert_equal 50, items[2]["total_price_cents"]
    assert_equal "value-high", body["sort"]
  end

  test "GET /api/inventory with sort parameter sorts by value lowest first" do
    item1 = CollectionItem.create!(user: @user, card_id: "uuid-cheap", collection_type: "inventory", quantity: 1, finish: "nonfoil")
    item2 = CollectionItem.create!(user: @user, card_id: "uuid-expensive", collection_type: "inventory", quantity: 2, finish: "nonfoil")
    item3 = CollectionItem.create!(user: @user, card_id: "uuid-medium", collection_type: "inventory", quantity: 1, finish: "nonfoil")

    CardPrice.create!(card_id: "uuid-cheap", fetched_at: 1.hour.ago, usd_cents: 50)
    CardPrice.create!(card_id: "uuid-expensive", fetched_at: 1.hour.ago, usd_cents: 1000)
    CardPrice.create!(card_id: "uuid-medium", fetched_at: 1.hour.ago, usd_cents: 500)

    stub_scryfall_card_details("uuid-cheap", name: "Cheap Card")
    stub_scryfall_card_details("uuid-expensive", name: "Expensive Card")
    stub_scryfall_card_details("uuid-medium", name: "Medium Card")

    get api_path("/inventory?sort=value-low")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "Cheap Card", items[0]["card_name"]
    assert_equal "Medium Card", items[1]["card_name"]
    assert_equal "Expensive Card", items[2]["card_name"]
    assert_equal "value-low", body["sort"]
  end

  test "GET /api/inventory with sort parameter sorts by date added newest first" do
    CollectionItem.create!(user: @user, card_id: "uuid-old", collection_type: "inventory", quantity: 1, created_at: 7.days.ago)
    CollectionItem.create!(user: @user, card_id: "uuid-new", collection_type: "inventory", quantity: 1, created_at: 1.day.ago)
    CollectionItem.create!(user: @user, card_id: "uuid-mid", collection_type: "inventory", quantity: 1, created_at: 3.days.ago)

    stub_scryfall_card_details("uuid-old", name: "Old Card")
    stub_scryfall_card_details("uuid-new", name: "New Card")
    stub_scryfall_card_details("uuid-mid", name: "Mid Card")

    get api_path("/inventory?sort=date-newest")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "New Card", items[0]["card_name"]
    assert_equal "Mid Card", items[1]["card_name"]
    assert_equal "Old Card", items[2]["card_name"]
    assert_equal "date-newest", body["sort"]
  end

  test "GET /api/inventory with sort parameter sorts by date added oldest first" do
    CollectionItem.create!(user: @user, card_id: "uuid-old", collection_type: "inventory", quantity: 1, created_at: 7.days.ago)
    CollectionItem.create!(user: @user, card_id: "uuid-new", collection_type: "inventory", quantity: 1, created_at: 1.day.ago)
    CollectionItem.create!(user: @user, card_id: "uuid-mid", collection_type: "inventory", quantity: 1, created_at: 3.days.ago)

    stub_scryfall_card_details("uuid-old", name: "Old Card")
    stub_scryfall_card_details("uuid-new", name: "New Card")
    stub_scryfall_card_details("uuid-mid", name: "Mid Card")

    get api_path("/inventory?sort=date-oldest")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "Old Card", items[0]["card_name"]
    assert_equal "Mid Card", items[1]["card_name"]
    assert_equal "New Card", items[2]["card_name"]
    assert_equal "date-oldest", body["sort"]
  end

  test "GET /api/inventory with pagination and sort applies sort globally before pagination" do
    # Create 25 cards to test pagination (more than default page size of 20)
    25.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "uuid-#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      # Name them so they sort alphabetically: "Card 00", "Card 01", ..., "Card 24"
      stub_scryfall_card_details("uuid-#{i}", name: "Card #{i.to_s.rjust(2, '0')}")
    end

    # Request page 2 sorted by name descending
    get api_path("/inventory?page=2&per_page=10&sort=name-desc")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    # Page 2 should contain cards 11-20 in descending order (Card 14 to Card 05)
    assert_equal 10, items.size
    assert_equal "Card 14", items[0]["card_name"]
    assert_equal "Card 05", items[9]["card_name"]
    assert_equal 2, body["page"]
    assert_equal "name-desc", body["sort"]
  end

  test "GET /api/inventory defaults to name-asc when sort parameter not provided" do
    CollectionItem.create!(user: @user, card_id: "uuid-zzz", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-aaa", collection_type: "inventory", quantity: 1)

    stub_scryfall_card_details("uuid-zzz", name: "Zombie Token")
    stub_scryfall_card_details("uuid-aaa", name: "Ancient Tomb")

    get api_path("/inventory")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    assert_equal "Ancient Tomb", items[0]["card_name"]
    assert_equal "Zombie Token", items[1]["card_name"]
    assert_equal "name-asc", body["sort"]
  end

  test "GET /api/inventory handles invalid sort parameter by defaulting to name-asc" do
    CollectionItem.create!(user: @user, card_id: "uuid-zzz", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-aaa", collection_type: "inventory", quantity: 1)

    stub_scryfall_card_details("uuid-zzz", name: "Zombie Token")
    stub_scryfall_card_details("uuid-aaa", name: "Ancient Tomb")

    get api_path("/inventory?sort=invalid-option")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    # Should default to name-asc
    assert_equal "Ancient Tomb", items[0]["card_name"]
    assert_equal "Zombie Token", items[1]["card_name"]
    assert_equal "name-asc", body["sort"]
  end

  test "GET /api/inventory handles cards without price data when sorting by value" do
    item1 = CollectionItem.create!(user: @user, card_id: "uuid-priced", collection_type: "inventory", quantity: 1, finish: "nonfoil")
    item2 = CollectionItem.create!(user: @user, card_id: "uuid-no-price", collection_type: "inventory", quantity: 1)

    CardPrice.create!(card_id: "uuid-priced", fetched_at: 1.hour.ago, usd_cents: 500)
    # No price for uuid-no-price

    stub_scryfall_card_details("uuid-priced", name: "Priced Card")
    stub_scryfall_card_details("uuid-no-price", name: "No Price Card")

    get api_path("/inventory?sort=value-high")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    # Priced card should come first, unprice card should come last (treated as 0)
    assert_equal "Priced Card", items[0]["card_name"]
    assert_equal "No Price Card", items[1]["card_name"]
    assert_equal "value-high", body["sort"]
  end

  test "GET /api/inventory sorts foil cards by regular price when foil price is NULL" do
    # Bug fix: When a foil card has NULL usd_foil_cents, it should fall back to usd_cents for sorting
    item1 = CollectionItem.create!(user: @user, card_id: "uuid-foil-expensive", collection_type: "inventory", quantity: 1, finish: "foil")
    item2 = CollectionItem.create!(user: @user, card_id: "uuid-cheap", collection_type: "inventory", quantity: 1, finish: "nonfoil")
    item3 = CollectionItem.create!(user: @user, card_id: "uuid-foil-medium", collection_type: "inventory", quantity: 1, finish: "foil")

    # Foil cards have NULL foil prices but valid regular prices
    CardPrice.create!(card_id: "uuid-foil-expensive", fetched_at: 1.hour.ago, usd_cents: 2181, usd_foil_cents: nil)
    CardPrice.create!(card_id: "uuid-cheap", fetched_at: 1.hour.ago, usd_cents: 1424)
    CardPrice.create!(card_id: "uuid-foil-medium", fetched_at: 1.hour.ago, usd_cents: 1578, usd_foil_cents: nil)

    stub_scryfall_card_details("uuid-foil-expensive", name: "Deadly Rollick")
    stub_scryfall_card_details("uuid-cheap", name: "Bearscape")
    stub_scryfall_card_details("uuid-foil-medium", name: "Heartless Hidetsugu")

    get api_path("/inventory?sort=value-high")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    # Should sort by regular price when foil price is NULL
    assert_equal "Deadly Rollick", items[0]["card_name"], "Most expensive should be first"
    assert_equal 2181, items[0]["total_price_cents"], "Should use usd_cents when usd_foil_cents is NULL"
    assert_equal "Heartless Hidetsugu", items[1]["card_name"]
    assert_equal 1578, items[1]["total_price_cents"]
    assert_equal "Bearscape", items[2]["card_name"]
    assert_equal 1424, items[2]["total_price_cents"]
  end

  test "GET /api/inventory handles cards without release_at when sorting by release date" do
    CollectionItem.create!(user: @user, card_id: "uuid-with-date", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-no-date", collection_type: "inventory", quantity: 1)

    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-with-date")
      .to_return(status: 200, body: { id: "uuid-with-date", name: "With Date", set: "M21", set_name: "Core 2021", collector_number: "1", released_at: "2020-07-03", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "#{ApiEndpoints.scryfall_base}/cards/uuid-no-date")
      .to_return(status: 200, body: { id: "uuid-no-date", name: "No Date", set: "TST", set_name: "Test", collector_number: "2", image_uris: { normal: "url" } }.to_json, headers: { "Content-Type" => "application/json" })

    get api_path("/inventory?sort=release-newest")

    assert_response :success
    body = JSON.parse(response.body)
    items = body["items"]

    # Card with date should come first, card without date should come last
    assert_equal "With Date", items[0]["card_name"]
    assert_equal "No Date", items[1]["card_name"]
    assert_equal "release-newest", body["sort"]
  end

  # ---------------------------------------------------------------------------
  # DELETE action with pagination edge cases (Issue #171)
  # ---------------------------------------------------------------------------

  test "DELETE /api/inventory/:id returns correct pagination metadata after deletion" do
    # Create 25 items (more than one page at 20 per page)
    25.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "delete_page_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("delete_page_#{i}", name: "Delete Card #{i}")
    end

    # Get items on page 2 (items 20-24, which are 5 items)
    get api_path("/inventory?page=2&per_page=20")
    assert_response :success
    page2_before = JSON.parse(response.body)
    assert_equal 2, page2_before["page"]
    assert_equal 5, page2_before["items"].size
    assert_equal 25, page2_before["total_count"]
    assert_equal 2, page2_before["total_pages"]

    # Delete all 5 items on page 2
    page2_before["items"].each do |item|
      delete api_path("/inventory/#{item['id']}")
      assert_response :no_content
    end

    # Request page 2 again - should now show the last page correctly
    get api_path("/inventory?page=2&per_page=20")
    assert_response :success
    page2_after = JSON.parse(response.body)

    # After deleting 5 items, we have 20 items total
    # All 20 should be on page 1, so page 2 should be empty
    assert_equal 20, page2_after["total_count"], "Total count should be 20 after deleting 5 items"
    assert_equal 1, page2_after["total_pages"], "Should have only 1 page with 20 items"
    assert_equal 0, page2_after["items"].size, "Page 2 should be empty"
  end

  test "DELETE all items on middle page should show remaining items that shift up" do
    # Create 60 items (3 pages at 20 per page)
    60.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "shift_test_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("shift_test_#{i}", name: "Card #{i.to_s.rjust(2, '0')}")
    end

    # Get items on page 2 (items 20-39)
    get api_path("/inventory?page=2&per_page=20")
    assert_response :success
    page2_before = JSON.parse(response.body)
    assert_equal 20, page2_before["items"].size
    assert_equal 60, page2_before["total_count"]

    # Delete all 20 items on page 2
    page2_before["items"].each do |item|
      delete api_path("/inventory/#{item['id']}")
      assert_response :no_content
    end

    # Request page 2 again - should now show items that were previously on page 3
    get api_path("/inventory?page=2&per_page=20")
    assert_response :success
    page2_after = JSON.parse(response.body)

    # After deleting 20 items from middle, we have 40 items total (2 pages)
    assert_equal 40, page2_after["total_count"], "Total count should be 40 after deleting 20 items"
    assert_equal 2, page2_after["total_pages"], "Should have 2 pages with 40 items"
    assert_equal 20, page2_after["items"].size, "Page 2 should show 20 items that shifted up from page 3"
  end

  test "DELETE all items on last page redirects to previous page by returning correct metadata" do
    # Create 45 items (3 pages: 20, 20, 5)
    45.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "last_page_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("last_page_#{i}", name: "Last Page Card #{i}")
    end

    # Get items on page 3 (last 5 items)
    get api_path("/inventory?page=3&per_page=20")
    assert_response :success
    page3_before = JSON.parse(response.body)
    assert_equal 3, page3_before["page"]
    assert_equal 5, page3_before["items"].size
    assert_equal 45, page3_before["total_count"]
    assert_equal 3, page3_before["total_pages"]

    # Delete all 5 items on page 3
    page3_before["items"].each do |item|
      delete api_path("/inventory/#{item['id']}")
      assert_response :no_content
    end

    # Request page 3 again - should indicate that page 3 no longer exists
    get api_path("/inventory?page=3&per_page=20")
    assert_response :success
    page3_after = JSON.parse(response.body)

    # After deleting 5 items, we have 40 items total (2 pages)
    assert_equal 40, page3_after["total_count"], "Total count should be 40"
    assert_equal 2, page3_after["total_pages"], "Should have only 2 pages now"
    assert_equal 0, page3_after["items"].size, "Page 3 should be empty since it no longer exists"
  end

  test "DELETE all items when only one page exists shows empty inventory correctly" do
    # Create exactly 20 items (1 page)
    20.times do |i|
      CollectionItem.create!(
        user: @user,
        card_id: "single_page_#{i}",
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_card_details("single_page_#{i}", name: "Single Page Card #{i}")
    end

    # Get all items
    get api_path("/inventory?page=1&per_page=20")
    assert_response :success
    page1_before = JSON.parse(response.body)
    assert_equal 20, page1_before["items"].size
    assert_equal 20, page1_before["total_count"]
    assert_equal 1, page1_before["total_pages"]

    # Delete all 20 items
    page1_before["items"].each do |item|
      delete api_path("/inventory/#{item['id']}")
      assert_response :no_content
    end

    # Request page 1 again - should show empty inventory
    get api_path("/inventory?page=1&per_page=20")
    assert_response :success
    page1_after = JSON.parse(response.body)

    assert_equal 0, page1_after["total_count"], "Total count should be 0"
    assert_equal 0, page1_after["total_pages"], "Should have 0 pages"
    assert_equal 0, page1_after["items"].size, "Should have no items"
  end

  # ---------------------------------------------------------------------------
  # Foil/Nonfoil Separation Tests (Issue #166)
  # ---------------------------------------------------------------------------
  test "POST /api/inventory creates separate entries for foil and nonfoil versions" do
    stub_valid_card("lightning-bolt-123")
    stub_scryfall_card_details("lightning-bolt-123", name: "Lightning Bolt")

    # Create nonfoil version
    post api_path("/inventory"), params: {
      card_id: "lightning-bolt-123",
      quantity: 1,
      finish: "nonfoil"
    }
    assert_response :success

    # Create foil version - should succeed and create separate entry
    post api_path("/inventory"), params: {
      card_id: "lightning-bolt-123",
      quantity: 1,
      finish: "foil"
    }
    assert_response :success

    # Verify both entries exist
    get api_path("/inventory")
    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size, "Should have 2 separate entries for foil and nonfoil"

    finishes = items.map { |item| item["finish"] }.sort
    assert_equal [ "foil", "nonfoil" ], finishes
  end

  test "GET /api/inventory returns foil and nonfoil as separate line items" do
    # Create both versions
    CollectionItem.create!(
      user: @user,
      card_id: "test-card-456",
      collection_type: "inventory",
      quantity: 2,
      finish: "nonfoil"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "test-card-456",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    stub_scryfall_card_details("test-card-456", name: "Test Card")

    get api_path("/inventory")
    assert_response :success
    items = parse_inventory_response

    assert_equal 2, items.size, "Should return 2 separate line items"

    nonfoil_item = items.find { |item| item["finish"] == "nonfoil" }
    foil_item = items.find { |item| item["finish"] == "foil" }

    assert_not_nil nonfoil_item, "Should have nonfoil entry"
    assert_not_nil foil_item, "Should have foil entry"

    assert_equal 2, nonfoil_item["quantity"]
    assert_equal 1, foil_item["quantity"]
  end

  test "POST /api/inventory with same card and finish increments quantity" do
    stub_valid_card("duplicate-test-789")
    stub_scryfall_card_details("duplicate-test-789", name: "Duplicate Test")

    # Create first foil
    post api_path("/inventory"), params: {
      card_id: "duplicate-test-789",
      quantity: 1,
      finish: "foil"
    }
    assert_response :success

    # Add another foil - should upsert and increment quantity
    post api_path("/inventory"), params: {
      card_id: "duplicate-test-789",
      quantity: 2,
      finish: "foil"
    }
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 3, body["quantity"], "Quantity should be incremented (1 + 2)"
    assert_equal "foil", body["finish"]

    # Verify only one foil entry exists
    foil_items = CollectionItem.where(
      user: @user,
      card_id: "duplicate-test-789",
      collection_type: "inventory",
      finish: "foil"
    )
    assert_equal 1, foil_items.count, "Should have exactly one foil entry"
  end

  test "DELETE /api/inventory removes only the specific finish" do
    # Create both versions
    nonfoil = CollectionItem.create!(
      user: @user,
      card_id: "delete-test-abc",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil"
    )
    foil = CollectionItem.create!(
      user: @user,
      card_id: "delete-test-abc",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    stub_scryfall_card_details("delete-test-abc", name: "Delete Test")

    # Delete foil version
    delete api_path("/inventory/#{foil.id}")
    assert_response :no_content

    # Verify nonfoil still exists
    get api_path("/inventory")
    assert_response :success
    items = parse_inventory_response

    assert_equal 1, items.size, "Should have 1 item remaining"
    assert_equal "nonfoil", items.first["finish"]
    assert_equal nonfoil.id, items.first["id"]
  end

  test "GET /api/inventory/value includes both foil and nonfoil values" do
    # Create both versions with different prices
    CollectionItem.create!(
      user: @user,
      card_id: "value-test-def",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "value-test-def",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    # Create price data with different prices for foil/nonfoil
    CardPrice.create!(
      card_id: "value-test-def",
      fetched_at: 1.day.ago,
      usd_cents: 200,          # $2.00 nonfoil
      usd_foil_cents: 1000     # $10.00 foil
    )

    get api_path("/inventory/value")
    assert_response :success

    value_data = JSON.parse(response.body)
    # Total should be $12.00 (200 + 1000)
    assert_equal 1200, value_data["total_value_cents"]
    assert_equal 2, value_data["valued_cards"], "Should count both finishes"
  end

  test "GET /api/inventory sorts foil and nonfoil independently by value" do
    # Create foil version worth more than nonfoil
    CollectionItem.create!(
      user: @user,
      card_id: "sort-test-ghi",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "sort-test-ghi",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    CardPrice.create!(
      card_id: "sort-test-ghi",
      fetched_at: 1.day.ago,
      usd_cents: 100,          # $1.00 nonfoil
      usd_foil_cents: 5000     # $50.00 foil
    )

    stub_scryfall_card_details("sort-test-ghi", name: "Sort Test Card")

    get api_path("/inventory?sort=value-high")
    assert_response :success

    items = parse_inventory_response
    assert_equal 2, items.size

    # Foil should be first (higher value)
    assert_equal "foil", items[0]["finish"]
    assert_equal 5000, items[0]["unit_price_cents"]

    # Nonfoil should be second
    assert_equal "nonfoil", items[1]["finish"]
    assert_equal 100, items[1]["unit_price_cents"]
  end

  test "POST /api/inventory/move_from_wishlist respects finish parameter" do
    # Create foil in wishlist
    wishlist_foil = CollectionItem.create!(
      user: @user,
      card_id: "move-test-jkl",
      collection_type: "wishlist",
      quantity: 1,
      finish: "foil"
    )

    # Create nonfoil already in inventory
    inventory_nonfoil = CollectionItem.create!(
      user: @user,
      card_id: "move-test-jkl",
      collection_type: "inventory",
      quantity: 2,
      finish: "nonfoil"
    )

    post api_path("/inventory/move_from_wishlist"), params: {
      card_id: "move-test-jkl"
    }
    assert_response :created

    # Verify wishlist foil was moved
    assert_nil CollectionItem.find_by(id: wishlist_foil.id), "Wishlist item should be deleted"

    # Verify both finishes exist in inventory
    inventory_items = CollectionItem.where(
      user: @user,
      card_id: "move-test-jkl",
      collection_type: "inventory"
    )
    assert_equal 2, inventory_items.count, "Should have 2 items in inventory (foil and nonfoil)"

    finishes = inventory_items.pluck(:finish).sort
    assert_equal [ "foil", "nonfoil" ], finishes
  end

  test "GET /api/inventory includes finish in stats calculation" do
    # Create multiple cards with different finishes - foil is more valuable
    CollectionItem.create!(
      user: @user,
      card_id: "stats-card-1",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil",
      card_name: "Stats Card 1",
      set_name: "Test Set"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "stats-card-1",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil",
      card_name: "Stats Card 1",
      set_name: "Test Set"
    )

    CardPrice.create!(
      card_id: "stats-card-1",
      fetched_at: 1.day.ago,
      usd_cents: 500,
      usd_foil_cents: 1500
    )

    stub_scryfall_card_details("stats-card-1", name: "Stats Card 1")

    get api_path("/inventory")
    assert_response :success

    body = JSON.parse(response.body)
    stats = body["stats"]

    # Most valuable card should use foil price (1500) over nonfoil (500)
    assert_equal "Stats Card 1", stats["most_valuable_card"]
  end

  private

  # Helper method to track SQL queries during a block
  def track_queries
    queries = []
    query_subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA"
    end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(query_subscriber) if query_subscriber
  end

end
