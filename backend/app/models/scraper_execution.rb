class ScraperExecution < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------
  enum :status, { success: 0, partial_success: 1, failure: 2 }

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :started_at, presence: true
  validates :commanders_attempted, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :commanders_succeeded, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :commanders_failed, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total_cards_processed, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

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
  # Returns 0 if no commanders were attempted
  def success_rate
    return 0 if commanders_attempted.zero?
    (commanders_succeeded.to_f / commanders_attempted * 100).round(2)
  end
end
