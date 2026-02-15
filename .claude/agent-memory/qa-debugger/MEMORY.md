# QA Debugger Memory

## Project Structure
- Frontend inventory page: `frontend/src/routes/inventory/+page.svelte`
- Page loader: `frontend/src/routes/inventory/+page.ts`
- InventoryTable component: `frontend/src/lib/components/InventoryTable.svelte`
- EmptyInventory component: `frontend/src/lib/components/EmptyInventory.svelte`

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

### Svelte 5 $derived timing in mutations
- When mutating `$state` that a `$derived` depends on, capture derived values BEFORE mutation
- Example: `const previousCount = displayItems.length;` must come before `allItems = ...`
- $derived values recompute when their dependencies change, even within the same synchronous function

## Debugging Techniques
- Use `git stash` to quickly verify if test failures are pre-existing vs caused by changes
- Run targeted tests with `-t "test name"` to avoid slow full suite runs (~50s for full suite)
- TypeScript check (`npm run check`) has permission issues in Docker environment - not reliable for CI verification
