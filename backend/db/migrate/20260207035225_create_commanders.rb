class CreateCommanders < ActiveRecord::Migration[8.1]
  def change
    create_table :commanders do |t|
      t.string :name, null: false
      t.integer :rank, null: false
      t.string :edhrec_url, null: false
      t.datetime :last_scraped_at

      t.timestamps
    end
    add_index :commanders, :name, unique: true
    add_index :commanders, :rank
  end
end
