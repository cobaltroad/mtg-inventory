class PricesController < ApplicationController
  # POST /api/prices/update
  # Triggers a manual price update for all cards in collections
  def update
    # Count cards to be updated
    card_count = CollectionItem.distinct.count(:card_id)

    if card_count.zero?
      render json: {
        message: "No cards found in collections",
        cards_to_update: 0
      }, status: :ok
      return
    end

    # Enqueue the job asynchronously
    UpdateCardPricesJob.perform_later

    render json: {
      message: "Price update job enqueued successfully",
      cards_to_update: card_count,
      status: "processing"
    }, status: :accepted
  end
end
