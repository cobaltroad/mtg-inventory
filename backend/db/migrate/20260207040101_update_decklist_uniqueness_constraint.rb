class UpdateDecklistUniquenessConstraint < ActiveRecord::Migration[8.1]
  def change
    # Remove the unique constraint on commander_id alone
    remove_index :decklists, :commander_id, unique: true

    # Add regular index on commander_id (for foreign key lookups)
    add_index :decklists, :commander_id

    # Remove the existing compound index
    remove_index :decklists, [ :commander_id, :partner_id ]

    # Add unique constraint on the combination of commander_id and partner_id
    # This allows same commander with different partners, but prevents duplicate combinations
    add_index :decklists, [ :commander_id, :partner_id ], unique: true
  end
end
