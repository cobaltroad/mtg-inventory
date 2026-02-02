class InventoryController < ApplicationController
  include CollectionItemActions

  before_action :validate_card_with_sdk, only: [ :create ]

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

  # Verify the card exists in Scryfall before we persist anything.
  # When card_id is blank we let the model validation surface that error
  # instead of hitting Scryfall with an empty string.
  def validate_card_with_sdk
    return if card_id_param.blank?

    CardValidatorService.new(card_id_param).validate!
  rescue CardValidatorService::CardNotFoundError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def collection_type
    "inventory"
  end
end
