class RenameTreatmentToFinish < ActiveRecord::Migration[8.1]
  def up
    # Add finish column to collection_items
    add_column :collection_items, :finish, :string

    # Transform existing data in collection_items
    # Normal → nonfoil
    # Foil → foil
    # Etched → etched
    # Showcase, Extended Art, Borderless, Full Art, Retro Frame, Textured Foil → nonfoil
    # NULL → NULL (preserved)
    execute <<-SQL
      UPDATE collection_items
      SET finish = CASE
        WHEN treatment = 'Normal' THEN 'nonfoil'
        WHEN treatment = 'Foil' THEN 'foil'
        WHEN treatment = 'Etched' THEN 'etched'
        WHEN treatment IN ('Showcase', 'Extended Art', 'Borderless', 'Full Art', 'Retro Frame', 'Textured Foil') THEN 'nonfoil'
        ELSE NULL
      END
    SQL

    # Remove old treatment column from collection_items
    remove_column :collection_items, :treatment

    # Add finish column to price_alerts
    add_column :price_alerts, :finish, :string

    # Transform existing data in price_alerts (same rules)
    execute <<-SQL
      UPDATE price_alerts
      SET finish = CASE
        WHEN treatment = 'Normal' THEN 'nonfoil'
        WHEN treatment = 'Foil' THEN 'foil'
        WHEN treatment = 'Etched' THEN 'etched'
        WHEN treatment IN ('Showcase', 'Extended Art', 'Borderless', 'Full Art', 'Retro Frame', 'Textured Foil') THEN 'nonfoil'
        ELSE NULL
      END
    SQL

    # Remove old treatment column from price_alerts
    remove_column :price_alerts, :treatment
  end

  def down
    # Add treatment column back to collection_items
    add_column :collection_items, :treatment, :string

    # Reverse transform data in collection_items
    # nonfoil → Normal
    # foil → Foil
    # etched → Etched
    # NULL → NULL (preserved)
    execute <<-SQL
      UPDATE collection_items
      SET treatment = CASE
        WHEN finish = 'nonfoil' THEN 'Normal'
        WHEN finish = 'foil' THEN 'Foil'
        WHEN finish = 'etched' THEN 'Etched'
        ELSE NULL
      END
    SQL

    # Remove finish column from collection_items
    remove_column :collection_items, :finish

    # Add treatment column back to price_alerts
    add_column :price_alerts, :treatment, :string

    # Reverse transform data in price_alerts
    execute <<-SQL
      UPDATE price_alerts
      SET treatment = CASE
        WHEN finish = 'nonfoil' THEN 'Normal'
        WHEN finish = 'foil' THEN 'Foil'
        WHEN finish = 'etched' THEN 'Etched'
        ELSE NULL
      END
    SQL

    # Remove finish column from price_alerts
    remove_column :price_alerts, :finish
  end
end
