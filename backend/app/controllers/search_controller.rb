class SearchController < ApplicationController
  # GET /api/search?q=query
  def index
    # Validate query parameter
    query = params[:q]

    if query.blank?
      render json: { error: "Search query (q) is required" }, status: :bad_request
      return
    end

    if query.length < 2
      render json: { error: "Search query must be at least 2 characters" }, status: :bad_request
      return
    end

    # Perform search
    service = SearchService.new(query: query)
    results = service.call

    # Format response
    render json: {
      query: query,
      total_results: results[:decklists].size,
      results: results
    }
  end
end
