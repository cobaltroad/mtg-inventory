# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## [0.3.2] - 2026-02-09

### Added
- Extended logging and monitoring to all background jobs (#125)
- ScraperExecution model for tracking scraper job history (#93)
- Admin API endpoints for scraper execution management (#93)
- Structured JSON logging in scraper jobs (#93)

### Fixed
- LayerCake scale errors on home page navigation (#121)
- Inventory drawer closing unexpectedly on interaction (#117)
- Memoization race conditions with ?uu parameter

### Changed
- Simplified home page by removing search link
- Improved drawer behavior with better interaction handling

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

[0.3.3]: https://github.com/cobaltroad/mtg-inventory/compare/v0.3.1...v0.3.3
[0.3.2]: https://github.com/cobaltroad/mtg-inventory/compare/v0.3.1...v0.3.2
[0.1.0]: https://github.com/cobaltroad/mtg-inventory/compare/v0.0.3...v0.1.0
[0.0.3]: https://github.com/cobaltroad/mtg-inventory/releases/tag/v0.0.3
