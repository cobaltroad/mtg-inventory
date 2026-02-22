# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] - 2026-02-22

### Added
- **Discord OAuth Authentication** (#222, #223, #224, #226, #228, #229, #233)
  - Full Discord OAuth 2.0 integration for user authentication
  - Backend OAuth provider setup with session management
  - Frontend authentication state management with SvelteKit
  - API client with automatic session cookie handling
  - Protected routes with automatic login redirects
  - Seeded inventory migration for new Discord users
  - Environment-based authentication (enabled in prod, optional in dev)
  - `VITE_AUTH_ENABLED` flag for development mode control
  - Makefile for easy dev/prod environment toggling
  - User model with Discord integration and secure session handling
- **Environment-Specific API Configuration** (#235)
  - Support for different external API endpoints per environment
  - Improved flexibility for development vs production deployments

### Changed
- Production deployment now uses cookie-based sessions for authentication
- OAuth redirect flow uses full page navigation for better compatibility
- Test suite improvements with better isolation and mocking
- Gitignore updated to catch all `.env.*` files for better security

### Fixed
- OAuth security vulnerabilities including session fixation and CSRF protection (#234)
- OAuth redirect and Set-Cookie header forwarding in production (#232)
- Test suite failures related to rate limiting and API mocking (#231)
- Test isolation issues with logging and singleton methods (#215)
- CollectionItem metadata synchronization and test infrastructure
- Error handling in OAuth callback page for better user experience

### Security
- Implemented secure session management with HttpOnly cookies
- Added CSRF protection to OAuth flow
- Fixed session fixation vulnerabilities
- Improved environment variable handling and .env file security

## [0.6.0] - 2026-02-20

### Added
- **Inventory Color Filtering** (#207)
  - Filter cards by color identity (W, U, B, R, G, colorless)
  - Backend API with color filtering support
  - Frontend UI with interactive color filter buttons
  - Handles double-faced cards properly
  - Mono-color filtering by default
- **Finish Display Improvements** (#204)
  - Display specific finish types without 'finish' suffix
  - Promo types support for special finish cards
  - New `finishDisplay` utility for consistent formatting
- **Price Alert Enhancements** (#203, #211)
  - $5 minimum price threshold for increase alerts (reduces noise)
  - Comprehensive dismiss functionality with hard delete
  - Improved X icon visibility in dismiss button
- **Mobile Responsive Inventory** (#42)
  - Fully responsive inventory page layout
  - Optimized table display for mobile devices
- **Static Card List Integration** (#200)
  - GitHub writer for static card lists (Game Changers, VCR)
  - VCR integration tests with real HTTP responses
  - Manual Game Changers YAML support
  - Wizards source for card data

### Changed
- Inventory value sort now uses unit price instead of total value
- Set sort option removed from inventory
- Removed `active` scope from price_alerts (simpler query model)
- Moxfield requests now include browser headers to prevent 403 errors

### Fixed
- TypeScript pre-existing lint errors across multiple files
- Failing frontend tests (#217)
- Skeleton UI v3 to v4 class migration (#214)
- Race condition memoization issues in concurrent requests
- Card search result styling improvements
- EDH metagame page improvements

## [0.4.0] - 2026-02-12

### Added
- Production monitoring and safety features for scheduled jobs (#104)
  - Duplicate job prevention with `.already_running?` checks
  - Job failure alerting via email, Slack, and custom webhooks
  - Enhanced job statistics with execution metrics (7-day and 30-day windows)
  - Rake task for viewing job queue statistics (`jobs:stats`)
- Finish segmented control to PrintingModal
- Filter finish options based on available finishes for selected printing (#138)

### Changed
- **BREAKING:** Renamed "treatment" to "finish" terminology throughout API and UI (#127)
  - Aligns with Scryfall terminology
  - Affects API request/response parameters
- CardPrice default scope to `fetched_at DESC` for improved performance
- Safer scope handling using `reorder` instead of `unscoped`

### Fixed
- SegmentedControl rendering in PrintingModal (#136)
- Price lookup in InventoryValueTimeline (#143)
- Test environment configuration to always run in test mode (#146)
- Test isolation by clearing records in setup (#145)
- Logging test assertions to match JSON format (#144)
- Jobs:stats test to ensure recurring tasks are set up (#151)
- Card image height constraint to ensure form visibility
- CardSearchController test parameter names
- Various test fixes and improvements

## [0.3.3] - 2026-02-11

### Added
- Inventory pagination with customizable page size (#132)
- Extended logging and monitoring to all background jobs (#125)
- ScraperExecution model for tracking scraper job history (#93)
- Admin API endpoints for scraper execution management (#93)
- Structured JSON logging in scraper jobs (#93)
- Value-based sorting in inventory (replaces quantity sort)
- Development schedule for price updates (every 2 days)

### Fixed
- Stale image display in PrintingModal when switching between printings (#129)
- Image extraction for two-sided/double-faced cards (#128)
- LayerCake scale errors on home page navigation (#121)
- Inventory drawer closing unexpectedly on interaction (#117)
- Duplicate dropdown arrows in page size selector (dark mode)
- Toast notification color handling and contrast
- Memoization race conditions with ?uu parameter

### Changed
- Simplified home page by removing search link
- Improved drawer behavior with better interaction handling
- Temporarily hidden Treatment and Language fields
- Updated documentation and moved guides to wiki

## [0.1.0] - 2026-02-06

### Added
- Dark mode support with theme toggle
- Inventory item quantity editing and removal UI (#40)
- Comprehensive tests for PATCH and DELETE inventory endpoints (#40)
- Inventory filtering, sorting, and statistics (#39)
- Released date field to inventory API for release date sorting
- Solid Queue for background job processing
- Sticky AppBar header with sidebar/rail toggle functionality
- Beleren font for card names
- Montserrat font family
- Search drawer with navigation preservation and mobile support (#53)
- PrintingModal integration with SearchDrawer for card selection (#51)
- Search functionality and results display in drawer (#50)
- Local card image caching for faster inventory display (#44)
- Inventory display page with printing details (#38)
- Inventory endpoint with Scryfall card details and caching (#38)

### Changed
- Migrated from Flowbite to Skeleton UI v4 (#55)
  - Converted Button, Input, Card, Alert, and Table components
  - Updated SearchDrawer and Sidebar with Skeleton v4 Dialog
  - Replaced icons with Lucide Svelte
  - Added dark mode support to all components
- Converted sidebar to Skeleton UI Navigation component (#60)
- Optimized page load and improved search button reactivity
- Configured SvelteKit proxy to forward all API requests to backend

### Fixed
- Inventory image loading with proper base path handling
- Enriched item format returned from PATCH /inventory/:id
- Base path in inventory API calls
- Duplicate closing tag in InventoryTable component
- Image display in inventory list
- HMR disabled when accessed through production domain
- API proxy path configuration

## [0.0.3] - (Previous release)

Earlier releases are not documented in this changelog.

[0.7.0]: https://github.com/cobaltroad/mtg-inventory/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/cobaltroad/mtg-inventory/compare/v0.5.2...v0.6.0
[0.4.0]: https://github.com/cobaltroad/mtg-inventory/compare/v0.3.3...v0.4.0
[0.3.3]: https://github.com/cobaltroad/mtg-inventory/compare/v0.3.1...v0.3.3
[0.1.0]: https://github.com/cobaltroad/mtg-inventory/compare/v0.0.3...v0.1.0
[0.0.3]: https://github.com/cobaltroad/mtg-inventory/releases/tag/v0.0.3
