# Rake Tasks

This directory contains custom rake tasks for the MTG Inventory application.

## Available Tasks

### Background Jobs

Run `rails -T jobs` to see all available job-related tasks, or use these common commands:

#### Scraping Tasks

```bash
# Scrape EDHREC commanders (normally runs every Saturday/Sunday at 8am)
rails jobs:scrape_commanders
```

#### Price Update Tasks

```bash
# Update all card prices (normally runs daily at 7am in production)
rails jobs:update_prices

# Update a single card's price by Scryfall ID
rails jobs:prices:update_card[SCRYFALL_CARD_ID]
```

#### Maintenance Tasks

```bash
# Clear finished Solid Queue jobs (normally runs hourly in production)
rails jobs:clear_finished

# View job queue statistics
rails jobs:stats
```

#### Convenience Tasks

```bash
# Run ALL scheduled jobs (useful for testing)
rails jobs:all
```

## Usage with Docker

All commands should be run through Docker:

```bash
docker compose exec backend rails jobs:scrape_commanders
docker compose exec backend rails jobs:update_prices
docker compose exec backend rails jobs:stats
```

## Task Definitions

All job-related tasks are defined in `lib/tasks/jobs.rake`.

## Adding New Tasks

When creating new scheduled jobs:

1. Create the job class in `app/jobs/`
2. Add the schedule to `config/recurring.yml`
3. Add a manual trigger rake task in `lib/tasks/jobs.rake`
4. Update the CLAUDE.md documentation with schedule and usage info
