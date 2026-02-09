class PriceUpdateExecution < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------
  enum :status, { success: 0, partial_success: 1, failure: 2 }

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :started_at, presence: true
  validates :mode, presence: true
  validates :cards_attempted, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cards_succeeded, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cards_failed, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cards_skipped, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :price_alerts_created, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # ---------------------------------------------------------------------------
  # Instance methods
  # ---------------------------------------------------------------------------

  # Calculate execution time in seconds
  # Returns nil if the execution hasn't finished yet
  def execution_time_seconds
    return nil unless started_at && finished_at
    (finished_at - started_at).to_f
  end

  # Calculate success rate as a percentage
  # Returns 0 if no cards were attempted
  def success_rate
    return 0 if cards_attempted.zero?
    (cards_succeeded.to_f / cards_attempted * 100).round(2)
  end
end
