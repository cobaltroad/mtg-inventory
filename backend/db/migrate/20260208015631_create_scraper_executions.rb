class CreateScraperExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :scraper_executions do |t|
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :status, default: 0, null: false
      t.integer :commanders_attempted, default: 0
      t.integer :commanders_succeeded, default: 0
      t.integer :commanders_failed, default: 0
      t.integer :total_cards_processed, default: 0
      t.text :error_summary

      t.timestamps
    end

    add_index :scraper_executions, :started_at
    add_index :scraper_executions, :status
  end
end
