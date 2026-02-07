# Background Jobs & Scheduled Tasks

This document describes all background jobs in the MTG Inventory application, their schedules, and how to run them manually.

## Overview

The application uses **Solid Queue** for background job processing. Jobs run automatically based on the schedules defined in `backend/config/recurring.yml`, but can also be triggered manually for testing or maintenance.

## Scheduled Jobs

### 1. Scrape EDHREC Commanders

**Job:** `ScrapeEdhrecCommandersJob`
**Schedule:**
- Development: Every Saturday at 8am
- Production: Every Sunday at 8am

**Purpose:** Fetches the top 20 EDH commanders from EDHREC and scrapes their complete decklists, including card names, quantities, and Scryfall IDs.

**What it does:**
1. Fetches commander rankings from EDHREC
2. For each commander (with real-time progress tracking):
   - Creates/updates commander record
   - Fetches complete decklist
   - Stores cards in JSONB format
3. Logs comprehensive summary with success/failure counts

**Progress Logging:**
- Start banner with timestamp
- Real-time progress: `[X/Y] (%)` for each commander
- Detailed step-by-step processing (DEBUG level)
- Individual success/failure indicators
- Final summary with statistics and timing

**Example Log Output:**

Watch logs in real-time:
```bash
# Watch job logs while scraping runs
docker compose logs -f jobs

# Or watch backend logs
docker compose logs -f backend
```

Job start:
```
================================================================================
ScrapeEdhrecCommandersJob: STARTING
Started at: 2026-02-07 15:30:00 UTC
================================================================================
ScrapeEdhrecCommandersJob: Fetching top commanders from EDHREC...
ScrapeEdhrecCommandersJob: Found 20 commanders to process
```

Individual commander processing:
```
┌─ [1/20] (5.0%) Processing: Atraxa, Praetors' Voice (Rank #1)
  └─ Commander record saved
  └─ Fetching decklist from EDHREC...
  └─ Retrieved 100 cards from decklist
  └─ Decklist saved with 100 cards
└─ ✓ SUCCESS: Atraxa, Praetors' Voice - 100 cards saved

┌─ [2/20] (10.0%) Processing: Muldrotha, the Gravetide (Rank #2)
  └─ Commander record saved
  └─ Fetching decklist from EDHREC...
  └─ Retrieved 99 cards from decklist
  └─ Decklist saved with 99 cards
└─ ✓ SUCCESS: Muldrotha, the Gravetide - 99 cards saved

... (continues for all 20 commanders) ...
```

Job completion:
```
================================================================================
ScrapeEdhrecCommandersJob: COMPLETED
================================================================================
Finished at:              2026-02-07 15:35:42 UTC
Execution time:           342.5s
--------------------------------------------------------------------------------
Total commanders:         20
Successfully scraped:     20 (100.0%)
Failed:                   0 (0.0%)
--------------------------------------------------------------------------------
Total cards processed:    1980
Average cards/commander:  99.0
================================================================================
```

Example with errors and retries:
```
┌─ [15/20] (75.0%) Processing: Example Commander (Rank #15)
ScrapeEdhrecCommandersJob: Retry 1/3 for 'Example Commander' - Network timeout
  └─ Commander record saved
  └─ Fetching decklist from EDHREC...
  └─ Retrieved 97 cards from decklist
  └─ Decklist saved with 97 cards
└─ ✓ SUCCESS: Example Commander - 97 cards saved

┌─ [16/20] (80.0%) Processing: Failing Commander (Rank #16)
ScrapeEdhrecCommandersJob: Retry 1/3 for 'Failing Commander' - Page not found
ScrapeEdhrecCommandersJob: Retry 2/3 for 'Failing Commander' - Page not found
ScrapeEdhrecCommandersJob: Retry 3/3 for 'Failing Commander' - Page not found
ScrapeEdhrecCommandersJob: Max retries exceeded for 'Failing Commander' - Page not found
└─ ✗ FAILED: Failing Commander - Page not found
```

Summary with failures:
```
================================================================================
ScrapeEdhrecCommandersJob: COMPLETED
================================================================================
Finished at:              2026-02-07 15:35:42 UTC
Execution time:           355.2s
--------------------------------------------------------------------------------
Total commanders:         20
Successfully scraped:     19 (95.0%)
Failed:                   1 (5.0%)
--------------------------------------------------------------------------------
Failed commanders:
  • Failing Commander
--------------------------------------------------------------------------------
Total cards processed:    1883
Average cards/commander:  99.1
================================================================================
```

**Log Levels:**
- **INFO**: Normal progress updates, start/completion banners
- **DEBUG**: Detailed step-by-step processing (commander save, decklist fetch, etc.)
- **WARN**: Retry attempts for transient errors
- **ERROR**: Failed commanders after max retries or unexpected errors

**Adjusting Log Verbosity:**

To see DEBUG logs (detailed step-by-step output):
```bash
# In docker-compose.yml or .env
RAILS_LOG_LEVEL=debug

# Or temporarily in Rails console
docker compose exec backend rails runner "Rails.logger.level = Logger::DEBUG; ScrapeEdhrecCommandersJob.perform_now"
```

**Manual trigger:**
```bash
# Using rake task (recommended - shows real-time progress)
docker compose exec backend rails jobs:scrape_commanders

# Using Rails console (no console output, check logs instead)
docker compose exec backend rails runner "ScrapeEdhrecCommandersJob.perform_now"

# Or enqueue for async execution
docker compose exec backend rails runner "ScrapeEdhrecCommandersJob.perform_later"
```

**Note:** The rake task automatically broadcasts log output to your console, so you'll see commander names and progress as they're scraped. Using Rails runner directly will only log to the log file.

**Duration:** Typically 2-5 minutes depending on network speed

---

### 2. Update Card Prices

**Job:** `UpdateCardPricesJob`
**Schedule:**
- Development: Not scheduled
- Production: Every day at 7am

**Purpose:** Updates market prices for all unique cards across all user collections by fetching current prices from Scryfall API.

**What it does:**
1. Identifies all unique cards in collections
2. Filters out cards already processed today (idempotent)
3. Fetches current prices in batches of 50
4. Stores price records with timestamp
5. Detects significant price changes and creates user alerts

**Manual trigger:**
```bash
# Update all cards
docker compose exec backend rails jobs:update_prices

# Update a single card
docker compose exec backend rails jobs:prices:update_card[SCRYFALL_CARD_ID]

# Using Rails console
docker compose exec backend rails runner "UpdateCardPricesJob.perform_now"
```

**Duration:** Varies based on collection size (50 cards per batch with 100ms delay)

**Rate limiting:** Built-in exponential backoff for rate limits and network errors

---

### 3. Clear Finished Jobs

**Job:** `SolidQueue::Job.clear_finished_in_batches`
**Schedule:**
- Development: Not scheduled
- Production: Every hour at minute 12

**Purpose:** Housekeeping task that removes completed job records from the database to prevent table bloat.

**What it does:**
1. Finds all finished jobs older than 1 day
2. Deletes them in batches with 300ms sleep between batches
3. Keeps failed jobs for debugging

**Manual trigger:**
```bash
# Using rake task
docker compose exec backend rails jobs:clear_finished

# Using Rails console
docker compose exec backend rails runner "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
```

---

### 4. Cache Card Image (On-Demand)

**Job:** `CacheCardImageJob`
**Schedule:** Not scheduled—triggered automatically when cards are added to inventory

**Purpose:** Pre-caches card images from Scryfall to improve page load performance.

**What it does:**
1. Downloads card image from Scryfall
2. Stores in local cache
3. Updates collection item with cached image path

**Manual trigger:**
```bash
docker compose exec backend rails jobs:cache:image[COLLECTION_ITEM_ID,IMAGE_URL]

# Using Rails console
docker compose exec backend rails runner "CacheCardImageJob.perform_now(item_id, image_url)"
```

---

## Monitoring & Debugging

### View Job Statistics

```bash
docker compose exec backend rails jobs:stats
```

Shows:
- Pending jobs count
- Running jobs count
- Finished jobs count
- Failed jobs count
- All recurring task schedules

### Watch Job Logs

```bash
# Watch job worker logs in real-time
docker compose logs -f jobs

# View backend logs (includes job execution)
docker compose logs -f backend

# View last 100 lines
docker compose logs --tail=100 jobs
```

### Rails Console

For advanced debugging:

```bash
docker compose exec backend rails console

# Check recent jobs
> SolidQueue::Job.last(10)

# Check failed jobs
> SolidQueue::Job.failed.last(5)

# Check pending jobs
> SolidQueue::Job.pending.count

# Check recurring tasks
> SolidQueue::RecurringTask.all

# Manually enqueue a job
> ScrapeEdhrecCommandersJob.perform_later

# Run a job synchronously
> UpdateCardPricesJob.perform_now
```

---

## Convenience Commands

### Run All Scheduled Jobs

For testing or manual data refresh:

```bash
docker compose exec backend rails jobs:all
```

This runs:
1. Scrape commanders
2. Update prices
3. Clear finished jobs

---

## Configuration Files

- **Job schedules:** `backend/config/recurring.yml`
- **Job classes:** `backend/app/jobs/`
- **Rake tasks:** `backend/lib/tasks/jobs.rake`
- **Solid Queue config:** `backend/config/queue.yml`

---

## Adding New Scheduled Jobs

1. **Create the job class:**
   ```ruby
   # app/jobs/my_new_job.rb
   class MyNewJob < ApplicationJob
     queue_as :default

     def perform
       # Job logic here
     end
   end
   ```

2. **Add to recurring schedule:**
   ```yaml
   # config/recurring.yml
   production:
     my_new_task:
       class: MyNewJob
       queue: default
       schedule: every day at 3am
       args: []
   ```

3. **Create rake task:**
   ```ruby
   # lib/tasks/jobs.rake
   namespace :jobs do
     desc "Run my new job"
     task my_new_job: :environment do
       puts "Running MyNewJob..."
       MyNewJob.perform_now
       puts "Completed!"
     end
   end
   ```

4. **Update documentation:**
   - Add to this file
   - Add to `CLAUDE.md`
   - Add to `lib/tasks/README.md`

---

## Troubleshooting

### Job is stuck in "running" state

```bash
docker compose exec backend rails console
> # Find the stuck job
> job = SolidQueue::Job.running.last
> # Mark it as failed
> job.failed!
```

### Job keeps failing

```bash
# Check failed jobs
docker compose exec backend rails console
> SolidQueue::Job.failed.last(5).each do |job|
>   puts "#{job.class_name}: #{job.error}"
> end
```

### Clear all jobs (dangerous!)

```bash
docker compose exec backend rails console
> SolidQueue::Job.destroy_all  # Use with caution!
```

### Restart job worker

```bash
docker compose restart jobs
```

### No logs appearing?

```bash
# Check if jobs container is running
docker compose ps jobs

# Restart jobs container
docker compose restart jobs

# Check Rails log level
docker compose exec backend rails runner "puts Rails.logger.level"
```

### Logs are truncated?

```bash
# Follow logs without truncation
docker compose logs -f --tail=1000 jobs

# View full logs file
docker compose exec backend tail -f log/development.log
```

### Job seems stuck?

Check the current job status:

```bash
docker compose exec backend rails jobs:stats
```

If a job is stuck in "running" state, you may need to restart the jobs container or manually fail the stuck job via Rails console.

---

## Performance Notes

- **Scraping:**
  - Average time per commander: ~15-20 seconds
  - Total time for 20 commanders: ~5-7 minutes
  - Network dependent (EDHREC response times vary)
  - Automatic retries for transient errors (up to 3 attempts)

- **Scraping:** Rate-limited by EDHREC response times
- **Price updates:** Rate-limited to 50 cards per batch with 100ms delays
- **Image caching:** Automatic retry with exponential backoff on failures
- **Job cleanup:** Batched deletes with sleep to avoid database locks
