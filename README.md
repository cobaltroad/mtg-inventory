# MTG Inventory Management System

A full-stack application for managing Magic: The Gathering card inventories with automated price tracking and EDH commander deck analysis.

## Architecture Overview

- **Backend**: Rails 8.1 API-only server (Ruby 3.4) → [backend/README.md](backend/README.md)
- **Frontend**: SvelteKit 2 with TypeScript → [frontend/README.md](frontend/README.md)
- **Database**: PostgreSQL 16
- **Job Queue**: Solid Queue for background processing
- **Deployment**: Docker Compose

## Quick Start

### Prerequisites

- Docker and Docker Compose
- (Optional) Ruby 3.4 and Node.js 20+ for local development

### Running with Docker Compose (Recommended)

1. **Start all services:**
   ```bash
   docker compose up
   ```

2. **Access the application:**
   - Frontend: http://localhost:3001
   - Backend API: http://localhost:3000
   - PostgreSQL: localhost:5433

The Docker setup includes four services:
- `backend` - Rails API server
- `frontend` - SvelteKit application
- `db` - PostgreSQL database
- `jobs` - Background job processor (Solid Queue)

### Initial Setup

On first run, the database will be automatically created, migrated, and seeded. To manually reset:

```bash
docker compose exec backend rails db:reset
```

## Background Jobs & Scheduled Tasks

The application uses **Solid Queue** for background job processing, running in a dedicated Docker container for isolation and reliability.

### Scheduled Jobs

Jobs are configured in `backend/config/recurring.yml`:

| Job | Schedule | Description |
|-----|----------|-------------|
| **ScrapeEdhrecCommandersJob** | Every Saturday 8am (dev)<br>Every Sunday 8am (prod) | **Discovery Phase**: Fetches top 20 EDH commanders from EDHREC. Schedules individual decklist jobs 1 hour apart. |
| **ScrapeCommanderDecklistJob** | Dynamically scheduled<br>(1 hour apart) | **Decklist Phase**: Scrapes an individual commander's decklist and imports cards. |
| **UpdateCardPricesJob** | Every 2 days at 7am (dev)<br>Every day at 7am (prod) | Updates market prices for all cards from Scryfall |
| **clear_solid_queue_finished_jobs** | Every hour at :12 (prod) | Cleans up completed job records older than 1 day |

### Distributed Scraping Architecture

The commander scraping system uses a **two-phase distributed approach**:

1. **Weekly Discovery** - `ScrapeEdhrecCommandersJob` fetches the top 20 commanders list and creates/updates commander records
2. **Distributed Decklist Scraping** - Individual `ScrapeCommanderDecklistJob` jobs are scheduled **1 hour apart**, spreading the load over ~20 hours

**Rate Limiting** (enforced by `RateLimiter` service):
- EDHREC requests: minimum 2 second delay
- Scryfall API requests: minimum 100ms delay
- 429 responses: exponential backoff with retries

This reduces peak request rate from ~20 commanders/minute to 1 commander/hour while maintaining reliability.

### Manual Job Invocation

Run jobs manually using rake tasks (shows real-time progress):

```bash
# Commander scraping
docker compose exec backend rails jobs:scrape_commanders        # Discovery only
docker compose exec backend rails jobs:scrape_commander_decklist[COMMANDER_ID]  # Single commander
docker compose exec backend rails jobs:all                      # All scheduled jobs

# Price updates
docker compose exec backend rails jobs:update_prices
docker compose exec backend rails jobs:prices:update_card[SCRYFALL_CARD_ID]  # Single card

# Maintenance
docker compose exec backend rails jobs:clear_finished           # Clean up old jobs
docker compose exec backend rails jobs:stats                    # View queue statistics
```

**Alternative (Rails console):**
```bash
docker compose exec backend rails console
> ScrapeEdhrecCommandersJob.perform_now
> ScrapeCommanderDecklistJob.perform_now(commander)
> SolidQueue::Job.last(5)  # Check recent jobs
```

**Note:** Rake tasks broadcast progress to your console. Using Rails console/runner only logs to the log file.

### Monitoring Jobs

**Watch job logs in real-time:**
```bash
docker compose logs -f jobs
```

**Check job status and statistics:**
```bash
docker compose exec backend rails jobs:stats
```
Shows queue statistics, next scheduled runs, last execution status, and **error summaries for failed jobs**.

**View recent job failures:**
```bash
docker compose exec backend rails jobs:failures
```
Displays the last 20 failed job executions from the past 7 days with detailed error messages, timestamps, and metrics.

**Clean up old log files:**
```bash
docker compose exec backend rails jobs:clean_logs
```
Removes old rotated log files to free up disk space.

**Access Solid Queue Mission Control (if enabled):**
```
http://localhost:3000/solid_queue
```

**View recent job history:**
```bash
docker compose exec backend rails console
> PriceUpdateExecution.order(started_at: :desc).limit(5)  # Recent price updates
> ScraperExecution.order(started_at: :desc).limit(5)      # Recent scraper runs
> SolidQueue::Job.last(10)                                # Recent Solid Queue jobs
```

## API Integration

The frontend communicates with the backend API through a proxy configured in `frontend/src/hooks.server.ts`. All API requests use the pattern:

```typescript
import { base } from '$app/paths';
const response = await fetch(`${base}/api/endpoint`);
```

This ensures proper routing in all environments (development, Docker, production).

**Key API endpoints:**
- `GET /api/inventory` - List inventory items
- `GET /api/commanders` - List EDH commanders
- `GET /api/price_alerts` - Active price alerts
- `POST /api/inventory` - Add card to inventory

See `backend/config/routes.rb` for the complete API reference.

## Development

### Backend Development
See [backend/README.md](backend/README.md) for:
- Ruby/Rails setup
- Database management
- Testing with Minitest
- Linting with RuboCop
- Security scanning

### Frontend Development
See [frontend/README.md](frontend/README.md) for:
- Node.js/SvelteKit setup
- Component architecture
- Testing with Vitest
- Linting and formatting
- UI component library

### Environment Variables

Copy the example environment file:
```bash
cp .env.example .env
```

Edit `.env` with your configuration. Key variables:
- `DATABASE_URL` - PostgreSQL connection string
- `RAILS_ENV` - Environment (development/production)
- `NODE_ENV` - Node environment

## Project Structure

```
.
├── backend/              # Rails 8.1 API server
│   ├── app/
│   │   ├── controllers/  # API endpoints
│   │   ├── models/       # ActiveRecord models
│   │   └── jobs/         # Background jobs (Solid Queue)
│   ├── config/           # Rails configuration
│   │   └── recurring.yml # Scheduled job definitions
│   ├── db/               # Migrations and seeds
│   └── test/             # Minitest suite
│
├── frontend/             # SvelteKit application
│   ├── src/
│   │   ├── routes/       # Pages (filesystem-based routing)
│   │   └── lib/          # Shared components and utilities
│   ├── static/           # Static assets
│   └── build/            # Production output
│
├── docker-compose.yml    # Container orchestration
└── CLAUDE.md            # Development guidelines for Claude Code
```

## Testing

**Backend tests:**
```bash
docker compose exec backend rails test
```

**Frontend tests:**
```bash
docker compose exec frontend npm run test
```

**Full test suite:**
```bash
docker compose exec backend rails test && docker compose exec frontend npm run test
```

## Contributing

This project uses a backlog-manager agent for work tracking. All features and bugs should be:
1. Written as user stories with personas
2. Include BDD acceptance criteria (Given-When-Then format)
3. Added to GitHub Projects Prioritized Backlog before implementation

See `.claude/agents/backlog-manager.md` for details.

## License

[Add license information]
