class Commander < ApplicationRecord
  has_many :decklists, dependent: :destroy, inverse_of: :commander

  validates :name, presence: true, uniqueness: true
  validates :rank, presence: true
  validates :edhrec_url, presence: true

  # Returns the number of cards in the commander's primary decklist.
  # Commanders may have multiple decklists (e.g., with different partners),
  # but this returns the count from the first/primary decklist.
  #
  # @return [Integer] number of cards in the decklist, or 0 if no decklist exists
  def card_count
    primary_decklist&.contents&.length || 0
  end

  private

  # Returns the primary (first) decklist for this commander
  # @return [Decklist, nil] the primary decklist or nil if none exists
  def primary_decklist
    decklists.first
  end
end
