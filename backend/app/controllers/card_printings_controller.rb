class CardPrintingsController < ApplicationController
  # ---------------------------------------------------------------------------
  # #show -- returns all printings for a specific card
  # ---------------------------------------------------------------------------
  def show
    service = CardPrintingsService.new(card_id: params[:id])
    printings = service.call
    render json: { printings: printings }
  rescue StandardError => e
    Rails.logger.error("Error fetching card printings: #{e.message}")
    render json: { error: "Unable to fetch printings. Please try again." }, status: :internal_server_error
  end
end
