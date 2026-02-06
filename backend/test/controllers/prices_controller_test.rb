require "test_helper"

class PricesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should trigger price update when cards exist" do
    # Create some collection items
    CollectionItem.create!(
      user: @user,
      card_id: "test-card-1",
      quantity: 1,
      collection_type: "inventory"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "test-card-2",
      quantity: 1,
      collection_type: "wishlist"
    )

    assert_enqueued_with(job: UpdateCardPricesJob) do
      post api_prices_update_url
    end

    assert_response :accepted

    json_response = JSON.parse(response.body)
    assert_equal "Price update job enqueued successfully", json_response["message"]
    assert_equal 2, json_response["cards_to_update"]
    assert_equal "processing", json_response["status"]
  end

  test "should handle empty collections gracefully" do
    # Ensure no collection items exist
    CollectionItem.delete_all

    assert_no_enqueued_jobs do
      post api_prices_update_url
    end

    assert_response :ok

    json_response = JSON.parse(response.body)
    assert_equal "No cards found in collections", json_response["message"]
    assert_equal 0, json_response["cards_to_update"]
  end

  test "should deduplicate cards across collections" do
    # Create duplicate card in different collections
    CollectionItem.create!(
      user: @user,
      card_id: "same-card",
      quantity: 1,
      collection_type: "inventory"
    )
    CollectionItem.create!(
      user: @user,
      card_id: "same-card",
      quantity: 2,
      collection_type: "wishlist"
    )

    post api_prices_update_url

    assert_response :accepted

    json_response = JSON.parse(response.body)
    # Should only count unique cards
    assert_equal 1, json_response["cards_to_update"]
  end

  test "should return proper content type" do
    post api_prices_update_url

    assert_equal "application/json; charset=utf-8", response.content_type
  end
end
