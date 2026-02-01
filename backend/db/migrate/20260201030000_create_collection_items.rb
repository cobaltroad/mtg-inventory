class CreateCollectionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :collection_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :card_id, null: false
      t.string :collection_type, null: false
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_index :collection_items, [ :user_id, :card_id, :collection_type ], unique: true
  end
end
