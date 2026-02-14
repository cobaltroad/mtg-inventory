class AddDenormalizedCardFieldsToCollectionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :collection_items, :card_name, :string
    add_column :collection_items, :set_name, :string
    add_column :collection_items, :released_at, :date

    # Add indexes for efficient sorting
    add_index :collection_items, :card_name
    add_index :collection_items, :set_name
    add_index :collection_items, :released_at
  end
end
