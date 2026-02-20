# Inventory Backup Strategy

## Overview

This document outlines the backup strategy for the inventory (`collection_items`) table and related user data in production.

## Data to Backup

### Primary Tables

| Table | Description | Priority |
|-------|-------------|----------|
| `collection_items` | Core inventory records | Critical |
| `users` | User accounts | Critical |
| `price_alerts` | User price alerts | High |
| `card_prices` | Historical price data | High |
| `oauth_providers` | OAuth provider links (future) | High |

### Supporting Tables

- `active_storage_attachments` - Cached card images
- `usage_snapshots` - Analytics data (rebuildable)

## Backup Methods

### Method 1: pg_dump (Recommended for Manual Backups)

```bash
# Full database backup
docker compose exec db pg_dump -U postgres -d mtg_inventory_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Inventory-only backup (smaller, faster)
docker compose exec db pg_dump -U postgres -d mtg_inventory_production \
  -t collection_items -t users -t price_alerts > inventory_backup_$(date +%Y%m%d).sql
```

### Method 2: Automated Daily Backups with Cron

Add to your server's crontab:

```bash
# Daily at 2:00 AM UTC
0 2 * * * docker compose exec db pg_dump -U postgres -d mtg_inventory_production | gzip > /backups/mtg_inventory_$(date +\%Y\%m\%d).sql.gz

# Keep 30 days of backups
0 3 * * * find /backups -name "mtg_inventory_*.sql.gz" -mtime +30 -delete
```

### Method 3: AWS S3 Offsite Backup

```bash
#!/bin/bash
# backup_to_s3.sh

DATE=$(date +%Y%m%d)
BACKUP_FILE="/tmp/mtg_inventory_${DATE}.sql.gz"

# Create compressed backup
docker compose exec db pg_dump -U postgres -d mtg_inventory_production | gzip > $BACKUP_FILE

# Upload to S3
aws s3 cp $BACKUP_FILE s3://your-bucket/backups/mtg_inventory_${DATE}.sql.gz

# Cleanup local file
rm $BACKUP_FILE
```

### Method 4: Rails Task Backup

```ruby
# lib/tasks/backup.rake
namespace :backup do
  desc "Export inventory to JSON"
  task export_inventory: :environment do
    filename = "inventory_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
    
    data = {
      version: 1,
      exported_at: Time.current,
      collection_items: CollectionItem.includes(:user).as_json,
      users: User.all.as_json(except: [:password_digest])
    }
    
    File.write(filename, JSON.pretty_generate(data))
    puts "Exported to #{filename}"
  end
end
```

Run with:
```bash
docker compose exec backend rails backup:export_inventory
```

## Automated Backup Schedule

| Frequency | Time | Retention | Storage Location |
|-----------|------|-----------|------------------|
| Daily | 2:00 AM UTC | 7 days | Local volume |
| Weekly | Sunday 3:00 AM UTC | 30 days | S3 |

## Restore Procedures

### Full Database Restore

```bash
# Stop application
docker compose stop backend jobs

# Restore database
docker compose exec -T db psql -U postgres -d mtg_inventory_production < backup_20260115.sql

# Verify
docker compose exec backend rails runner "puts 'Collection items: ' + CollectionItem.count.to_s"

# Restart application
docker compose up -d backend jobs
```

### Point-in-Time Recovery

For more granular recovery, enable PostgreSQL point-in-time recovery:

```yaml
# docker-compose.override.yml
services:
  db:
    volumes:
      - ./backups/wal:/var/lib/postgresql/data/pg_wal
    command: postgres -cwal_level=replica -carchive_mode=on -carchive_command='test ! -f /var/lib/postgresql/data/pg_wal/%f && cp %p /var/lib/postgresql/data/pg_wal/%f'
```

## Verification

Always verify backups are valid:

```bash
# Test restore to verify backup is valid
docker compose exec db psql -U postgres -d mtg_inventory_test -f backup_20260115.sql

# Check record counts
docker compose exec db psql -U postgres -d mtg_inventory_production -c "SELECT COUNT(*) FROM collection_items;"
docker compose exec db psql -U postgres -d mtg_inventory_test -c "SELECT COUNT(*) FROM collection_items;"
```

## Backup Monitoring

Add to your monitoring system:

```bash
# Check last backup age
#!/bin/bash
LATEST=$(find /backups -name "mtg_inventory_*.sql.gz" -mmin -1440 | wc -l)
if [ $LATEST -eq 0 ]; then
  echo "ALERT: No backup in last 24 hours"
  # Send alert notification
fi
```

## Environment Variables

Ensure these are set for backup scripts:

```bash
POSTGRES_DB_NAME=mtg_inventory_production
POSTGRES_USER_NAME=postgres
AWS_S3_BUCKET=your-bucket-name
BACKUP_PATH=/backups
```

## Checklist

- [ ] Automated daily backups configured
- [ ] Weekly S3 offsite backups configured
- [ ] Backup retention policy implemented
- [ ] Restore procedure documented and tested
- [ ] Monitoring alerts for failed backups
- [ ] Backup encryption at rest (S3 bucket encryption)
