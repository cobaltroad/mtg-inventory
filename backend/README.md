# MTG Inventory - Backend

Rails 8.1 API-only server for the MTG inventory management system.

See the [main README](../README.md) for Docker Compose setup and background job management.

## Tech Stack

- **Framework**: Rails 8.1 (API-only mode)
- **Ruby Version**: 3.4
- **Database**: PostgreSQL 16
- **Job Queue**: Solid Queue
- **Testing**: Minitest with fixtures
- **Code Quality**: RuboCop (Rails Omakase), Brakeman, Bundler Audit

## Local Development Setup

### Prerequisites

- Ruby 3.4
- PostgreSQL 16
- Bundler

### Installation

```bash
cd backend
bundle install
```

### Database Setup

```bash
# Create, migrate, and seed database (idempotent)
rails db:prepare

# Or manually:
rails db:create
rails db:migrate
rails db:seed
```

### Running the Server

```bash
rails server -b 0.0.0.0  # Runs on port 3000
```

The `-b 0.0.0.0` flag allows connections from Docker containers.

## Testing

### Run Tests

```bash
# All tests
rails test

# Specific test file
rails test test/models/card_test.rb

# Specific test
rails test test/models/card_test.rb:12
```

### Test Structure

- **Models**: `test/models/` - ActiveRecord model tests
- **Controllers**: `test/controllers/` - API endpoint tests
- **Jobs**: `test/jobs/` - Background job tests
- **Fixtures**: `test/fixtures/` - Test data

### Test Coverage

Tests use Minitest with fixtures for data setup. All new features should include:
- Model tests for validations and associations
- Controller tests for API endpoints
- Job tests for background processing

## Code Quality

### Linting

```bash
# Run RuboCop (Rails Omakase style)
rubocop

# Auto-correct safe violations
rubocop -a

# Auto-correct all violations (use with caution)
rubocop -A
```

### Security Analysis

```bash
# Scan for security vulnerabilities in code
brakeman

# Check for vulnerable gem versions
bundler-audit
```

## Database Management

### Migrations

```bash
# Create a migration
rails generate migration AddFieldToTable field:type

# Run pending migrations
rails db:migrate

# Rollback last migration
rails db:rollback

# Reset database (drop, create, migrate, seed)
rails db:reset
```

### Seeds

The seed file (`db/seeds.rb`) includes:
- Sample inventory items
- Test commanders
- Sample price alerts

## Authentication

The backend implements **Discord OAuth 2.0** authentication with secure session management.

### OAuth Configuration

Configure Discord OAuth in your `.env` file:

```bash
# Discord OAuth Application Credentials
DISCORD_CLIENT_ID=your_client_id
DISCORD_CLIENT_SECRET=your_client_secret
DISCORD_REDIRECT_URI=http://localhost:3001/auth/callback

# Session Configuration (production)
SESSION_SECRET=your_secure_random_secret
```

### OAuth Flow

1. **Login** - User clicks "Login with Discord"
2. **Redirect** - Backend redirects to Discord OAuth page
3. **Callback** - Discord redirects back with authorization code
4. **Token Exchange** - Backend exchanges code for access token
5. **User Creation** - User record created/updated with Discord data
6. **Session** - Secure HttpOnly cookie set for session management

### Authentication Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/discord` | GET | Initiate Discord OAuth flow |
| `/auth/callback` | GET | OAuth callback handler |
| `/auth/status` | GET | Check authentication status |
| `/auth/logout` | DELETE | Destroy user session |

### Session Management

- **Cookie-based sessions** with `HttpOnly` and `Secure` flags
- **CSRF protection** using Rails built-in mechanisms
- **Session fixation prevention** with session regeneration after login
- Sessions stored in encrypted cookies (production) or cookie store (development)

### User Model

The `User` model integrates with Discord:

```ruby
class User < ApplicationRecord
  validates :discord_id, presence: true, uniqueness: true
  validates :username, presence: true

  def self.find_or_create_by_discord(discord_data)
    # Creates or updates user from Discord OAuth response
  end
end
```

### Environment-Based Authentication

Authentication can be disabled in development mode:

```bash
# Disable auth in development (optional)
VITE_AUTH_ENABLED=false
```

Use the provided `Makefile` to toggle between dev and prod modes:

```bash
make dev   # Development mode (auth optional)
make prod  # Production mode (auth required)
```

## API Endpoints

The API is organized into namespaced controllers under `app/controllers/api/`.

### Core Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/inventory` | GET | List all inventory items |
| `/api/inventory` | POST | Add card to inventory |
| `/api/inventory/:id` | GET | Get single inventory item |
| `/api/inventory/:id` | PATCH/PUT | Update inventory item |
| `/api/inventory/:id` | DELETE | Remove from inventory |
| `/api/commanders` | GET | List EDH commanders |
| `/api/commanders/:id` | GET | Get commander with decklist |
| `/api/price_alerts` | GET | List price alerts |
| `/api/cards/search` | GET | Search cards by name |

**Note:** All API endpoints require authentication when running in production mode.

See `config/routes.rb` for the complete API reference.

### API Response Format

Standard JSON responses with appropriate HTTP status codes:

```ruby
# Success (200 OK)
{ "data": [...] }

# Created (201 Created)
{ "data": {...}, "message": "Created successfully" }

# Error (4xx/5xx)
{ "error": "Error message" }
```

## Background Jobs

Background jobs use **Solid Queue** and are located in `app/jobs/`.

### Job Classes

- **ScrapeEdhrecCommandersJob** - Fetches top commanders from EDHREC
- **ScrapeCommanderDecklistJob** - Scrapes individual commander decklists
- **UpdateCardPricesJob** - Updates card prices from Scryfall
- **CacheCardImageJob** - Pre-caches card images for faster loading

### Creating a New Job

```bash
rails generate job MyJob
```

Then implement in `app/jobs/my_job.rb`:

```ruby
class MyJobJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Job logic here
  end
end
```

### Rate Limiting

The `RateLimiter` service (`app/services/rate_limiter.rb`) enforces delays:

```ruby
RateLimiter.throttle(:edhrec) do
  # Makes request with min 2 second delay
end

RateLimiter.throttle(:scryfall) do
  # Makes request with min 100ms delay
end
```

### Job Configuration

Scheduled jobs are defined in `config/recurring.yml`:

```yaml
production:
  scrape_commanders:
    class: ScrapeEdhrecCommandersJob
    schedule: "0 8 * * 0"  # Sunday 8am
```

See the [main README](../README.md#background-jobs--scheduled-tasks) for job monitoring and manual invocation.

## Models

### Core Models

- **Card** - Represents a Magic: The Gathering card (linked to Scryfall)
- **InventoryItem** - Tracks cards in user's collection
- **Commander** - EDH commander with decklist
- **PriceAlert** - Alerts when card prices change
- **ScryfallCard** - Cached Scryfall card data

### Model Relationships

```ruby
Card
  has_many :inventory_items
  has_many :price_alerts
  belongs_to :scryfall_card

Commander
  has_many :commander_deck_cards
  has_many :cards, through: :commander_deck_cards

InventoryItem
  belongs_to :card
```

### Model Validations

Models include comprehensive validations:

```ruby
class Card < ApplicationRecord
  validates :name, presence: true
  validates :scryfall_id, presence: true, uniqueness: true
end
```

## Services

Service objects in `app/services/` handle complex business logic:

- **RateLimiter** - Rate limiting for external APIs
- **EdhrecScraper** - EDHREC website scraping
- **ScryfallImporter** - Import cards from Scryfall API

### Creating a Service

```ruby
# app/services/my_service.rb
class MyService
  def self.call(*args)
    new(*args).call
  end

  def initialize(*args)
    # Setup
  end

  def call
    # Service logic
  end
end
```

## Configuration

### Environment Variables

Configure via `.env` file or environment:

```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/mtg_inventory

# Rails Environment
RAILS_ENV=development
RAILS_LOG_LEVEL=info
APP_ENV=development  # Used for environment-specific configs

# Discord OAuth (required for production)
DISCORD_CLIENT_ID=your_client_id
DISCORD_CLIENT_SECRET=your_client_secret
DISCORD_REDIRECT_URI=http://localhost:3001/auth/callback

# Session Security (required for production)
SESSION_SECRET=your_secure_random_secret

# External API Configuration
EDHREC_BASE_URL=https://edhrec.com
SCRYFALL_API_BASE=https://api.scryfall.com
```

### Credentials

Edit encrypted credentials:

```bash
rails credentials:edit
```

## Deployment

The backend is containerized with Docker. See [main README](../README.md#quick-start) for Docker Compose setup.

### Production Considerations

- Set `RAILS_ENV=production` and `APP_ENV=production`
- Configure proper database credentials
- **Configure Discord OAuth credentials** (required for authentication)
- **Set secure SESSION_SECRET** (generate with `rails secret`)
- Enable SSL in production for secure cookies
- Set up proper logging and monitoring
- Configure rate limiting based on API quotas
- Ensure `DISCORD_REDIRECT_URI` matches your production domain

## Troubleshooting

### Common Issues

**Database connection errors:**
```bash
# Check PostgreSQL is running
docker compose ps db

# Reset database
rails db:reset
```

**Job queue issues:**
```bash
# Check job queue status
rails jobs:stats

# Clear failed jobs
rails jobs:clear_finished
```

**Missing dependencies:**
```bash
bundle install
```

## Contributing

- Follow Rails Omakase style guide (enforced by RuboCop)
- Write tests for all new features
- Run linting before committing: `rubocop -a`
- Ensure all tests pass: `rails test`
- Document API endpoints in this README

## Additional Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Solid Queue Documentation](https://github.com/rails/solid_queue)
- [Scryfall API Documentation](https://scryfall.com/docs/api)
- [Main Project README](../README.md)
