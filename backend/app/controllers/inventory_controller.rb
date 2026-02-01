class InventoryController < ApplicationController
  include CollectionItemActions

  # Transfers a card from the user's wishlist to their inventory.
  # If an inventory row already exists for the card, its quantity is
  # incremented by the wishlist quantity.  The entire operation runs in a
  # single transaction so a failure after the wishlist deletion cannot
  # leave orphaned state.
  def move_from_wishlist
    card_id = params[:card_id]
    wishlist_item = current_user.collection_items.find_by(card_id: card_id, collection_type: "wishlist")

    unless wishlist_item
      render json: { error: "Not found in wishlist" }, status: :not_found
      return
    end

    inventory_item = CollectionItem.transaction do
      qty = wishlist_item.quantity
      wishlist_item.destroy!

      existing = current_user.collection_items.find_by(card_id: card_id, collection_type: "inventory")

      if existing
        existing.update!(quantity: existing.quantity + qty)
        existing
      else
        current_user.collection_items.create!(
          card_id: card_id,
          collection_type: "inventory",
          quantity: qty
        )
      end
    end

    render json: inventory_item, status: :created
  end

  private

  def collection_type
    "inventory"
  end
end
