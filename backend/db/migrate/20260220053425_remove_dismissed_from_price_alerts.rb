class RemoveDismissedFromPriceAlerts < ActiveRecord::Migration[8.1]
  def change
    # Remove index that includes dismissed column
    remove_index :price_alerts, name: "index_price_alerts_on_user_id_and_dismissed"

    # Remove dismissed columns
    remove_column :price_alerts, :dismissed, :boolean, default: false, null: false
    remove_column :price_alerts, :dismissed_at, :datetime
  end
end
