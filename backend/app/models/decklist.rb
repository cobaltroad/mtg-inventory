class Decklist < ApplicationRecord
  belongs_to :commander, inverse_of: :decklists
  belongs_to :partner, class_name: "Commander", optional: true

  validates :commander, presence: true
  validates :contents, presence: true
  validates :commander_id, uniqueness: { scope: :partner_id }
  validate :contents_cannot_be_empty

  before_validation :generate_vector

  private

  def contents_cannot_be_empty
    if contents.is_a?(Array) && contents.empty?
      errors.add(:contents, "can't be blank")
    end
  end

  def generate_vector
    return unless contents.present?

    searchable_text = build_searchable_text
    combined_text = searchable_text.join(" ")

    # Use raw SQL to generate tsvector value
    result = self.class.connection.execute(
      "SELECT to_tsvector('english', #{self.class.connection.quote(combined_text)}) AS vector"
    )
    self.vector = result.first["vector"]
  end

  def build_searchable_text
    text = []

    # Add card names from contents
    contents.each { |card| text << card["card_name"] if card["card_name"].present? } if contents.is_a?(Array)

    # Add commander and partner names
    text << commander.name if commander&.name.present?
    text << partner.name if partner&.name.present?

    text
  end
end
