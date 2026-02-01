class CardSearchService
  VALID_TREATMENTS = %w[foil borderless art_frame etched extended_art showcase].freeze

  def initialize(query:, treatments: [])
    @query = query
    @treatments = treatments & VALID_TREATMENTS
  end

  # ---------------------------------------------------------------------------
  # Fetches a single page of cards matching the query, derives treatments for
  # each card, and optionally filters to only cards that carry at least one of
  # the requested treatments (OR logic).
  # ---------------------------------------------------------------------------
  def call
    cards = MTG::Card.where(name: @query, page: 1).all
    results = cards.map { |card| format_card(card) }
    @treatments.any? ? filter_by_treatments(results) : results
  end

  private

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
