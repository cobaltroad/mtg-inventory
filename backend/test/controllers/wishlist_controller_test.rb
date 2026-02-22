require "test_helper"
require "webmock/minitest"

class WishlistControllerTest < ActionDispatch::IntegrationTest
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
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  # Stubs Scryfall API to validate a card ID
  def stub_valid_card(card_id)
    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/#{card_id}/)
      .to_return(
        status: 200,
        body: { id: card_id, name: "Test Card" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # Stubs Scryfall API to return card details
  def stub_scryfall_card_details(card_id, name: "Black Lotus")
    stub_request(:get, /#{Regexp.escape(ApiEndpoints.scryfall_base)}\/cards\/#{card_id}/)
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: "LEA",
          set_name: "Limited Edition Alpha",
          collector_number: "234",
          released_at: "1993-08-05",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ---------------------------------------------------------------------------
  # #index -- returns only current_user's wishlist items
  # ---------------------------------------------------------------------------
  test "GET /api/wishlist returns only current user's wishlist items" do
    CollectionItem.create!(user: @user, card_id: "wish_card", collection_type: "wishlist", quantity: 1)

    other_user = User.create!(email: "other_wish@example.com", name: "Other")
    CollectionItem.create!(user: other_user, card_id: "their_wish", collection_type: "wishlist", quantity: 1)

    stub_scryfall_card_details("wish_card", name: "Wish Card")

    get api_path("/wishlist")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size
    assert_equal "wish_card", items.first["card_id"]
  end

  test "GET /api/wishlist does not return inventory items" do
    CollectionItem.create!(user: @user, card_id: "inv_only", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "wish_only", collection_type: "wishlist", quantity: 1)

    stub_scryfall_card_details("wish_only", name: "Wish Only Card")

    get api_path("/wishlist")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size
    assert_equal "wish_only", items.first["card_id"]
  end

  # ---------------------------------------------------------------------------
  # #create -- adds item or increments quantity on duplicate
  # ---------------------------------------------------------------------------
  test "POST /api/wishlist creates a new wishlist item" do
    stub_valid_card("new_wish")

    post api_path("/wishlist"), params: { card_id: "new_wish", quantity: 1 }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "new_wish", body["card_id"]
    assert_equal "wishlist", body["collection_type"]
    assert_equal 1, body["quantity"]
    assert_equal @user.id, body["user_id"]
  end

  test "POST /api/wishlist increments quantity when card already exists in wishlist" do
    CollectionItem.create!(user: @user, card_id: "dup_wish", collection_type: "wishlist", quantity: 2)

    stub_valid_card("dup_wish")

    post api_path("/wishlist"), params: { card_id: "dup_wish", quantity: 1 }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 3, body["quantity"]
    assert_equal 1, CollectionItem.where(user: @user, card_id: "dup_wish", collection_type: "wishlist").count
  end

  test "POST /api/wishlist returns unprocessable_entity for missing card_id" do
    post api_path("/wishlist"), params: { quantity: 1 }, as: :json

    assert_response :unprocessable_entity
  end

  test "POST /api/wishlist returns unprocessable_entity for zero quantity" do
    stub_valid_card("zero_wish")

    post api_path("/wishlist"), params: { card_id: "zero_wish", quantity: 0 }, as: :json

    assert_response :unprocessable_entity
  end

  # ---------------------------------------------------------------------------
  # #update -- updates quantity on an existing item
  # ---------------------------------------------------------------------------
  test "PATCH /api/wishlist/:id updates quantity" do
    item = CollectionItem.create!(user: @user, card_id: "update_wish", collection_type: "wishlist", quantity: 1)

    patch api_path("/wishlist/#{item.id}"), params: { quantity: 7 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 7, body["quantity"]
  end

  test "PATCH /api/wishlist/:id returns not_found for another user's item" do
    other_user = User.create!(email: "other_wish_up@example.com", name: "Other")
    item = CollectionItem.create!(user: other_user, card_id: "cant_update", collection_type: "wishlist", quantity: 1)

    patch api_path("/wishlist/#{item.id}"), params: { quantity: 10 }, as: :json

    assert_response :not_found
  end

  test "PATCH /api/wishlist/:id returns unprocessable_entity for invalid quantity" do
    item = CollectionItem.create!(user: @user, card_id: "bad_wish_qty", collection_type: "wishlist", quantity: 1)

    patch api_path("/wishlist/#{item.id}"), params: { quantity: 0 }, as: :json

    assert_response :unprocessable_entity
  end

  # ---------------------------------------------------------------------------
  # #destroy -- removes item
  # ---------------------------------------------------------------------------
  test "DELETE /api/wishlist/:id removes the item" do
    item = CollectionItem.create!(user: @user, card_id: "del_wish", collection_type: "wishlist", quantity: 1)

    delete api_path("/wishlist/#{item.id}")

    assert_response :success
    assert_equal 0, CollectionItem.where(id: item.id).count
  end

  test "DELETE /api/wishlist/:id returns not_found for another user's item" do
    other_user = User.create!(email: "other_wish_del@example.com", name: "Other")
    item = CollectionItem.create!(user: other_user, card_id: "cant_del_wish", collection_type: "wishlist", quantity: 1)

    delete api_path("/wishlist/#{item.id}")

    assert_response :not_found
    assert_equal 1, CollectionItem.where(id: item.id).count
  end

  # ---------------------------------------------------------------------------
  # #index with card details enrichment -- wishlist-specific behavior
  # ---------------------------------------------------------------------------
  test "GET /api/wishlist includes card details from Scryfall API" do
    CollectionItem.create!(user: @user, card_id: "uuid-wish-123", collection_type: "wishlist", quantity: 3)

    stub_scryfall_card_details("uuid-wish-123", name: "Wishlist Card")

    get api_path("/wishlist")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    item = items.first
    assert_equal "uuid-wish-123", item["card_id"]
    assert_equal 3, item["quantity"]
    assert_equal "Wishlist Card", item["card_name"]
    assert_equal "LEA", item["set"]
    assert_equal "Limited Edition Alpha", item["set_name"]
    assert_equal "234", item["collector_number"]
  end

  test "GET /api/wishlist excludes acquired_date and acquired_price_cents fields" do
    CollectionItem.create!(
      user: @user,
      card_id: "wish_no_acquire",
      collection_type: "wishlist",
      quantity: 2
    )

    stub_scryfall_card_details("wish_no_acquire", name: "Wish Card")

    get api_path("/wishlist")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    item = items.first
    assert_nil item["acquired_date"], "Wishlist items should not include acquired_date"
    assert_nil item["acquired_price_cents"], "Wishlist items should not include acquired_price_cents"
  end

  test "GET /api/wishlist includes current market price" do
    CollectionItem.create!(
      user: @user,
      card_id: "wish_priced",
      collection_type: "wishlist",
      quantity: 2
    )

    CardPrice.create!(
      card_id: "wish_priced",
      fetched_at: 1.hour.ago,
      usd_cents: 500
    )

    stub_scryfall_card_details("wish_priced", name: "Priced Wish Card")

    get api_path("/wishlist")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size

    item = items.first
    assert_equal 500, item["unit_price_cents"]
    assert_equal 1000, item["total_price_cents"]
    assert_not_nil item["price_updated_at"]
  end

  test "GET /api/wishlist returns items sorted alphabetically by card name" do
    CollectionItem.create!(user: @user, card_id: "uuid-zzz", collection_type: "wishlist", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-aaa", collection_type: "wishlist", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "uuid-mmm", collection_type: "wishlist", quantity: 1)

    stub_scryfall_card_details("uuid-zzz", name: "Zombie Token")
    stub_scryfall_card_details("uuid-aaa", name: "Ancient Tomb")
    stub_scryfall_card_details("uuid-mmm", name: "Mox Pearl")

    get api_path("/wishlist")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 3, items.size

    # Verify alphabetical order
    assert_equal "Ancient Tomb", items[0]["card_name"]
    assert_equal "Mox Pearl", items[1]["card_name"]
    assert_equal "Zombie Token", items[2]["card_name"]
  end

  test "GET /api/wishlist returns empty array when wishlist is empty" do
    get api_path("/wishlist")

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 0, items.size
  end

  test "POST /api/wishlist allows same card in both inventory and wishlist" do
    CollectionItem.create!(user: @user, card_id: "dual_card", collection_type: "inventory", quantity: 1)

    stub_valid_card("dual_card")

    post api_path("/wishlist"), params: { card_id: "dual_card", quantity: 2 }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "dual_card", body["card_id"]
    assert_equal "wishlist", body["collection_type"]
    assert_equal 2, body["quantity"]

    # Both records should exist
    assert_equal 1, CollectionItem.where(user: @user, card_id: "dual_card", collection_type: "inventory").count
    assert_equal 1, CollectionItem.where(user: @user, card_id: "dual_card", collection_type: "wishlist").count
  end

  test "DELETE /api/wishlist/:id does not affect current user's inventory items" do
    inventory_item = CollectionItem.create!(user: @user, card_id: "shared_card", collection_type: "inventory", quantity: 1)
    wishlist_item = CollectionItem.create!(user: @user, card_id: "shared_card", collection_type: "wishlist", quantity: 2)

    delete api_path("/wishlist/#{wishlist_item.id}")

    assert_response :success

    # Wishlist item should be deleted
    assert_equal 0, CollectionItem.where(id: wishlist_item.id).count

    # Inventory item should still exist
    assert_equal 1, CollectionItem.where(id: inventory_item.id).count
    inventory_item.reload
    assert_equal 1, inventory_item.quantity
  end
end
