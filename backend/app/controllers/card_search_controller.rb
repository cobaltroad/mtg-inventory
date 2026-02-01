class CardSearchController < ApplicationController
  # ---------------------------------------------------------------------------
  # #index -- searches for cards by name, optionally filtered by treatment
  # ---------------------------------------------------------------------------
  def index
    unless params[:q].present?
      render json: { error: "Search query (q) is required" }, status: :unprocessable_entity
      return
    end

    service = CardSearchService.new(
      query: params[:q],
      treatments: Array(params[:treatments])
    )

    render json: { cards: service.call }
  end
end
