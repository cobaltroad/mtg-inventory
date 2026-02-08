class SearchService
  # Cache search results for 1 hour
  CACHE_TTL = 1.hour
  # Inventory cache TTL - 5 minutes (shorter than decklist cache)
  INVENTORY_CACHE_TTL = 5.minutes

  def initialize(query:)
    @query = query
  end

  def call
    results = fetch_search_results_with_cache
    {
      decklists: results
    }
  end

  # Searches user's inventory for cards matching the query
  # Returns enriched inventory items with card details from Scryfall
  def search_inventory(user, query)
    Rails.cache.fetch(inventory_cache_key(user, query), expires_in: INVENTORY_CACHE_TTL) do
      perform_inventory_search(user, query)
    end
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

  # Performs inventory search with enrichment
  def perform_inventory_search(user, query)
    # 1. Fetch user inventory items
    items = user.collection_items.where(collection_type: "inventory")

    # 2. Enrich with Scryfall details
    enriched = enrich_inventory_items(items)

    # 3. Filter by card name (case-insensitive, partial match)
    normalized_query = query.downcase
    filtered = enriched.select do |item|
      item[:card_name].downcase.include?(normalized_query)
    end

    # 4. Limit to 50 results
    filtered.take(50)
  end

  # Enriches inventory items with card details from Scryfall
  def enrich_inventory_items(items)
    items.map do |item|
      card_details = fetch_card_details(item.card_id)
      next if card_details.nil?

      serialize_inventory_item(item, card_details)
    end.compact
  end

  # Fetches card details from Scryfall with caching
  def fetch_card_details(card_id)
    CardDetailsService.new(card_id: card_id).call
  rescue CardDetailsService::NetworkError, CardDetailsService::TimeoutError => e
    Rails.logger.warn("Failed to fetch card details for #{card_id}: #{e.message}")
    nil
  rescue CardDetailsService::RateLimitError => e
    Rails.logger.error("Scryfall rate limit exceeded: #{e.message}")
    nil
  end

  # Serializes an inventory item with its card details and price data
  def serialize_inventory_item(item, card_details)
    # Get price data
    latest_price = item.latest_price
    unit_price = item.unit_price_cents
    total_price = item.total_price_cents
    price_updated_at = latest_price&.fetched_at

    {
      id: item.id,
      card_id: item.card_id,
      card_name: card_details[:name],
      set: card_details[:set],
      set_name: card_details[:set_name],
      collector_number: card_details[:collector_number],
      quantity: item.quantity,
      image_url: card_details[:image_url],
      treatment: item.treatment,
      unit_price_cents: unit_price,
      total_price_cents: total_price
    }
  end

  # Generates cache key for inventory search
  def inventory_cache_key(user, query)
    normalized_query = query.downcase.strip
    "search:inventory:#{user.id}:#{normalized_query}"
  end
end
