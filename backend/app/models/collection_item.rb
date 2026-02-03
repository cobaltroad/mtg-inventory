class CollectionItem < ApplicationRecord
  COLLECTION_TYPES = %w[inventory wishlist].freeze

  TREATMENT_OPTIONS = [
    "Normal", "Foil", "Etched", "Showcase", "Extended Art",
    "Borderless", "Full Art", "Retro Frame", "Textured Foil"
  ].freeze

  LANGUAGE_OPTIONS = [
    "English", "Japanese", "German", "French", "Spanish",
    "Italian", "Portuguese", "Russian", "Korean",
    "Chinese Simplified", "Chinese Traditional"
  ].freeze

  belongs_to :user

  # Required field validations
  validates :card_id, presence: true
  validates :card_id, uniqueness: { scope: [ :user_id, :collection_type ], message: "has already been taken" }
  validates :collection_type, presence: true, inclusion: { in: COLLECTION_TYPES }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Enhanced tracking field validations (optional fields)
  validates :acquired_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :treatment, inclusion: { in: TREATMENT_OPTIONS }, allow_nil: true
  validates :language, inclusion: { in: LANGUAGE_OPTIONS }, allow_nil: true

  validate :acquired_date_cannot_be_in_future

  private

  def acquired_date_cannot_be_in_future
    return if acquired_date.blank?

    errors.add(:acquired_date, "cannot be in the future") if acquired_date > Date.today
  end
end
