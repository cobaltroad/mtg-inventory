class CardSearchService
  VALID_TREATMENTS = %w[foil borderless art_frame etched extended_art showcase].freeze
  # Cache external API results for 24 hours to reduce API usage.
  # Can be overridden via CARD_SEARCH_CACHE_TTL environment variable (in seconds).
  CACHE_TTL = (ENV.fetch("CARD_SEARCH_CACHE_TTL", 24.hours.to_s).to_i).seconds

  def initialize(query:, treatments: [])
    @query = query
    @treatments = treatments & VALID_TREATMENTS
  end

  # ---------------------------------------------------------------------------
  # Fetches a single page of cards matching the query, derives treatments for
  # each card, and optionally filters to only cards that carry at least one of
  # the requested treatments (OR logic).
  #
  # Caching strategy:
  # - External API results are cached by query string only (not treatments)
  # - Treatment filtering is applied after cache retrieval
  # - This allows different treatment filters to share the same cached API data
  # - Cache TTL: 24 hours by default (configurable via CARD_SEARCH_CACHE_TTL)
  # ---------------------------------------------------------------------------
  def call
    results = fetch_cards_with_cache
    @treatments.any? ? filter_by_treatments(results) : results
  end

  private

  # ---------------------------------------------------------------------------
  # Fetches cards from cache if available, otherwise calls external API.
  # Cache key is based only on query to allow treatment filtering from cache.
  # ---------------------------------------------------------------------------
  def fetch_cards_with_cache
    Rails.cache.fetch(cache_key_for_query, expires_in: CACHE_TTL) do
      fetch_cards_from_api
    end
  end

  # Generates a cache key for the given query string
  def cache_key_for_query
    "card_search:#{@query}"
  end

  # Fetches cards from the external MTG API and formats them
  def fetch_cards_from_api
    cards = MTG::Card.where(name: @query, page: 1).all
    cards.map { |card| format_card(card) }
  end

  def format_card(card)
    {
      id: card.id,
      name: card.name,
      set: card.set,
      set_name: card.set_name,
      collector_number: card.number,
      image_url: card.image_url,
      treatments: derive_treatments(card)
    }
  end

  # Derives treatment badges from the card's raw SDK attributes.  Currently
  # only `borderless` is detectable via card.border; extend this method as
  # the SDK surfaces additional treatment signals.
  def derive_treatments(card)
    treatments = []
    treatments << "borderless" if card.border == "borderless"
    treatments
  end

  def filter_by_treatments(results)
    results.select { |card| (card[:treatments] & @treatments).any? }
  end
end
