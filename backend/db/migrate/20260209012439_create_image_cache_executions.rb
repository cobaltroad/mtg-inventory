class CreateImageCacheExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :image_cache_executions do |t|
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :status, default: 0, null: false  # enum: success, failure, skipped
      t.bigint :collection_item_id, null: false
      t.string :card_id, null: false
      t.boolean :cache_hit, default: false
      t.boolean :downloaded, default: false
      t.integer :file_size_bytes
      t.text :error_message

      t.timestamps
    end

    add_index :image_cache_executions, :started_at
    add_index :image_cache_executions, :status
    add_index :image_cache_executions, :collection_item_id
    add_index :image_cache_executions, :card_id
  end
end
