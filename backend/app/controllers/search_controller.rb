class SearchController < ApplicationController
  # GET /api/search?q=query
  # Searches both commander decklists and user's inventory
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

    # Perform searches
    service = SearchService.new(query: query)

    # Search decklists
    decklist_results = service.call

    # Search inventory (returns empty array if no current_user)
    inventory_results = search_user_inventory(service, query)

    # Combine results
    combined_results = {
      decklists: decklist_results[:decklists],
      inventory: inventory_results
    }

    # Calculate total count
    total_count = decklist_results[:decklists].size + inventory_results.size

    # Format response
    render json: {
      query: query,
      total_results: total_count,
      results: combined_results
    }
  end

  private

  # Searches user's inventory, returns empty array if no user authenticated
  def search_user_inventory(service, query)
    return [] unless current_user

    service.search_inventory(current_user, query)
  end
end
