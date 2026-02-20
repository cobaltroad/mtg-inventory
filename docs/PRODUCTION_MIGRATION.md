# Preserving Inventory Records When Moving to Production

This document outlines the steps to preserve existing inventory (collection_items) when transitioning from development to production.

## Database Overview

Inventory data is stored in the `collection_items` table. Related tables that should also be preserved:

| Table | Purpose |
|-------|---------|
| `users` | User accounts |
| `collection_items` | Card inventory records |
| `card_prices` | Historical price data |
| `price_alerts` | User price alerts |
| `active_storage_*` | Cached card images |

## Migration Options

### Option 1: Database Dump and Restore (Recommended)

This preserves all data by exporting from the development database and importing into production.

```bash
# 1. Stop the application to ensure data consistency
docker compose stop backend jobs

# 2. Dump the development database
docker compose exec db pg_dump -U postgres -d mtg_inventory_development > backup_$(date +%Y%m%d).sql

# 3. Restore to production database (adjust DATABASE_URL for production)
docker compose exec -e PGPASSWORD=$POSTGRES_USER_PASSWORD db \
  psql -U $POSTGRES_USER_NAME -d mtg_inventory_production < backup_YYYYMMDD.sql
```

### Option 2: Docker Volume Migration

If using named volumes, export/import the volume:

```bash
# Export development volume
docker run --rm -v mtg-inventory_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_data.tar.gz -C /data .

# Import to production (before starting production containers)
docker run --rm -v mtg-inventory_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres_data.tar.gz -C /data
```

### Option 3: Rails Export/Import

Export inventory to JSON, then re-import in production:

```bash
# Export from development
docker compose exec backend rails runner "puts CollectionItem.all.to_json" > collection_items.json

# Import in production
docker compose exec backend rails runner "CollectionItem.import!(JSON.parse(File.read('collection_items.json')))"
```

## Pre-Migration Checklist

1. **Backup existing data**
   ```bash
   docker compose exec db pg_dump -U postgres -d mtg_inventory_development > backup_$(date +%Y%m%d).sql
   ```

2. **Verify data integrity before migration**
   ```bash
   docker compose exec backend rails runner "puts 'Collection items: ' + CollectionItem.count.to_s"
   docker compose exec backend rails runner "puts 'Users: ' + User.count.to_s"
   ```

3. **Update environment variables for production**
   - Set `RAILS_ENV=production`
   - Configure production `DATABASE_URL`
   - Update `APP_DOMAIN` to production URL

4. **Run migrations on production database**
   ```bash
   docker compose exec backend bundle exec rails db:migrate
   ```

## Post-Migration Verification

```bash
# Verify record counts match
docker compose exec backend rails runner "puts CollectionItem.count"

# Check for any data issues
docker compose exec backend rails runner "puts CollectionItem.where(card_id: nil).count"
```

## Important Considerations

- **User IDs**: If using the same database, user IDs will be preserved. If creating new users, existing inventory may need reassignment.
- **Image cache**: Active Storage attachments for card images can be large. Consider whether to migrate these or let them rebuild naturally.
- **Price alerts**: These are tied to specific card_ids and user_ids—migrate both tables together.
- **Environment isolation**: Ensure production and development use separate databases to avoid data conflicts.
