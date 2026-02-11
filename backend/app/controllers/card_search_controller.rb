class CardSearchController < ApplicationController
  # ---------------------------------------------------------------------------
  # #index -- searches for cards by name, optionally filtered by finish
  # ---------------------------------------------------------------------------
  def index
    unless params[:q].present?
      render json: { error: "Search query (q) is required" }, status: :unprocessable_entity
      return
    end

    service = CardSearchService.new(
      query: params[:q],
      finishes: Array(params[:finishes])
    )

    render json: { cards: service.call }
  end
end
