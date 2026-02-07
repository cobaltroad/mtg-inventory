class CommandersController < ApplicationController
  # GET /api/commanders
  # Returns all commanders ordered by rank (ascending) with their card counts.
  # Response includes: id, name, rank, edhrec_url, last_scraped_at, card_count
  def index
    commanders = Commander.includes(:decklists).order(rank: :asc)

    render json: commanders.as_json(
      only: [ :id, :name, :rank, :edhrec_url, :last_scraped_at ],
      methods: [ :card_count ]
    )
  end

  # GET /api/commanders/:id
  # Returns a single commander with full decklist contents.
  # Response includes all commander fields plus a cards array containing
  # the full decklist from the JSONB contents column.
  def show
    commander = find_commander

    render json: serialize_commander_with_decklist(commander)
  rescue ActiveRecord::RecordNotFound, ArgumentError
    render_not_found
  end

  private

  # Finds a commander by ID with eager-loaded decklists
  # Raises ActiveRecord::RecordNotFound if not found
  # Raises ArgumentError if ID format is invalid
  def find_commander
    Commander.includes(:decklists).find(params[:id])
  end

  # Serializes a commander with its complete decklist contents
  # @param commander [Commander] the commander to serialize
  # @return [Hash] JSON-serializable hash with commander data and cards array
  def serialize_commander_with_decklist(commander)
    {
      id: commander.id,
      name: commander.name,
      rank: commander.rank,
      edhrec_url: commander.edhrec_url,
      last_scraped_at: commander.last_scraped_at,
      card_count: commander.card_count,
      cards: extract_decklist_contents(commander)
    }
  end

  # Extracts the decklist contents from a commander's first decklist
  # @param commander [Commander] the commander whose decklist to extract
  # @return [Array] array of card hashes, or empty array if no decklist exists
  def extract_decklist_contents(commander)
    commander.decklists.first&.contents || []
  end

  # Renders a 404 Not Found response with error message
  def render_not_found
    render json: { error: "Commander not found" }, status: :not_found
  end
end
