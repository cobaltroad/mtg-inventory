class CardAnalytic < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Validations (AC2)
  # ---------------------------------------------------------------------------
  validates :card_id, presence: true
  validates :card_name, presence: true
  validates :source, presence: true, inclusion: { in: [ "edhrec" ] }
  validates :card_id, uniqueness: { scope: :strategy }

  # usage_data structure validation
  validate :usage_data_must_be_valid

  # ---------------------------------------------------------------------------
  # Scopes (AC2)
  # ---------------------------------------------------------------------------
  scope :for_source, ->(source) { where(source: source) }
  scope :by_strategy, ->(strategy) { where(strategy: strategy) }
  scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }

  # ---------------------------------------------------------------------------
  # Helper methods (AC2)
  # ---------------------------------------------------------------------------

  # Returns a specific metric from the usage_data JSONB
  # @param key [String] The metric key to retrieve
  # @return [Object, nil] The metric value or nil if not found
  def usage_metric(key)
    usage_data&.dig(key) || usage_data&.dig(key.to_s)
  end

  # Returns all unique rarities from the stored data
  # For EDHREC source, this returns the rarity field
  # @return [Array<String>] Array of unique rarity values
  def all_rarities
    rarity = usage_metric("rarity")
    rarity ? [ rarity ] : []
  end

  private

  # ---------------------------------------------------------------------------
  # Custom validation for usage_data structure
  # ---------------------------------------------------------------------------
  def usage_data_must_be_valid
    # Check presence
    if usage_data.blank?
      errors.add(:usage_data, "can't be blank")
      return
    end

    # Check it's a hash
    unless usage_data.is_a?(Hash)
      errors.add(:usage_data, "must be a hash")
      return
    end

    # Check for required keys
    unless usage_data.key?("commander_decklist_inclusion") || usage_data.key?(:commander_decklist_inclusion)
      errors.add(:usage_data, "must contain commander_decklist_inclusion array")
      return
    end

    # Check commander_decklist_inclusion is an array
    inclusion = usage_data["commander_decklist_inclusion"] || usage_data[:commander_decklist_inclusion]
    unless inclusion.is_a?(Array)
      errors.add(:usage_data, "commander_decklist_inclusion must be an array")
      return
    end

    # Check for rarity
    unless usage_data.key?("rarity") || usage_data.key?(:rarity)
      errors.add(:usage_data, "must contain rarity")
    end
  end
end
