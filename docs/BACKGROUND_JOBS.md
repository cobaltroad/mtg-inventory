# Background Jobs & Scheduled Tasks

This document describes all background jobs in the MTG Inventory application, their schedules, and how to run them manually.

## Overview

The application uses **Solid Queue** for background job processing. Jobs run automatically based on the schedules defined in `backend/config/recurring.yml`, but can also be triggered manually for testing or maintenance.

## Distributed Scraping Architecture

The commander scraping system uses a **two-phase distributed approach** to respect EDHREC's rate limits and avoid overwhelming their servers:

1. **Weekly Discovery Phase** - `ScrapeEdhrecCommandersJob` fetches the top 20 commanders list and creates/updates commander records **without** scraping decklists
2. **Distributed Decklist Phase** - Individual `ScrapeCommanderDecklistJob` jobs are scheduled **1 hour apart**, spreading the load over ~20 hours throughout the week

**Rate Limiting** (enforced by `RateLimiter` service):
- EDHREC requests: minimum 2 second delay between requests
- Scryfall API requests: minimum 100ms delay between requests
- 429 responses: exponential backoff with automatic retries

This architecture reduces peak request rate from ~20 commanders/minute to 1 commander/hour while maintaining reliability through isolated job execution and independent failure handling.

---

## Scheduled Jobs

### 1. Commander Discovery (Weekly)

**Job:** `ScrapeEdhrecCommandersJob`
**Schedule:**
- Development: Every Saturday at 8am
- Production: Every Sunday at 8am

**Purpose:** **Discovery Phase Only** - Fetches the top 20 EDH commander rankings from EDHREC and creates/updates commander records. Does NOT scrape decklists. Instead, schedules individual `ScrapeCommanderDecklistJob` jobs 1 hour apart for distributed processing.

**What it does:**
1. Fetches commander rankings from EDHREC (list only)
2. For each commander (with real-time progress tracking):
   - Creates/updates commander record with name, rank, and URL
   - Schedules a `ScrapeCommanderDecklistJob` for 1 hour later (incrementing by 1 hour for each)
3. Logs comprehensive summary with scheduling status

**Progress Logging:**
- Start banner with timestamp
- Real-time progress: `[X/Y] (%)` for each commander
- Shows scheduled time for each decklist job
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
ScrapeEdhrecCommandersJob: STARTING DISCOVERY PHASE
Started at: 2026-02-07 08:00:00 UTC
================================================================================
ScrapeEdhrecCommandersJob: Fetching top commanders from EDHREC...
ScrapeEdhrecCommandersJob: Found 20 commanders to process
```

Individual commander processing:
```
┌─ [1/20] (5.0%) Processing: Atraxa, Praetors' Voice (Rank #1)
  └─ Commander record saved
  └─ Scheduled ScrapeCommanderDecklistJob for 2026-02-07 09:00:00 UTC (in 1 hour)
└─ ✓ SUCCESS: Atraxa, Praetors' Voice - Decklist job scheduled

┌─ [2/20] (10.0%) Processing: Muldrotha, the Gravetide (Rank #2)
  └─ Commander record saved
  └─ Scheduled ScrapeCommanderDecklistJob for 2026-02-07 10:00:00 UTC (in 2 hours)
└─ ✓ SUCCESS: Muldrotha, the Gravetide - Decklist job scheduled

... (continues for all 20 commanders) ...
```

Job completion:
```
================================================================================
ScrapeEdhrecCommandersJob: DISCOVERY PHASE COMPLETED
================================================================================
Finished at:              2026-02-07 08:02:15 UTC
Execution time:           135.2s
--------------------------------------------------------------------------------
Total commanders:         20
Successfully scheduled:   20 (100.0%)
Failed:                   0 (0.0%)
--------------------------------------------------------------------------------
Decklist jobs scheduled over next 20 hours
First job starts:         2026-02-07 09:00:00 UTC
Last job completes:       2026-02-08 04:00:00 UTC
================================================================================
```

Example with failures:
```
┌─ [15/20] (75.0%) Processing: Example Commander (Rank #15)
  └─ Commander record saved
  └─ Scheduled ScrapeCommanderDecklistJob for 2026-02-07 23:00:00 UTC
└─ ✓ SUCCESS: Example Commander - Decklist job scheduled

┌─ [16/20] (80.0%) Processing: Failing Commander (Rank #16)
  └─ ERROR: Failed to fetch commander data - Network timeout
└─ ✗ FAILED: Failing Commander - Network timeout
```

Summary with failures:
```
================================================================================
ScrapeEdhrecCommandersJob: DISCOVERY PHASE COMPLETED
================================================================================
Finished at:              2026-02-07 08:02:30 UTC
Execution time:           150.3s
--------------------------------------------------------------------------------
Total commanders:         20
Successfully scheduled:   19 (95.0%)
Failed:                   1 (5.0%)
--------------------------------------------------------------------------------
Failed commanders:
  • Failing Commander
--------------------------------------------------------------------------------
Decklist jobs scheduled over next 19 hours
================================================================================
```

**Log Levels:**
- **INFO**: Normal progress updates, start/completion banners, job scheduling
- **DEBUG**: Detailed step-by-step processing (commander save, job scheduling details)
- **ERROR**: Failed commanders or scheduling errors

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

**Note:** The rake task automatically broadcasts log output to your console, so you'll see commander names and job scheduling as they're processed. Using Rails runner directly will only log to the log file.

**Duration:** Typically 1-3 minutes (discovery only, no decklist scraping)

---

### 2. Commander Decklist Scraping (Distributed)

**Job:** `ScrapeCommanderDecklistJob`
**Schedule:** Dynamically scheduled by `ScrapeEdhrecCommandersJob` with 1-hour spacing
- First job: 1 hour after discovery completes
- Subsequent jobs: 1 hour apart
- Total duration: ~20 hours to process all commanders

**Purpose:** **Decklist Phase** - Scrapes an individual commander's complete decklist from EDHREC, including card names, quantities, and Scryfall IDs. Runs independently for each commander to isolate failures and distribute load.

**What it does:**
1. Fetches the commander record
2. Scrapes the complete decklist from EDHREC
3. Processes all cards with Scryfall lookups
4. Stores cards in JSONB format
5. Updates commander record with success/failure status

**Rate Limiting:**
- EDHREC requests: minimum 2 second delay between requests
- Scryfall API requests: minimum 100ms delay between requests
- Automatic retry with exponential backoff for 429 responses

**Progress Logging:**
- Job start with commander name
- Step-by-step processing (fetch, parse, store)
- Individual card processing (DEBUG level)
- Success/failure summary

**Example Log Output:**

Job start:
```
================================================================================
ScrapeCommanderDecklistJob: STARTING
Commander: Atraxa, Praetors' Voice (ID: 123)
Started at: 2026-02-07 09:00:00 UTC
================================================================================
```

Processing:
```
ScrapeCommanderDecklistJob: Fetching decklist from EDHREC...
ScrapeCommanderDecklistJob: Retrieved 100 cards from decklist
ScrapeCommanderDecklistJob: Processing cards with Scryfall lookups...
ScrapeCommanderDecklistJob: [1/100] Sol Ring - Found on Scryfall
ScrapeCommanderDecklistJob: [2/100] Command Tower - Found on Scryfall
... (DEBUG level shows all cards) ...
ScrapeCommanderDecklistJob: Decklist saved with 100 cards
```

Job completion:
```
================================================================================
ScrapeCommanderDecklistJob: COMPLETED
================================================================================
Commander:       Atraxa, Praetors' Voice
Finished at:     2026-02-07 09:03:42 UTC
Execution time:  222.5s
--------------------------------------------------------------------------------
Cards processed: 100
Success:         ✓
================================================================================
```

Example with errors:
```
================================================================================
ScrapeCommanderDecklistJob: STARTING
Commander: Example Commander (ID: 456)
Started at: 2026-02-07 15:00:00 UTC
================================================================================
ScrapeCommanderDecklistJob: Fetching decklist from EDHREC...
ScrapeCommanderDecklistJob: ERROR - Retry 1/3: Network timeout
ScrapeCommanderDecklistJob: Retry 2/3: Network timeout
ScrapeCommanderDecklistJob: Retry 3/3: Network timeout
ScrapeCommanderDecklistJob: Max retries exceeded
================================================================================
ScrapeCommanderDecklistJob: FAILED
================================================================================
Commander:       Example Commander
Finished at:     2026-02-07 15:02:15 UTC
Error:           Network timeout after 3 retries
================================================================================
```

**Manual trigger:**
```bash
# Scrape a specific commander's decklist
docker compose exec backend rails jobs:scrape_commander_decklist[COMMANDER_ID]

# Using Rails console
docker compose exec backend rails runner "ScrapeCommanderDecklistJob.perform_now(Commander.find(COMMANDER_ID))"

# Or enqueue for async execution
docker compose exec backend rails runner "ScrapeCommanderDecklistJob.perform_later(Commander.find(COMMANDER_ID))"
```

**Duration:** Typically 2-4 minutes per commander depending on:
- Decklist size (usually 99-100 cards)
- Network speed
- Scryfall API response times
- Rate limiting delays (2s EDHREC + 100ms per Scryfall lookup)

---

### 3. Update Card Prices

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

### 4. Clear Finished Jobs

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

### 5. Cache Card Image (On-Demand)

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
1. Scrape commanders (discovery phase - schedules decklist jobs)
2. Update prices
3. Clear finished jobs

**Note:** This does NOT trigger individual commander decklist scraping - those jobs are scheduled automatically by the discovery job with 1-hour spacing.

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

- **Commander Discovery (ScrapeEdhrecCommandersJob):**
  - Discovery phase only: ~1-3 minutes for 20 commanders
  - Fetches commander list without decklists
  - Schedules individual decklist jobs with 1-hour spacing
  - Minimal EDHREC load (single rankings page request)

- **Commander Decklist Scraping (ScrapeCommanderDecklistJob):**
  - Per commander: ~2-4 minutes depending on decklist size
  - Distributed: 1 hour apart to respect rate limits
  - Total time to process all 20 commanders: ~20 hours
  - Rate-limited (EDHREC: 2s, Scryfall: 100ms per card)
  - Automatic retries for transient errors (up to 3 attempts)
  - Isolated failures don't affect other commanders

- **Rate Limiting (RateLimiter service):**
  - EDHREC: minimum 2 second delay between requests
  - Scryfall: minimum 100ms delay between requests
  - 429 handling: exponential backoff with retries
  - Thread-safe for concurrent job execution

- **Price updates:** Rate-limited to 50 cards per batch with 100ms delays
- **Image caching:** Automatic retry with exponential backoff on failures
- **Job cleanup:** Batched deletes with sleep to avoid database locks
