class CreatePriceAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :price_alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :card_id, null: false
      t.string :alert_type, null: false # 'price_increase' or 'price_decrease'
      t.integer :old_price_cents, null: false
      t.integer :new_price_cents, null: false
      t.decimal :percentage_change, precision: 10, scale: 2, null: false
      t.string :treatment # 'normal', 'foil', or 'etched'
      t.boolean :dismissed, default: false, null: false
      t.datetime :dismissed_at

      t.timestamps
    end

    add_index :price_alerts, [:user_id, :card_id, :created_at]
    add_index :price_alerts, [:user_id, :dismissed]
  end
end
