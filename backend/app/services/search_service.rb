class SearchService
  # Cache search results for 1 hour
  CACHE_TTL = 1.hour

  def initialize(query:)
    @query = query
  end

  def call
    results = fetch_search_results_with_cache
    {
      decklists: results
    }
  end

  private

  def fetch_search_results_with_cache
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      perform_search
    end
  end

  def cache_key
    normalized_query = @query.downcase.strip
    "search:decklists:#{normalized_query}"
  end

  def perform_search
    # Use PostgreSQL full-text search on the vector column
    sanitized_query = ActiveRecord::Base.connection.quote(@query)
    decklists = Decklist
      .joins(:commander)
      .where("decklists.vector @@ plainto_tsquery('english', ?)", @query)
      .includes(:commander, :partner)
      .select("decklists.*, ts_rank(decklists.vector, plainto_tsquery('english', #{sanitized_query})) AS search_rank")
      .order("search_rank DESC")
      .limit(20)

    decklists.map do |decklist|
      format_result(decklist)
    end
  end

  def format_result(decklist)
    # Find matching cards in the decklist contents
    card_matches = find_matching_cards(decklist.contents, @query)

    {
      commander_id: decklist.commander.id,
      commander_name: decklist.commander.name,
      commander_rank: decklist.commander.rank,
      card_matches: card_matches,
      match_count: card_matches.size
    }
  end

  def find_matching_cards(contents, query)
    return [] unless contents.is_a?(Array)

    # Normalize query for matching
    query_terms = query.downcase.split(/\s+/)

    matching_cards = contents.select do |card|
      card_name = card["card_name"]&.downcase || ""
      # Check if any query term appears in the card name
      query_terms.any? { |term| card_name.include?(term) }
    end

    matching_cards.map do |card|
      {
        card_name: card["card_name"],
        quantity: card["quantity"]
      }
    end
  end
end
