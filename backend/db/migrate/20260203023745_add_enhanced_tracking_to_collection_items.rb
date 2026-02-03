class AddEnhancedTrackingToCollectionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :collection_items, :acquired_date, :date
    add_column :collection_items, :acquired_price_cents, :integer
    add_column :collection_items, :treatment, :string
    add_column :collection_items, :language, :string
  end
end
