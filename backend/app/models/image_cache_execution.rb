class ImageCacheExecution < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Enums
  # ---------------------------------------------------------------------------
  enum :status, { success: 0, failure: 1, skipped: 2 }

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  validates :started_at, presence: true
  validates :collection_item_id, presence: true
  validates :card_id, presence: true
  validates :file_size_bytes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # ---------------------------------------------------------------------------
  # Instance methods
  # ---------------------------------------------------------------------------

  # Calculate execution time in seconds
  # Returns nil if the execution hasn't finished yet
  def execution_time_seconds
    return nil unless started_at && finished_at
    (finished_at - started_at).to_f
  end
end
