class RenameCardAnalyticsToUsageSnapshots < ActiveRecord::Migration[8.1]
  def change
    rename_table :card_analytics, :usage_snapshots
  end
end
