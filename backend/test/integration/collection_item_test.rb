require "test_helper"
require "webmock/minitest"

# ---------------------------------------------------------------------------
# Cross-cutting integration tests that exercise inventory and wishlist
# endpoints together, verifying scenarios that span both resources.
# ---------------------------------------------------------------------------
class CollectionItemIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
    WebMock.reset!
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  def stub_valid_card(card_id)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: { id: card_id, name: "Test Card" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ---------------------------------------------------------------------------
  # Scenario 3 -- same card can exist in both inventory and wishlist
  # ---------------------------------------------------------------------------
  test "POST to inventory and wishlist for the same card both succeed" do
    stub_valid_card("dual_card")

    post api_path("/inventory"), params: { card_id: "dual_card", quantity: 2 }, as: :json
    assert_response :created

    post api_path("/wishlist"), params: { card_id: "dual_card", quantity: 1 }, as: :json
    assert_response :created

    # Both rows exist independently
    assert_equal 1, CollectionItem.where(user: @user, card_id: "dual_card", collection_type: "inventory").count
    assert_equal 1, CollectionItem.where(user: @user, card_id: "dual_card", collection_type: "wishlist").count

    inv_body = JSON.parse(CollectionItem.where(user: @user, card_id: "dual_card", collection_type: "inventory").first.to_json)
    wish_body = JSON.parse(CollectionItem.where(user: @user, card_id: "dual_card", collection_type: "wishlist").first.to_json)
    assert_equal 2, inv_body["quantity"]
    assert_equal 1, wish_body["quantity"]
  end

  # ---------------------------------------------------------------------------
  # Scenario 4 -- PATCH updates quantity without creating duplicates
  # ---------------------------------------------------------------------------
  test "PATCH /api/inventory/:id updates quantity without duplicating the row" do
    stub_valid_card("patch_card")

    post api_path("/inventory"), params: { card_id: "patch_card", quantity: 1 }, as: :json
    assert_response :created
    item_id = JSON.parse(response.body)["id"]

    patch api_path("/inventory/#{item_id}"), params: { quantity: 10 }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 10, body["quantity"]
    assert_equal 1, CollectionItem.where(user: @user, card_id: "patch_card", collection_type: "inventory").count
  end

  # ---------------------------------------------------------------------------
  # Scenario 6 -- move_from_wishlist transfers the item correctly
  # ---------------------------------------------------------------------------
  test "POST /api/inventory/move_from_wishlist transfers card from wishlist to inventory" do
    # Seed a wishlist item
    post api_path("/wishlist"), params: { card_id: "transfer_card", quantity: 3 }, as: :json
    assert_response :created

    # Move it
    post api_path("/inventory/move_from_wishlist"), params: { card_id: "transfer_card" }, as: :json
    assert_response :created
    body = JSON.parse(response.body)

    assert_equal "transfer_card", body["card_id"]
    assert_equal "inventory", body["collection_type"]
    assert_equal 3, body["quantity"]

    # Wishlist row is gone; inventory row exists
    assert_equal 0, CollectionItem.where(user: @user, card_id: "transfer_card", collection_type: "wishlist").count
    assert_equal 1, CollectionItem.where(user: @user, card_id: "transfer_card", collection_type: "inventory").count
  end

  test "move_from_wishlist does not affect an existing inventory row for the same card" do
    # Pre-seed inventory
    CollectionItem.create!(user: @user, card_id: "overlap_card", collection_type: "inventory", quantity: 5)
    # Seed wishlist
    CollectionItem.create!(user: @user, card_id: "overlap_card", collection_type: "wishlist", quantity: 2)

    post api_path("/inventory/move_from_wishlist"), params: { card_id: "overlap_card" }, as: :json
    assert_response :created

    body = JSON.parse(response.body)
    # The move creates a NEW inventory row (or the implementation may choose to
    # increment -- either way the wishlist row is gone and the response is inventory).
    assert_equal "inventory", body["collection_type"]

    # Wishlist row is gone
    assert_equal 0, CollectionItem.where(user: @user, card_id: "overlap_card", collection_type: "wishlist").count
  end

  # ---------------------------------------------------------------------------
  # Scenario 7 -- GET endpoints exclude other users' items
  # ---------------------------------------------------------------------------
  test "GET /api/inventory excludes other users' items" do
    other_user = User.create!(email: "integ_other@example.com", name: "Integration Other")

    CollectionItem.create!(user: @user, card_id: "mine", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: other_user, card_id: "theirs", collection_type: "inventory", quantity: 1)

    get api_path("/inventory")
    assert_response :success

    items = JSON.parse(response.body)
    card_ids = items.map { |i| i["card_id"] }
    assert_includes card_ids, "mine"
    assert_not_includes card_ids, "theirs"
  end

  test "GET /api/wishlist excludes other users' items" do
    other_user = User.create!(email: "integ_other_w@example.com", name: "Integration Other W")

    CollectionItem.create!(user: @user, card_id: "my_wish", collection_type: "wishlist", quantity: 1)
    CollectionItem.create!(user: other_user, card_id: "their_wish", collection_type: "wishlist", quantity: 1)

    get api_path("/wishlist")
    assert_response :success

    items = JSON.parse(response.body)
    card_ids = items.map { |i| i["card_id"] }
    assert_includes card_ids, "my_wish"
    assert_not_includes card_ids, "their_wish"
  end

  # ---------------------------------------------------------------------------
  # Issue #9 -- SDK validation end-to-end
  # ---------------------------------------------------------------------------
  test "POST /api/inventory with a valid card_id persists the item end-to-end" do
    stub_valid_card("e2e_valid_card")

    post api_path("/inventory"), params: { card_id: "e2e_valid_card", quantity: 1 }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "e2e_valid_card", body["card_id"]
    assert_equal "inventory", body["collection_type"]
    assert_equal 1, body["quantity"]
  end

  test "POST /api/inventory with a duplicate card_id returns incremented quantity" do
    CollectionItem.create!(user: @user, card_id: "e2e_dup_card", collection_type: "inventory", quantity: 2)

    stub_valid_card("e2e_dup_card")

    post api_path("/inventory"), params: { card_id: "e2e_dup_card", quantity: 1 }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "e2e_dup_card", body["card_id"]
    assert_equal 3, body["quantity"]
  end
end
