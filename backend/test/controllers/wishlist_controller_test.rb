require "test_helper"

class WishlistControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Setup -- ensure the seeded default user exists; all requests will be
  # scoped to that user via ApplicationController#current_user.
  # ---------------------------------------------------------------------------
  setup do
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
  end

  # ---------------------------------------------------------------------------
  # #index -- returns only current_user's wishlist items
  # ---------------------------------------------------------------------------
  test "GET /api/wishlist returns only current user's wishlist items" do
    CollectionItem.create!(user: @user, card_id: "wish_card", collection_type: "wishlist", quantity: 1)

    other_user = User.create!(email: "other_wish@example.com", name: "Other")
    CollectionItem.create!(user: other_user, card_id: "their_wish", collection_type: "wishlist", quantity: 1)

    get "/api/wishlist"

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size
    assert_equal "wish_card", items.first["card_id"]
  end

  test "GET /api/wishlist does not return inventory items" do
    CollectionItem.create!(user: @user, card_id: "inv_only", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "wish_only", collection_type: "wishlist", quantity: 1)

    get "/api/wishlist"

    assert_response :success
    items = JSON.parse(response.body)
    assert_equal 1, items.size
    assert_equal "wish_only", items.first["card_id"]
  end

  # ---------------------------------------------------------------------------
  # #create -- adds item or increments quantity on duplicate
  # ---------------------------------------------------------------------------
  test "POST /api/wishlist creates a new wishlist item" do
    post "/api/wishlist", params: { card_id: "new_wish", quantity: 1 }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "new_wish", body["card_id"]
    assert_equal "wishlist", body["collection_type"]
    assert_equal 1, body["quantity"]
    assert_equal @user.id, body["user_id"]
  end

  test "POST /api/wishlist increments quantity when card already exists in wishlist" do
    CollectionItem.create!(user: @user, card_id: "dup_wish", collection_type: "wishlist", quantity: 2)

    post "/api/wishlist", params: { card_id: "dup_wish", quantity: 1 }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 3, body["quantity"]
    assert_equal 1, CollectionItem.where(user: @user, card_id: "dup_wish", collection_type: "wishlist").count
  end

  test "POST /api/wishlist returns unprocessable_entity for missing card_id" do
    post "/api/wishlist", params: { quantity: 1 }, as: :json

    assert_response :unprocessable_entity
  end

  test "POST /api/wishlist returns unprocessable_entity for zero quantity" do
    post "/api/wishlist", params: { card_id: "zero_wish", quantity: 0 }, as: :json

    assert_response :unprocessable_entity
  end

  # ---------------------------------------------------------------------------
  # #update -- updates quantity on an existing item
  # ---------------------------------------------------------------------------
  test "PATCH /api/wishlist/:id updates quantity" do
    item = CollectionItem.create!(user: @user, card_id: "update_wish", collection_type: "wishlist", quantity: 1)

    patch "/api/wishlist/#{item.id}", params: { quantity: 7 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 7, body["quantity"]
  end

  test "PATCH /api/wishlist/:id returns not_found for another user's item" do
    other_user = User.create!(email: "other_wish_up@example.com", name: "Other")
    item = CollectionItem.create!(user: other_user, card_id: "cant_update", collection_type: "wishlist", quantity: 1)

    patch "/api/wishlist/#{item.id}", params: { quantity: 10 }, as: :json

    assert_response :not_found
  end

  test "PATCH /api/wishlist/:id returns unprocessable_entity for invalid quantity" do
    item = CollectionItem.create!(user: @user, card_id: "bad_wish_qty", collection_type: "wishlist", quantity: 1)

    patch "/api/wishlist/#{item.id}", params: { quantity: 0 }, as: :json

    assert_response :unprocessable_entity
  end

  # ---------------------------------------------------------------------------
  # #destroy -- removes item
  # ---------------------------------------------------------------------------
  test "DELETE /api/wishlist/:id removes the item" do
    item = CollectionItem.create!(user: @user, card_id: "del_wish", collection_type: "wishlist", quantity: 1)

    delete "/api/wishlist/#{item.id}"

    assert_response :success
    assert_equal 0, CollectionItem.where(id: item.id).count
  end

  test "DELETE /api/wishlist/:id returns not_found for another user's item" do
    other_user = User.create!(email: "other_wish_del@example.com", name: "Other")
    item = CollectionItem.create!(user: other_user, card_id: "cant_del_wish", collection_type: "wishlist", quantity: 1)

    delete "/api/wishlist/#{item.id}"

    assert_response :not_found
    assert_equal 1, CollectionItem.where(id: item.id).count
  end
end
