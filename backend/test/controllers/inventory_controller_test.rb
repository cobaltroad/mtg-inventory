require "test_helper"
require "webmock/minitest"

class InventoryControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Setup -- ensure the seeded default user exists; all requests will be
  # scoped to that user via ApplicationController#current_user.
  # ---------------------------------------------------------------------------
  setup do
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
    WebMock.reset!
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

  # ---------------------------------------------------------------------------
  # #index -- returns only current_user's inventory items
  # ---------------------------------------------------------------------------
  test "GET /api/inventory returns only current user's inventory items" do
    CollectionItem.create!(user: @user, card_id: "my_card", collection_type: "inventory", quantity: 2)

    other_user = User.create!(email: "other@example.com", name: "Other")
    CollectionItem.create!(user: other_user, card_id: "their_card", collection_type: "inventory", quantity: 1)

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size
    assert_equal "my_card", items.first["card_id"]
  end

  test "GET /api/inventory does not return wishlist items" do
    CollectionItem.create!(user: @user, card_id: "inv_card", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "wish_card", collection_type: "wishlist", quantity: 1)

    get api_path("/inventory")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size
    assert_equal "inv_card", items.first["card_id"]
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

  private

end
