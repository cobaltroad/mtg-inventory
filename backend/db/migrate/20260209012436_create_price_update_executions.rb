class CreatePriceUpdateExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :price_update_executions do |t|
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :status, default: 0, null: false  # enum: success, partial_success, failure
      t.string :mode, null: false  # 'batch' or 'single_card'
      t.integer :cards_attempted, default: 0
      t.integer :cards_succeeded, default: 0
      t.integer :cards_failed, default: 0
      t.integer :cards_skipped, default: 0
      t.integer :price_alerts_created, default: 0
      t.text :error_summary

      t.timestamps
    end

    add_index :price_update_executions, :started_at
    add_index :price_update_executions, :status
    add_index :price_update_executions, :mode
  end
end
