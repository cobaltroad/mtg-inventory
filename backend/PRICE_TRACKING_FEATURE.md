# Card Price Tracking Feature

This document describes the card price tracking feature implemented for GitHub issue #64.

## Overview

The price tracking feature fetches and stores daily market prices for Magic: The Gathering cards from the Scryfall API. It supports USD, USD foil, and USD etched price variants.

## Components

### Database Schema

**Table: `card_prices`**
- `id` (bigint, primary key)
- `card_id` (string, not null, indexed) - Scryfall card UUID
- `usd_cents` (integer, nullable) - Normal card price in cents
- `usd_foil_cents` (integer, nullable) - Foil card price in cents
- `usd_etched_cents` (integer, nullable) - Etched card price in cents
- `fetched_at` (timestamp, not null) - When price was fetched
- `created_at` (timestamp, not null)
- Composite index on `(card_id, fetched_at DESC)` for efficient queries

### Model: CardPrice

Location: `app/models/card_price.rb`

**Validations:**
- Requires `card_id` and `fetched_at`
- Price fields must be non-negative integers (if present)
- Price fields can be nil (for unavailable prices)

**Methods:**
- `CardPrice.latest_for(card_id)` - Returns most recent price for a card

### Service: CardPriceService

Location: `app/services/card_price_service.rb`

**Responsibilities:**
- Fetches price data from Scryfall API
- Converts dollar amounts to cents
- Implements 24-hour caching (configurable via `CARD_PRICE_CACHE_TTL`)
- Handles rate limiting with exponential backoff
- Retries network errors up to 3 times
- Logs info for missing prices, errors for failures

**Usage:**
```ruby
service = CardPriceService.new(card_id: "some-uuid")
price_data = service.call
# Returns: { card_id:, usd_cents:, usd_foil_cents:, usd_etched_cents:, fetched_at: }
# Returns nil if card not found
```

**Error Handling:**
- Raises `CardPriceService::RateLimitError` on 429 response
- Raises `CardPriceService::NetworkError` on connection failures
- Raises `CardPriceService::TimeoutError` on request timeout
- Raises `CardPriceService::InvalidResponseError` on invalid JSON

### Job: UpdateCardPricesJob

Location: `app/jobs/update_card_prices_job.rb`

**Responsibilities:**
- Fetches prices using CardPriceService
- Creates CardPrice record with fetched data
- Automatically retries on rate limit (5 attempts) and network errors (3 attempts)

**Usage:**
```ruby
# Enqueue immediately
UpdateCardPricesJob.perform_later("card-uuid")

# Enqueue with delay
UpdateCardPricesJob.set(wait: 1.hour).perform_later("card-uuid")

# Perform synchronously (testing)
UpdateCardPricesJob.perform_now("card-uuid")
```

## Running the Migration

```bash
# Development
rails db:migrate

# Test
RAILS_ENV=test rails db:migrate

# Production
RAILS_ENV=production rails db:migrate
```

## Running Tests

```bash
# All price-related tests
rails test test/models/card_price_test.rb
rails test test/services/card_price_service_test.rb
rails test test/jobs/update_card_prices_job_test.rb

# Or run all tests
rails test
```

## Test Coverage

The implementation includes comprehensive test coverage:

### CardPrice Model Tests (19 tests)
- Validations for all fields
- Nullable price handling
- Latest price query functionality
- Multiple prices for same card
- Database constraints and timestamps

### CardPriceService Tests (21 tests)
- Successful price fetching and conversion
- Partial and missing price handling
- 24-hour caching behavior
- Rate limiting with exponential backoff
- Network error retry logic (up to 3 attempts)
- Error logging
- Edge cases (zero prices, expensive cards, decimal rounding)

### UpdateCardPricesJob Tests (14 tests)
- Job enqueuing and execution
- CardPrice record creation
- Error handling with retry
- Logging behavior
- Idempotency and multiple updates
- Parameter validation

**Total: 54 comprehensive tests covering all acceptance criteria**

## Usage Examples

### Fetch and Store Prices for a Card

```ruby
# Background job (recommended)
UpdateCardPricesJob.perform_later("card-uuid-123")

# Direct service call
service = CardPriceService.new(card_id: "card-uuid-123")
price_data = service.call
if price_data
  CardPrice.create!(price_data)
end
```

### Query Latest Price

```ruby
latest_price = CardPrice.latest_for("card-uuid-123")
if latest_price
  puts "USD: $#{latest_price.usd_cents / 100.0}" if latest_price.usd_cents
  puts "Foil: $#{latest_price.usd_foil_cents / 100.0}" if latest_price.usd_foil_cents
  puts "Fetched at: #{latest_price.fetched_at}"
end
```

### Schedule Regular Updates

```ruby
# In a rake task or initializer
inventory_cards = CollectionItem.distinct.pluck(:card_id)
inventory_cards.each do |card_id|
  UpdateCardPricesJob.set(wait: rand(1..60).minutes).perform_later(card_id)
end
```

## Configuration

Environment variables:

- `CARD_PRICE_CACHE_TTL` - Cache duration in seconds (default: 86400 = 24 hours)

## Implementation Notes

### Why Cents Instead of Dollars?

Storing prices as cents (integers) avoids floating-point precision issues:
- `10.50` dollars → `1050` cents
- Ensures exact calculations for inventory valuation
- No rounding errors when summing prices

### Caching Strategy

- Prices are cached for 24 hours to reduce API calls
- Cache key: `card_price:#{card_id}`
- Service handles cache internally (transparent to callers)

### Error Handling Philosophy

- **Rate Limits**: Retry with exponential backoff (service + job retry)
- **Network Errors**: Retry up to 3 times with delays
- **Missing Prices**: Log info, store null values (valid state)
- **Not Found (404)**: Return nil, don't create record

### Index Optimization

The composite index `(card_id, fetched_at DESC)` allows PostgreSQL to efficiently:
1. Filter by card_id
2. Sort by fetched_at in descending order
3. Return the first row (latest price) without a full table scan

## Future Enhancements

Potential improvements (not in scope for issue #64):

- Schedule automatic daily price updates for inventory cards
- API endpoint to retrieve price history
- Price trend analysis and notifications
- Support for other currencies (EUR, etc.)
- Bulk price updates for better API efficiency
