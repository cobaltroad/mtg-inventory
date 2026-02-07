# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MTG (Magic: The Gathering) inventory management system. Full-stack application with:
- **Backend**: Rails 8.1 API-only (Ruby 3.4)
- **Frontend**: SvelteKit 2 with TypeScript, Skeleton UI v4, Tailwind CSS v4
- **Database**: PostgreSQL 16
- **Deployment**: Docker Compose

## Development Commands

### Docker Compose (Recommended)
```bash
# Start all services
docker compose up

# Backend: http://localhost:3000
# Frontend: http://localhost:3001
# PostgreSQL: localhost:5433
```

### Backend (Rails)
```bash
cd backend
bundle install
rails db:prepare          # Create/migrate/seed idempotently
rails server -b 0.0.0.0   # Start on port 3000

# Testing & Linting
rails test                # Run test suite
rails test test/path/to/test_file.rb  # Single test file
rubocop                   # Lint (Rails Omakase style)
brakeman                  # Security analysis
bundler-audit             # Gem vulnerability scan
```

### Frontend (SvelteKit)
```bash
cd frontend
npm install
npm run dev               # Dev server (port 5173 local, 3001 docker)

# Testing & Linting
npm run check             # TypeScript type checking
npm run lint              # Prettier + ESLint
npm run format            # Auto-format with Prettier
npm run build             # Production build
npm run test              # Run test suite (Vitest)
npm run test:watch        # Run tests in watch mode
```

**UI Stack:**
- **Skeleton UI v4** - Component library and design system
- **Tailwind CSS v4** - Utility-first CSS framework
- **Lucide Svelte** - Icon library
- **Svelte 5** - Reactive UI framework with runes

**Styling Approach:**
- Utility-first design with Tailwind classes
- Skeleton UI theme: Crimson
- Dark mode support via `class` strategy
- Semantic HTML with accessibility features

**Frontend Coding Guidelines:**

- **API Calls**: Always use `${base}/api` for API endpoints to ensure proper routing in all environments
  ```typescript
  import { base } from '$app/paths';

  // ✅ Correct - works in Docker, production, and dev
  const response = await fetch(`${base}/api/inventory`, { ... });

  // ❌ Wrong - hardcoded URLs break in Docker/production
  const response = await fetch('http://localhost:3000/api/inventory', { ... });
  ```

- **Import Patterns**: Use SvelteKit path aliases for clean imports
  ```typescript
  import Component from '$lib/components/Component.svelte';
  import { util } from '$lib/utils/util';
  import type { Type } from '$lib/types/type';
  ```

- **State Management**: Use Svelte 5 runes (`$state`, `$derived`, `$effect`, `$props`)
  ```typescript
  let count = $state(0);
  let doubled = $derived(count * 2);
  ```

- **Error Handling**: Always handle API errors with user-friendly messages
  ```typescript
  try {
    const response = await fetch(`${base}/api/endpoint`, { ... });
    if (!response.ok) throw new Error('Operation failed');
    // handle success
  } catch (err) {
    console.error('Error:', err);
    // show user-friendly error message
  }
  ```

## Background Jobs & Scheduled Tasks

The application uses **Solid Queue** for background job processing. Jobs run in a separate Docker container (`mtg_jobs`).

### Scheduled Jobs

Jobs are configured in `backend/config/recurring.yml` and run automatically:

| Job | Schedule | Description |
|-----|----------|-------------|
| **ScrapeEdhrecCommandersJob** | Every Saturday 8am (dev)<br>Every Sunday 8am (prod) | Scrapes top 20 EDH commanders and their decklists from EDHREC |
| **UpdateCardPricesJob** | Every day at 7am (prod) | Updates market prices for all cards in collections from Scryfall |
| **clear_solid_queue_finished_jobs** | Every hour at :12 (prod) | Cleans up completed job records older than 1 day |

### Manual Job Triggers

Run jobs manually using rake tasks (useful for testing/maintenance):

```bash
# Using Docker with rake tasks (recommended - shows real-time progress)
docker compose exec backend rails jobs:scrape_commanders
docker compose exec backend rails jobs:update_prices
docker compose exec backend rails jobs:clear_finished

# Run all scheduled jobs
docker compose exec backend rails jobs:all

# Update a single card's price
docker compose exec backend rails jobs:prices:update_card[SCRYFALL_CARD_ID]

# View job queue statistics
docker compose exec backend rails jobs:stats

# Using Rails console for more control (logs to file only)
docker compose exec backend rails console
> ScrapeEdhrecCommandersJob.perform_now    # Run synchronously
> ScrapeEdhrecCommandersJob.perform_later  # Enqueue for async execution
> SolidQueue::Job.last(5)                   # Check recent jobs
```

**Note:** Rake tasks broadcast progress to your console, showing commander names and status in real-time. Using Rails console/runner directly only logs to the log file.

### Monitoring Jobs

```bash
# Watch job logs in real-time
docker compose logs -f jobs

# Check job status
docker compose exec backend rails jobs:stats

# Access Solid Queue mission control (if enabled)
# Visit: http://localhost:3000/solid_queue
```

**Note:** The `CacheCardImageJob` is not scheduled—it's triggered automatically when cards are added to inventory to pre-cache images for faster page loads.

## Architecture

```
backend/                  # Rails 8.1 API server
├── app/
│   ├── controllers/      # API endpoints
│   ├── models/           # ActiveRecord models
│   └── jobs/             # Background jobs (Solid Queue)
├── config/               # Rails configuration
├── db/                   # Migrations and seeds
└── test/                 # Minitest suite

frontend/                 # SvelteKit application
├── src/
│   ├── routes/           # Pages (filesystem-based routing)
│   └── lib/              # Shared components and utilities
├── static/               # Static assets
└── build/                # Production output
```

## Key Configuration Files

- `docker-compose.yml` - Container orchestration
- `backend/config/database.yml` - PostgreSQL connections
- `frontend/vite.config.ts` - Vite bundler with API proxy
- `.env` / `.env.example` - Environment variables

## Project Management

This project uses a backlog-manager agent for work tracking. All features and bugs should be:
1. Written as user stories with personas (see `.claude/agents/backlog-manager.md`)
2. Include BDD acceptance criteria (Given-When-Then format)
3. Added to GitHub Projects Prioritized Backlog before implementation
