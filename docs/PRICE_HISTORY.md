# How Price History is Automatically Generated

The MTG Inventory application automatically tracks price history for all cards in user collections through a sophisticated scheduled job system. Here's how it works:

## 1. Scheduled Daily Price Updates

The system runs the `UpdateCardPricesJob` automatically:
- **Production**: Every day at 7am
- **Development**: Every 2 days at 7am

This is configured in `backend/config/recurring.yml:33-36` using Solid Queue's recurring jobs feature.

## 2. Batch Processing of All Cards

When the job runs (`backend/app/jobs/update_card_prices_job.rb`), it:

1. **Collects unique cards**: Queries all unique `card_id` values from `CollectionItem` records across all users
2. **Filters already-processed cards**: Skips cards that already have a price record from today (idempotency)
3. **Processes in batches**: Updates 50 cards at a time with 100ms delays between batches for rate limiting

## 3. Fetching Prices from Scryfall

For each card, the `CardPriceService` (`backend/app/services/card_price_service.rb`):

1. **Checks cache**: First looks for cached prices (24-hour TTL) to reduce API calls
2. **Queries Scryfall API**: Fetches current market prices if not cached
3. **Handles multiple finishes**: Retrieves prices for:
   - Regular (nonfoil) - `usd_cents`
   - Foil - `usd_foil_cents`
   - Etched - `usd_etched_cents`
4. **Rate limiting & retries**: Implements exponential backoff for 429 errors and network failures

## 4. Storing Historical Snapshots

Each price fetch creates a new `CardPrice` record (`backend/app/models/card_price.rb`):

```ruby
{
  card_id: "uuid",
  usd_cents: 1500,           # Stored as integers to avoid float precision issues
  usd_foil_cents: 3000,
  usd_etched_cents: null,
  fetched_at: "2026-02-12 07:00:00"
}
```

**Key features**:
- Prices stored in **cents** (not dollars) to avoid floating-point errors
- Each record is a **time-stamped snapshot**
- Multiple records per card build the **price history timeline**
- Composite index `(card_id, fetched_at DESC)` enables fast queries

## 5. Accessing Price History

The `CardPriceHistoryController` (`backend/app/controllers/card_price_history_controller.rb`) provides:

**API endpoint**: `GET /api/cards/:card_id/price_history?time_period=30`

**Time periods**:
- `7` - Last 7 days
- `30` - Last 30 days (default)
- `90` - Last 90 days
- `365` - Last year
- `all` - Complete history

**Response includes**:
- Chronological price data points
- Summary statistics (start/end prices, % change, direction)
- Separate tracking for each finish type

## 6. Price Change Alerts

After updating prices, the job automatically:
1. Runs `PriceAlertService` to detect significant price changes
2. Creates alert records for users when their cards spike or drop in value
3. Tracks alert counts in the execution log

## Architecture Benefits

✅ **Automatic**: No manual intervention required
✅ **Comprehensive**: Tracks all cards in any user's collection
✅ **Efficient**: Batch processing with rate limiting
✅ **Reliable**: Retries, error handling, and idempotency
✅ **Scalable**: Composite indexes for fast historical queries
✅ **Observable**: Detailed logging with `PriceUpdateExecution` records

## Manual Triggers

You can also manually trigger price updates:

```bash
# Update all cards
docker compose exec backend rails jobs:update_prices

# Update single card
docker compose exec backend rails jobs:prices:update_card[SCRYFALL_CARD_ID]

# View job statistics
docker compose exec backend rails jobs:stats
```

## Database Schema

The `card_prices` table stores all historical snapshots:

```ruby
create_table :card_prices do |t|
  t.string :card_id, null: false
  t.integer :usd_cents
  t.integer :usd_foil_cents
  t.integer :usd_etched_cents
  t.timestamp :fetched_at, null: false
  t.timestamps
end

# Indexes for efficient queries
add_index :card_prices, :card_id
add_index :card_prices, [:card_id, :fetched_at], order: { fetched_at: :desc }
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  Solid Queue Scheduler                       │
│           (recurring.yml - every day at 7am)                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              UpdateCardPricesJob.perform                     │
│  1. Get all unique card_ids from CollectionItem             │
│  2. Filter out cards already processed today                │
│  3. Process in batches of 50                                │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              CardPriceService.call                           │
│  1. Check Rails.cache (24h TTL)                             │
│  2. If miss: Fetch from Scryfall API                        │
│  3. Parse USD, USD foil, USD etched                         │
│  4. Convert dollars → cents                                 │
│  5. Return price_data hash                                  │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              CardPrice.create!                               │
│  Store snapshot with fetched_at timestamp                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              PriceAlertService                               │
│  Detect significant price changes & create alerts           │
└─────────────────────────────────────────────────────────────┘
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `backend/app/jobs/update_card_prices_job.rb` | Scheduled job that orchestrates batch price updates |
| `backend/app/services/card_price_service.rb` | Service that fetches prices from Scryfall API |
| `backend/app/models/card_price.rb` | ActiveRecord model for historical price snapshots |
| `backend/app/controllers/card_price_history_controller.rb` | API endpoint for retrieving price history |
| `backend/config/recurring.yml` | Solid Queue schedule configuration |
| `backend/db/migrate/20260206000000_create_card_prices.rb` | Database schema definition |

---

This architecture ensures that every time a user views their inventory value or price charts, the data is based on actual historical snapshots collected daily, providing accurate trend analysis and portfolio tracking.
