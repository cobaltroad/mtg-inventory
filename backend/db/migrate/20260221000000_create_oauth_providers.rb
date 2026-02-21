class CreateOauthProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_providers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false

      t.timestamps
    end
    add_index :oauth_providers, [:provider, :uid], unique: true
  end
end
