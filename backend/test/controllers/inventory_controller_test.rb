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
  # #update -- updates quantity on an existing item
  # ---------------------------------------------------------------------------
  test "PATCH /api/inventory/:id updates quantity" do
    item = CollectionItem.create!(user: @user, card_id: "update_card", collection_type: "inventory", quantity: 1)

    patch api_path("/inventory/#{item.id}"), params: { quantity: 5 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 5, body["quantity"]
    assert_equal 1, CollectionItem.where(user: @user, card_id: "update_card", collection_type: "inventory").count
  end

  test "PATCH /api/inventory/:id returns not_found for another user's item" do
    other_user = User.create!(email: "other_update@example.com", name: "Other")
    item = CollectionItem.create!(user: other_user, card_id: "other_card", collection_type: "inventory", quantity: 1)

    patch api_path("/inventory/#{item.id}"), params: { quantity: 10 }, as: :json

    assert_response :not_found
  end

  test "PATCH /api/inventory/:id returns unprocessable_entity for invalid quantity" do
    item = CollectionItem.create!(user: @user, card_id: "bad_update", collection_type: "inventory", quantity: 1)

    patch api_path("/inventory/#{item.id}"), params: { quantity: -1 }, as: :json

    assert_response :unprocessable_entity
  end

  # ---------------------------------------------------------------------------
  # #destroy -- removes item
  # ---------------------------------------------------------------------------
  test "DELETE /api/inventory/:id removes the item" do
    item = CollectionItem.create!(user: @user, card_id: "delete_card", collection_type: "inventory", quantity: 1)

    delete api_path("/inventory/#{item.id}")

    assert_response :success
    assert_equal 0, CollectionItem.where(id: item.id).count
  end

  test "DELETE /api/inventory/:id returns not_found for another user's item" do
    other_user = User.create!(email: "other_delete@example.com", name: "Other")
    item = CollectionItem.create!(user: other_user, card_id: "cant_delete", collection_type: "inventory", quantity: 1)

    delete api_path("/inventory/#{item.id}")

    assert_response :not_found
    assert_equal 1, CollectionItem.where(id: item.id).count
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

  private

end
