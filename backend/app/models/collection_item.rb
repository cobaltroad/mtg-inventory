class CollectionItem < ApplicationRecord
  COLLECTION_TYPES = %w[inventory wishlist].freeze

  belongs_to :user

  validates :card_id, presence: true
  validates :collection_type, presence: true, inclusion: { in: COLLECTION_TYPES }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :card_id, uniqueness: { scope: [ :user_id, :collection_type ], message: "has already been taken" }
end
