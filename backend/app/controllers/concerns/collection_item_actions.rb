# Shared CRUD logic for inventory and wishlist controllers.
# Including controllers must define `collection_type` (a private method
# returning "inventory" or "wishlist").
module CollectionItemActions
  def index
    render json: collection_items
  end

  # Upsert: if a row already exists for this card in the current collection,
  # increment its quantity rather than creating a duplicate.
  def create
    item = find_existing_item(card_id_param)
    status = :created

    if item
      item.quantity += quantity_param
      status = :ok
    else
      item = current_user.collection_items.new(
        card_id: card_id_param,
        collection_type: collection_type,
        quantity: quantity_param
      )
    end

    if item.save
      render json: item, status: status
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    item = find_item!(params[:id])
    return unless item # find_item! already rendered 404

    if item.update(quantity: quantity_param)
      render json: item
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    item = find_item!(params[:id])
    return unless item # find_item! already rendered 404

    item.destroy
    render json: { message: "Deleted" }
  end

  private

  def collection_items
    current_user.collection_items.where(collection_type: collection_type)
  end

  def find_existing_item(card_id)
    collection_items.find_by(card_id: card_id)
  end

  # Returns the record, or renders 404 and returns nil.
  def find_item!(id)
    collection_items.find(id)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Not found" }, status: :not_found
    nil
  end

  def card_id_param
    params[:card_id]
  end

  def quantity_param
    params[:quantity]&.to_i || 0
  end
end
