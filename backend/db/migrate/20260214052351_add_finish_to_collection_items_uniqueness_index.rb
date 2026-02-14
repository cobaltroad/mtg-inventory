class AddFinishToCollectionItemsUniquenessIndex < ActiveRecord::Migration[8.1]
  def change
    # Remove the old unique index that doesn't include finish
    remove_index :collection_items,
                 name: "idx_on_user_id_card_id_collection_type_4c84eddf15",
                 if_exists: true

    # Add new unique index that includes finish to allow foil/nonfoil separation
    # This enables tracking foil and nonfoil versions of the same card separately
    add_index :collection_items,
              [ :user_id, :card_id, :collection_type, :finish ],
              unique: true,
              name: "idx_collection_items_on_user_card_type_finish"
  end
end
