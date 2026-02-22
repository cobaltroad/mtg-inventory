namespace :data do
  desc "Migrate data from development to production database. " \
       "Migrates users first, then maps dev user IDs to prod user IDs for collection_items. " \
       "Usage: bundle exec rake data:migrate_from_development"
  task :migrate_from_development => :environment do
    dev_db = "mtg_inventory_development"
    prod_db = "mtg_inventory_production"

    puts "Starting data migration from #{dev_db} to #{prod_db}"
    puts "-" * 60

    # Define development database connection specs
    DEV_CONNECTION = {
      adapter: "postgresql",
      database: dev_db,
      host: ENV.fetch("DB_HOST", "db"),
      username: ENV.fetch("DB_USER", "postgres"),
      password: ENV.fetch("DB_PASS", nil)
    }.freeze

    PROD_CONNECTION = {
      adapter: "postgresql",
      database: prod_db,
      host: ENV.fetch("DB_HOST", "db"),
      username: ENV.fetch("DB_USER", "postgres"),
      password: ENV.fetch("DB_PASS", nil)
    }.freeze

    class DevUser < ActiveRecord::Base
      self.table_name = "users"
      establish_connection(DEV_CONNECTION)
    end

    class DevCollectionItem < ActiveRecord::Base
      self.table_name = "collection_items"
      establish_connection(DEV_CONNECTION)
    end

    class DevCardPrice < ActiveRecord::Base
      self.table_name = "card_prices"
      establish_connection(DEV_CONNECTION)
    end

    User.establish_connection(PROD_CONNECTION)
    CollectionItem.establish_connection(PROD_CONNECTION)
    CardPrice.establish_connection(PROD_CONNECTION)

    puts "\n[1/3] Migrating users..."
    dev_users = DevUser.all.to_a
    users_migrated = 0
    users_skipped = 0
    user_id_mapping = {}

    if dev_users.empty?
      puts "  No users found in development database. Skipping user migration."
    else
      dev_users.each do |dev_user|
        existing_user = User.find_by(email: dev_user.email)
        if existing_user
          user_id_mapping[dev_user.id] = existing_user.id
          users_skipped += 1
        else
          new_user = User.create!(
            email: dev_user.email,
            name: dev_user.name,
            created_at: dev_user.created_at,
            updated_at: dev_user.updated_at
          )
          user_id_mapping[dev_user.id] = new_user.id
          users_migrated += 1
        end
      end
    end

    puts "  Users migrated: #{users_migrated}"
    puts "  Users skipped (already exist): #{users_skipped}"
    puts "  User ID mapping: #{user_id_mapping.inspect}"

    if user_id_mapping.empty?
      puts "\nERROR: No users were migrated and no mapping available. Cannot migrate collection_items."
      puts "Please ensure there are users in the development database."
      exit 1
    end

    puts "\n[2/3] Migrating collection_items..."
    dev_collection_items = DevCollectionItem.all.to_a
    collection_items_migrated = 0
    collection_items_skipped = 0

    dev_collection_items.each do |dev_item|
      prod_user_id = user_id_mapping[dev_item.user_id]
      unless prod_user_id
        collection_items_skipped += 1
        next
      end

      existing = CollectionItem.find_by(
        user_id: prod_user_id,
        card_id: dev_item.card_id,
        collection_type: dev_item.collection_type,
        finish: dev_item.finish
      )

      if existing
        collection_items_skipped += 1
        next
      end

      CollectionItem.create!(
        user_id: prod_user_id,
        card_id: dev_item.card_id,
        collection_type: dev_item.collection_type,
        quantity: dev_item.quantity,
        finish: dev_item.finish,
        language: dev_item.language,
        acquired_date: dev_item.acquired_date,
        acquired_price_cents: dev_item.acquired_price_cents,
        card_name: dev_item.card_name,
        set_name: dev_item.set_name,
        released_at: dev_item.released_at,
        created_at: dev_item.created_at,
        updated_at: dev_item.updated_at
      )
      collection_items_migrated += 1
    end

    puts "  Collection items migrated: #{collection_items_migrated}"
    puts "  Collection items skipped: #{collection_items_skipped}"

    puts "\n[3/3] Migrating card_prices..."
    dev_card_prices = DevCardPrice.all.to_a
    card_prices_migrated = 0

    dev_card_prices.each do |dev_price|
      existing = CardPrice.find_by(card_id: dev_price.card_id, fetched_at: dev_price.fetched_at)
      if existing
        next
      end

      CardPrice.create!(
        card_id: dev_price.card_id,
        fetched_at: dev_price.fetched_at,
        usd_cents: dev_price.usd_cents,
        usd_foil_cents: dev_price.usd_foil_cents,
        usd_etched_cents: dev_price.usd_etched_cents,
        created_at: dev_price.created_at,
        updated_at: dev_price.updated_at
      )
      card_prices_migrated += 1
    end

    puts "  Card prices migrated: #{card_prices_migrated}/#{dev_card_prices.length}"

    puts "\n" + "=" * 60
    puts "Migration complete!"
    puts "=" * 60
    puts "Users:           #{users_migrated} migrated (#{users_skipped} skipped)"
    puts "Collection items: #{collection_items_migrated} migrated (#{collection_items_skipped} skipped)"
    puts "Card prices:     #{card_prices_migrated} migrated"
  end
end
