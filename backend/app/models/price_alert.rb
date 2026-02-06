# Tracks significant price changes for cards in user inventories.
# Alerts are generated when cards experience price increases of 20% or more,
# or price decreases of 30% or more within a 24-hour period.
class PriceAlert < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------

  belongs_to :user

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------

  ALERT_TYPES = %w[price_increase price_decrease].freeze

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  validates :card_id, presence: true
  validates :alert_type, presence: true, inclusion: { in: ALERT_TYPES }
  validates :old_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :new_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :percentage_change, presence: true

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------

  scope :active, -> { where(dismissed: false) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  # ---------------------------------------------------------------------------
  # Instance Methods
  # ---------------------------------------------------------------------------

  # Marks the alert as dismissed and records the dismissal timestamp.
  def dismiss!
    update!(dismissed: true, dismissed_at: Time.current)
  end

  # Returns true if this is a price increase alert.
  # @return [Boolean]
  def price_increase?
    alert_type == "price_increase"
  end

  # Returns true if this is a price decrease alert.
  # @return [Boolean]
  def price_decrease?
    alert_type == "price_decrease"
  end
end
