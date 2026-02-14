# Shared CRUD logic for inventory and wishlist controllers.
# Including controllers must define `collection_type` (a private method
# returning "inventory" or "wishlist").
module CollectionItemActions
  def index
    # Subclasses can override this to customize serialization
    render json: serialize_collection_items(collection_items)
  end

  # Upsert: if a row already exists for this card in the current collection
  # with the same finish, increment its quantity rather than creating a duplicate.
  # Different finishes (foil/nonfoil/etched) are tracked separately when explicitly specified.
  #
  # Backward Compatibility:
  # - When finish is NOT specified: finds ANY existing version (maintains old behavior)
  # - When finish IS specified: only matches that specific finish (enables foil/nonfoil separation)
  def create
    # Check if finish was explicitly provided in request parameters
    finish_explicit = params.key?(:finish)
    finish_value = finish_explicit ? params[:finish].presence : nil

    item = find_existing_item(card_id_param, finish_value, finish_explicit)
    status = :created

    if item
      item.quantity += quantity_param
      # Only update enhanced fields if they are currently nil
      apply_enhanced_params_to_existing(item)
      status = :ok
    else
      item = current_user.collection_items.new(
        card_id: card_id_param,
        collection_type: collection_type,
        quantity: quantity_param,
        **enhanced_tracking_params
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
    head :no_content
  end

  private

  # Default serialization - subclasses can override
  def serialize_collection_items(items)
    items
  end

  def collection_items
    current_user.collection_items
      .where(collection_type: collection_type)
      .includes(cached_image_attachment: :blob)
  end

  def find_existing_item(card_id, finish = nil, finish_explicit = false)
    # Backward compatibility logic:
    # - If finish was NOT explicitly provided: find ANY existing version (old behavior)
    # - If finish WAS explicitly provided: only match that specific finish (new behavior)
    if !finish_explicit
      # Find any existing version regardless of finish for backward compatibility
      collection_items.find_by(card_id: card_id)
    elsif finish.nil? || finish == DEFAULT_FINISH
      # When explicitly requesting nonfoil, also match legacy nil finish
      collection_items.find_by(card_id: card_id, finish: [ nil, DEFAULT_FINISH ])
    else
      # Explicit finish provided: only match that finish
      collection_items.find_by(card_id: card_id, finish: finish)
    end
  end

  def finish_param
    params[:finish].presence || DEFAULT_FINISH
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

  # Constants for default values
  DEFAULT_FINISH = "nonfoil"
  DEFAULT_LANGUAGE = "English"
  DEFAULT_PRICE_CENTS = 0
  CENTS_PER_DOLLAR = 100

  # Enhanced tracking parameters with default values and price conversion.
  # Returns an empty hash if no enhanced fields are provided (backward compatibility).
  def enhanced_tracking_params
    return {} unless enhanced_fields_present?

    {
      acquired_price_cents: resolve_price_in_cents,
      acquired_date: params[:acquired_date].presence || Date.today,
      finish: params[:finish].presence || DEFAULT_FINISH,
      language: params[:language].presence || DEFAULT_LANGUAGE
    }
  end

  # Apply enhanced tracking params to an existing item, but only if those fields are nil.
  # This preserves existing enhanced data during upsert operations.
  def apply_enhanced_params_to_existing(item)
    enhanced_params = enhanced_tracking_params
    return if enhanced_params.empty?

    %i[acquired_price_cents acquired_date finish language].each do |field|
      item.public_send("#{field}=", enhanced_params[field]) if item.public_send(field).nil?
    end
  end

  # Check if any enhanced tracking field is provided in params
  def enhanced_fields_present?
    params.key?(:acquired_price_cents) ||
      params.key?(:price) ||
      params.key?(:acquired_date) ||
      params.key?(:finish) ||
      params.key?(:language)
  end

  # Resolve price from either acquired_price_cents or price parameter.
  # Prioritizes acquired_price_cents over price. Converts price (decimal) to cents.
  def resolve_price_in_cents
    if params[:acquired_price_cents].present?
      params[:acquired_price_cents].to_i
    elsif params[:price].present?
      (params[:price].to_f * CENTS_PER_DOLLAR).to_i
    else
      DEFAULT_PRICE_CENTS
    end
  end
end
