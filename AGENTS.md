# Agent Guidelines for MTG Inventory

This is a SvelteKit + Rails application for managing a Magic: The Gathering card collection.

## Project Structure

```
/home/ron/mtg-inventory/
├── frontend/          # SvelteKit 5 + TypeScript + TailwindCSS 4
│   ├── src/
│   │   ├── lib/       # Shared components, services, utilities
│   │   └── routes/    # SvelteKit routes/pages
│   └── tests/         # Vitest tests (*.test.ts)
└── backend/           # Rails 8 API
    ├── app/           # Models, controllers, services
    ├── test/          # Minitest tests
    └── lib/tasks/     # Rake tasks
```

---

## Commands

### Frontend (SvelteKit)

```bash
# Development
cd frontend && npm run dev

# Build & Type Check
npm run build          # Production build
npm run check          # TypeScript + Svelte type checking
npm run check:watch    # Watch mode for type checking

# Linting & Formatting
npm run lint           # Run ESLint + Prettier
npm run format         # Auto-format with Prettier

# Testing
npm run test           # Run all tests once (Vitest)
npm run test:watch     # Watch mode for development

# Single test file
npm run test -- src/routes/inventory/inventory.test.ts

# Single test (alternative - run specific test)
npm run test -- --reporter=verbose src/lib/utils/format.test.ts -t "test_name"
```

### Backend (Rails)

```bash
# Start development server
cd backend && bin/rails server

# Linting & Code Style
bundle exec rubocop                              # Run RuboCop
bundle exec rubocop -a                           # Auto-fix issues

# Testing
RAILS_ENV=test bin/rails test                              # Run all tests
RAILS_ENV=test bin/rails test test/models/user_test.rb     # Single test file
RAILS_ENV=test bin/rails test -n test_name                 # Single test by name
RAILS_ENV=test bin/rails test -n "/user/"                 # Run tests matching pattern

# Database
RAILS_ENV=test bin/rails db:test:prepare    # Setup test database

# Rake tasks
bundle exec rake -T                          # List available tasks
```

### Docker

```bash
# Run frontend tests
docker compose exec frontend npm run test

# Run backend tests
docker compose exec backend bin/rails test

# Run backend tests with specific test
docker compose exec backend env RAILS_ENV=test bin/rails test test/models/user_test.rb
```

---

## Code Style Guidelines

### General

- **Self-documenting code**: Write code that explains itself through clear naming
- **Comments**: Add comments only when the "why" isn't obvious from the code
- **SOLID principles**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **DRY**: Don't repeat yourself; extract common logic into utilities

### TypeScript / Svelte

- **Types**: Always use TypeScript types. Avoid `any`. Use `unknown` when type is truly unknown.
- **Interfaces vs Types**: Use `interface` for object shapes, `type` for unions/aliases
- **Null handling**: Use optional chaining (`?.`) and nullish coalescing (`??`)
- **Imports**: Use path aliases (`$lib/`, `$app/`) for internal modules
- **Svelte 5**: Use runes (`$state`, `$derived`, `$effect`) for reactivity

```typescript
// Good
interface Card {
  id: string;
  name: string;
  prices: Price[];
}

// Avoid
const card: any = { ... };
```

### Ruby / Rails

- **RuboCop**: Follow `rubocop-rails-omakase` style (the default)
- **Naming**: `snake_case` for methods/variables, `CamelCase` for classes
- **Blocks**: Prefer `{ }` for single-line blocks, `do...end` for multi-line
- **Errors**: Use custom error classes for domain-specific errors

```ruby
# Good
class CardPriceService
  def fetch_price(card)
    # ...
  rescue ScryfallApiError => e
    Rails.logger.error("Failed to fetch price: #{e.message}")
    raise PriceFetchError, "Could not fetch price for #{card.name}"
  end
end
```

### SQL

- **Parameterization**: Always use parameterized queries to prevent SQL injection
- **Indexes**: Add indexes for frequently queried columns
- **N+1**: Use `includes`, `joins`, or `preload` to avoid N+1 queries

---

## Error Handling

### Frontend

```typescript
// Use try/catch with async functions
async function fetchCard(id: string): Promise<Card | null> {
  try {
    const response = await fetch(`/api/cards/${id}`);
    if (!response.ok) {
      throw new ApiError('Failed to fetch card', response.status);
    }
    return await response.json();
  } catch (error) {
    if (error instanceof ApiError) {
      console.error('API Error:', error.message);
    }
    return null;
  }
}
```

### Backend

```ruby
# Rails controllers - use rescue_from or inline rescue
class CardsController < ApplicationController
  def show
    card = Card.find(params[:id])
    render json: card
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Card not found' }, status: :not_found
  end
end
```

---

## Git Workflow

### GitHub Context Protocol

Agents MUST interpret shorthand GitHub refs as context fetches:

| Reference | Action | URL Template |
|-----------|--------|--------------|
| issue N   | Read full issue + comments | https://github.com/cobaltroad/mtg-inventory/issues/{N}  |
| PR N      | Read PR description, diff, comments | https://github.com/cobaltroad/mtg-inventory/pull/{N} |
| #N        | Same as issue N | (alias for issues/PRs) |

- "issue N" → Read https://github.com/cobaltroad/mtg-inventory/issues/N fully (title, body, all comments chronologically, labels).
- Fetch via browser, paste relevant excerpts.

- Parse discussions for requirements, bugs, decisions.
- Quote key excerpts with links.
- For Kilo CLI: Leverage @git-changes or built-in git tools; manually fetch issues via browser/export if needed.  Use /init or skills if available; otherwise note "Context from issue N: [paste]".
- Always confirm: "Incorporating context from issue 233: [summary + link]".
- Cross-reference with code: e.g., "Fix issue 233 by updating src/lib/services/cardService.ts".


### Commit Messages

Use conventional commits:
- `feat: add card price tracking`
- `fix: resolve pagination after deletion (fixes #190)`
- `refactor: extract price calculation logic`
- `test: add tests for inventory filtering`

### Branch Naming

- `feature/issue-{number}-{description}`
- `fix/issue-{number}-{description}`
- `refactor/{description}`

---

## Testing Guidelines

### TDD Workflow

1. **RED**: Write failing tests first
2. **GREEN**: Write minimal code to pass
3. **REFACTOR**: Improve code while keeping tests green

### Test Structure (AAA Pattern)

```typescript
describe('InventoryService', () => {
  it('filters cards by color', () => {
    // Arrange
    const cards = buildCardList();
    
    // Act
    const filtered = filterByColor(cards, 'blue');
    
    // Assert
    expect(filtered).toHaveLength(3);
  });
});
```

### Backend Test Naming

Use descriptive names: `test_filters_inventory_by_finish_type`

### Mocking

- **Frontend**: Use Vitest mocks for services
- **Backend**: Use Mocha for stubbing, VCR for HTTP recordings
- **External APIs**: Record with VCR cassettes in `test/fixtures/vcr_cassettes/`

---

## Import Conventions

### Frontend

```typescript
// Internal imports - use aliases
import { CardService } from '$lib/services/cardService';
import { formatPrice } from '$lib/utils/format';

// SvelteKit imports
import { page } from '$app/stores';
import { goto } from '$app/navigation';

// Relative for sibling components
import InventoryTable from './InventoryTable.svelte';
```

### Backend

```ruby
# Grouped: built-in -> external -> internal
require 'json'
require 'faraday'

require_relative '../services/card_service'
require_relative './my_controller_helper'
```

---

## Database

- **Migrations**: Always use migrations for schema changes
- **Foreign keys**: Use `add_foreign_key` for associations
- **Timestamps**: Include `t.timestamps` in migrations
- **Test isolation**: Each test should be independent; use `setup`/`teardown`

---

## Performance

- **Frontend**: Use `$derived` for computed values, avoid reactive statements in loops
- **Backend**: Use `bullet` gem to detect N+1 queries in development
- **Database**: Add database indices for filtered/sorted columns
- **Caching**: Use Rails.cache for expensive operations

---

## Pull Requests

1. Run full test suite locally before pushing
2. Ensure linting passes (`npm run lint` and `bundle exec rubocop`)
3. Write clear PR description with context
4. Reference issue numbers in commits: `fixes #123`
