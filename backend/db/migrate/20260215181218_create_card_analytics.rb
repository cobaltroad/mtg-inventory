class CreateCardAnalytics < ActiveRecord::Migration[8.1]
  def change
    create_table :card_analytics do |t|
      t.string :card_id, null: false
      t.string :card_name, null: false
      t.string :source, null: false
      t.jsonb :usage_data, null: false, default: {}
      t.string :strategy
      t.decimal :score, precision: 9, scale: 4
      t.text :tags, array: true, default: []
      t.text :summary
      t.datetime :computed_at

      t.timestamps
    end

    # Indexes for efficient queries
    add_index :card_analytics, :card_id
    add_index :card_analytics, :source
    add_index :card_analytics, [ :card_id, :strategy ], unique: true
    add_index :card_analytics, :usage_data, using: :gin
    add_index :card_analytics, :tags, using: :gin
  end
end
