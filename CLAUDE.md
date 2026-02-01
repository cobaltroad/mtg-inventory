# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MTG (Magic: The Gathering) inventory management system. Full-stack application with:
- **Backend**: Rails 8.1 API-only (Ruby 3.4)
- **Frontend**: SvelteKit 2 with TypeScript
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
```

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
