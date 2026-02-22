# QA Debugger Memory

## Project Structure
- Frontend inventory page: `frontend/src/routes/inventory/+page.svelte`
- Page loader: `frontend/src/routes/inventory/+page.ts`
- InventoryTable component: `frontend/src/lib/components/InventoryTable.svelte`
- EmptyInventory component: `frontend/src/lib/components/EmptyInventory.svelte`
- Home page: `frontend/src/routes/+page.svelte`
- PriceAlertWidget: `frontend/src/lib/components/PriceAlertWidget.svelte`
- SvelteKit hooks proxy: `frontend/src/hooks.server.ts`

## Known Pre-existing Test Failures
- `backend-pagination.test.ts` > "includes page parameter in URL when navigating to page 2" - fails due to Skeleton Pagination aria-current not updating in test environment
- `pagination.test.ts` > "should navigate to second page with multi-page inventory after update" - similar pagination navigation issue in tests
- `reports.test.ts` - 12 tests failing (unrelated to inventory)

## Bug Patterns Found

### Issue #171: Empty state checks must consider backend pagination metadata
- `allItems.length === 0` is insufficient for empty state detection in backend-paginated mode
- Must also check `backendTotalCount === 0` to distinguish "page is empty" from "inventory is empty"
- When items are deleted client-side, `backendTotalCount` must be decremented optimistically
- After all page items are deleted, need to redirect to a valid page using `goto()` with `invalidateAll: true`

### Issue #211/212: Skeleton UI v3 vs v4 CSS Class Incompatibility
- `variant-ghost-surface`, `variant-soft-success`, `variant-soft-error`, `variant-filled-primary` are Skeleton v3 class patterns
- Skeleton v4 (^4.11.0) does NOT define any of these classes - they are complete no-ops
- The `btn-icon` and `btn-icon-sm` classes DO exist in Skeleton v4 and generate proper CSS
- These v3 classes are used across multiple components (PriceAlertWidget, metagame pages, InventoryValueWidget)
- Broader tech-debt: project needs migration from Skeleton v3 class patterns to v4 equivalents

### Svelte 5 $derived timing in mutations
- When mutating `$state` that a `$derived` depends on, capture derived values BEFORE mutation
- Example: `const previousCount = displayItems.length;` must come before `allItems = ...`
- $derived values recompute when their dependencies change, even within the same synchronous function

## Environment Details
- Docker container runs Vite dev server (`npm run dev --host`), NOT production build
- `APP_DOMAIN=cobaltroad.com` disables HMR (page requires manual reload after code changes)
- `PUBLIC_BASE_PATH=/projects/mtg` sets the SvelteKit base path
- API proxy in `hooks.server.ts` forwards `/api/` and `/rails/` paths to `VITE_API_URL` (backend)
- Source code is volume-mounted into container (`./frontend:/frontend`)
- Traefik v3.6.7 reverse proxy in front of SvelteKit (traefik-public network)
- Backend gets `PUBLIC_API_PATH=/projects/mtg/api` but NOT `PUBLIC_BASE_PATH`

## OAuth / Auth Flow Architecture
- Full request path: Browser -> Traefik -> SvelteKit hooks.server.ts proxy -> Rails backend
- `redirect: 'manual'` in hooks.server.ts is CRITICAL for OAuth redirects
- Without it: Node.js fetch follows 302 to Discord server-side, returns Brotli HTML -> "Content Encoding Error"
- Rails `frontend_url()` uses `ENV.fetch("PUBLIC_BASE_PATH", "")` which is empty on backend (env var not passed in docker-compose.yml)
- This causes OAuth callback redirects to miss the `/projects/mtg` base path prefix

## Debugging Techniques
- Use `git stash` to quickly verify if test failures are pre-existing vs caused by changes
- Run targeted tests with `-t "test name"` to avoid slow full suite runs (~50s for full suite)
- TypeScript check (`npm run check`) has permission issues in Docker environment - not reliable for CI verification
- Fetch compiled Svelte modules from Vite dev server to verify compiled output
- Browser `console.log` from Svelte components only appears in browser DevTools, NOT in Docker logs
- Server-side `onMount` does not run during SSR - component starts in loading state on first render
