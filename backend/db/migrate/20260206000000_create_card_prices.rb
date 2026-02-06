class CreateCardPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :card_prices do |t|
      t.string :card_id, null: false
      t.integer :usd_cents
      t.integer :usd_foil_cents
      t.integer :usd_etched_cents
      t.timestamp :fetched_at, null: false

      t.timestamps
    end

    # Add index on card_id for lookups
    add_index :card_prices, :card_id

    # Add composite index for efficient latest price queries
    # DESC order allows fast retrieval of most recent price for a card
    add_index :card_prices, [:card_id, :fetched_at], order: { fetched_at: :desc }, name: "index_card_prices_on_card_id_and_fetched_at_desc"
  end
end
