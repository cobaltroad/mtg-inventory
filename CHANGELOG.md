# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/cobaltroad/mtg-inventory/compare/v0.0.3...v0.1.0
[0.0.3]: https://github.com/cobaltroad/mtg-inventory/releases/tag/v0.0.3
