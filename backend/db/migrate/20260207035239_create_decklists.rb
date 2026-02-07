class CreateDecklists < ActiveRecord::Migration[8.1]
  def change
    create_table :decklists do |t|
      t.references :commander, null: false, foreign_key: true, index: { unique: true }
      t.references :partner, null: true, foreign_key: { to_table: :commanders }
      t.jsonb :contents, null: false, default: []
      t.tsvector :vector, null: false

      t.timestamps
    end

    # Add compound index as specified in requirements
    add_index :decklists, [ :commander_id, :partner_id ]
  end
end
