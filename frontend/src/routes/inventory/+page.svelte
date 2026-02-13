<script lang="ts">
	import { onMount, getContext } from 'svelte';
	import { goto } from '$app/navigation';
	import { page, navigating } from '$app/stores';
	import { Search, ChevronLeft, ChevronRight } from 'lucide-svelte';
	import { Pagination } from '@skeletonlabs/skeleton-svelte';
	import InventoryTable from '$lib/components/InventoryTable.svelte';
	import EmptyInventory from '$lib/components/EmptyInventory.svelte';
	import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';
	import FilterBar from '$lib/components/FilterBar.svelte';
	import SortDropdown from '$lib/components/SortDropdown.svelte';
	import InventoryStats from '$lib/components/InventoryStats.svelte';
	import { pluralize } from '$lib/utils/format';
	import { filterBySet, sortInventory } from '$lib/utils/inventory';
	import type { PageData } from './$types';
	import type { SortOption } from '$lib/types/inventory';

	// Constants
	const DEFAULT_PAGE_SIZE = 20;
	const PAGE_SIZE_OPTIONS = [20, 50, 100] as const;
	const STORAGE_KEY_SORT = 'inventory-sort';
	const STORAGE_KEY_PAGE_SIZE = 'inventory-page-size';

	let { data }: { data: PageData } = $props();

	// Get search drawer opener from context
	const openSearchDrawer = getContext<() => void>('openSearchDrawer');

	// State management
	// Initialize with empty array to avoid capturing prop value at initialization
	let allItems = $state<typeof data.items>([]);
	let error = $derived(data.error || null);
	let loading = $state(false);
	let initialLoading = $state(true);

	// Detect navigation loading state for backend pagination
	let isNavigating = $derived($navigating !== null);

	// Backend pagination metadata - initialize without referencing data
	let backendPage = $state(1);
	let backendPerPage = $state(0); // 0 = not set, don't override local pageSize
	let backendTotalCount = $state(0);
	let backendTotalPages = $state(0);

	// Backend stats from API - initialize without referencing data
	let backendStats = $state<typeof data.stats>(null);

	// Sync allItems and pagination metadata with data using $effect
	// This reads data in a reactive context, establishing proper tracking
	$effect(() => {
		allItems = data.items || [];
		const newPage = data.page || 1;
		const newPerPage = data.per_page || 0;
		const newTotalCount = data.total_count || 0;
		const newTotalPages = data.total_pages || 0;
		const newStats = data.stats || null;

		// Only update if values have changed (avoid unnecessary reactivity)
		if (newPage !== backendPage) backendPage = newPage;
		if (newPerPage !== backendPerPage) {
			backendPerPage = newPerPage;
			// When backend per_page changes, sync to local pageSize if valid and initialized
			if (
				pageSizeInitialized &&
				newPerPage > 0 &&
				newPerPage !== pageSize &&
				PAGE_SIZE_OPTIONS.includes(newPerPage as typeof PAGE_SIZE_OPTIONS[number])
			) {
				pageSize = newPerPage;
			}
		}
		if (newTotalCount !== backendTotalCount) backendTotalCount = newTotalCount;
		if (newTotalPages !== backendTotalPages) backendTotalPages = newTotalPages;
		backendStats = newStats;

		// Mark initial loading as complete once we've synced data
		initialLoading = false;
	});

	// Handle items change from InventoryTable
	// IMPORTANT: displayItems is a paginated subset, so we can't just replace allItems
	// Instead, merge changes by ID to preserve items on other pages
	function handleItemsChange(updatedItems: typeof allItems) {
		// Create a map of updated items for O(1) lookup
		const updatedMap = new Map(updatedItems.map((item) => [item.id, item]));

		// Update existing items or remove deleted ones
		allItems = allItems
			.map((item) => updatedMap.get(item.id) || item)
			.filter((item) => {
				// If item was in displayItems but not in updatedItems, it was deleted
				const wasDisplayed = displayItems.some((d) => d.id === item.id);
				const stillExists = updatedMap.has(item.id);
				return !wasDisplayed || stillExists;
			});
	}

	// Filtering and sorting state
	let currentFilter = $state('');
	let currentSort = $state<SortOption>('name-asc');

	// Pagination state - sync with backend page when available
	let currentPage = $state(1);

	// Initialize pageSize from localStorage or use default
	// Must be reactive to work properly in tests
	let pageSize = $state(DEFAULT_PAGE_SIZE);
	let pageSizeInitialized = $state(false); // Track if pageSize has been initialized

	// Initialize pageSize from localStorage on mount
	$effect(() => {
		if (!pageSizeInitialized && typeof window !== 'undefined') {
			const savedPageSize = localStorage.getItem(STORAGE_KEY_PAGE_SIZE);
			if (savedPageSize) {
				const parsed = parseInt(savedPageSize, 10);
				// Validate that the saved page size is a valid option
				if (PAGE_SIZE_OPTIONS.includes(parsed as typeof PAGE_SIZE_OPTIONS[number])) {
					pageSize = parsed;
				}
			}
			pageSizeInitialized = true;
		}
	});

	// Sync currentPage with backend state ONLY when backend page changes
	// Track last synced value to avoid fighting with user interactions
	let lastSyncedBackendPage = $state(0);
	$effect(() => {
		if (backendPage > 0 && backendPage !== lastSyncedBackendPage) {
			currentPage = backendPage;
			lastSyncedBackendPage = backendPage;
		}
	});

	// Apply filtering and sorting
	let filteredItems = $derived(filterBySet(allItems, currentFilter));
	let sortedItems = $derived(sortInventory(filteredItems, currentSort));

	// Check if we're using backend pagination
	// Backend pagination: we have metadata AND we don't have all items locally
	// (total_count > items we have, indicating there are more items on the server)
	let isBackendPaginated = $derived(
		backendTotalCount > 0 &&
			!currentFilter &&
			backendTotalCount > allItems.length
	);

	// Apply pagination
	// When using backend pagination, items are already paginated - don't slice again
	// When using client-side pagination (all items loaded locally or with filters), apply slicing
	let paginationStart = $derived((currentPage - 1) * pageSize);
	let paginationEnd = $derived(paginationStart + pageSize);
	let displayItems = $derived(
		isBackendPaginated ? sortedItems : sortedItems.slice(paginationStart, paginationEnd)
	);

	// Pagination visibility and total count
	// Use backend total when using backend pagination
	// Otherwise use local filtered count for client-side pagination
	let effectiveTotalCount = $derived(
		isBackendPaginated ? backendTotalCount : filteredItems.length
	);
	let showPagination = $derived(effectiveTotalCount > pageSize);

	// Count display - use backend total count when available, fallback to local count
	let itemCountText = $derived(() => {
		const totalCount = backendTotalCount > 0 ? backendTotalCount : allItems.length;
		if (currentFilter && filteredItems.length !== allItems.length) {
			return `Showing ${filteredItems.length} of ${totalCount} ${pluralize(totalCount, 'card')}`;
		}
		return `${totalCount} ${pluralize(totalCount, 'card')}`;
	});

	// Load sort preference from localStorage on mount
	onMount(() => {
		const savedSort = localStorage.getItem(STORAGE_KEY_SORT);
		if (savedSort) {
			currentSort = savedSort as SortOption;
		}
	});

	/**
	 * Updates sort order and persists to localStorage
	 */
	function handleSortChange(newSort: SortOption) {
		currentSort = newSort;
		localStorage.setItem(STORAGE_KEY_SORT, newSort);
	}

	/**
	 * Updates filter and resets pagination to first page
	 */
	function handleFilterChange(newFilter: string) {
		currentFilter = newFilter;
		currentPage = 1; // Reset to first page when filter changes
	}

	/**
	 * Updates page size, persists to localStorage, and resets to first page
	 */
	function handlePageSizeChange(event: Event) {
		const target = event.currentTarget as HTMLSelectElement;
		const newSize = parseInt(target.value, 10);
		pageSize = newSize;
		localStorage.setItem(STORAGE_KEY_PAGE_SIZE, target.value);
		currentPage = 1; // Reset to first page when page size changes

		// Update URL for backend pagination (when no filter is applied)
		if (isBackendPaginated) {
			const url = new URL($page.url);
			url.searchParams.set('page', '1');
			url.searchParams.set('per_page', String(newSize));
			goto(url.toString(), { keepFocus: true, noScroll: true });
		}
	}

	/**
	 * Updates current page when user navigates
	 */
	function handlePageChange(event: { page: number }) {
		currentPage = event.page;

		// Update URL for backend pagination (when no filter is applied)
		if (isBackendPaginated) {
			const url = new URL($page.url);
			url.searchParams.set('page', String(event.page));
			url.searchParams.set('per_page', String(pageSize));
			goto(url.toString(), { keepFocus: true, noScroll: true });
		}
	}
</script>

<div class="inventory-page">
	<header class="page-header">
		<div class="header-content">
			<div class="header-text">
				<h1 class="page-title">My Inventory</h1>
				{#if allItems.length > 0 && !loading}
					<p class="item-count">{itemCountText()}</p>
				{/if}
			</div>
			{#if allItems.length > 0}
				<button class="search-btn" onclick={openSearchDrawer}>
					<Search class="h-4 w-4" />
					Search Cards
				</button>
			{/if}
		</div>
	</header>

	{#if error}
		<div class="alert alert-error" role="alert">
			<span class="font-medium">Error!</span>
			{error}
		</div>
	{/if}

	{#if initialLoading}
		<LoadingSpinner message="Loading your inventory..." />
	{:else if !error && allItems.length === 0}
		<EmptyInventory />
	{:else if allItems.length > 0}
		{#if backendStats}
			<InventoryStats stats={backendStats} />
		{/if}

		<div class="controls-bar">
			<FilterBar items={allItems} {currentFilter} onFilterChange={handleFilterChange} />
			<SortDropdown {currentSort} onSortChange={handleSortChange} />
		</div>

		{#if filteredItems.length === 0}
			<div class="no-results">
				<p>No cards match the current filter.</p>
				<button class="clear-filter-btn" onclick={() => handleFilterChange('')}>
					Clear Filter
				</button>
			</div>
		{:else}
			<InventoryTable
				items={displayItems}
				loading={loading || isNavigating}
				onItemsChange={handleItemsChange}
			/>

			{#if showPagination}
				<div class="pagination-container">
					<label class="page-size-label">
						<span>Items per page:</span>
						<select
							class="page-size-select"
							value={String(pageSize)}
							onchange={handlePageSizeChange}
							aria-label="Items per page"
						>
							<option value="20">20</option>
							<option value="50">50</option>
							<option value="100">100</option>
						</select>
					</label>

					<nav class="pagination-nav" aria-label="Pagination navigation">
						<Pagination
							count={effectiveTotalCount}
							{pageSize}
							page={currentPage}
							onPageChange={handlePageChange}
						>
							<Pagination.PrevTrigger>
								<ChevronLeft class="h-4 w-4" />
								<span>Previous</span>
							</Pagination.PrevTrigger>
							<Pagination.Context>
								{#snippet children(pag)}
									{#each pag().pages as pageItem, index (pageItem.value ?? `ellipsis-${index}`)}
										{#if pageItem.type === 'page'}
											<Pagination.Item {...pageItem}>
												{pageItem.value}
											</Pagination.Item>
										{:else}
											<Pagination.Ellipsis {index}>&#8230;</Pagination.Ellipsis>
										{/if}
									{/each}
								{/snippet}
							</Pagination.Context>
							<Pagination.NextTrigger>
								<span>Next</span>
								<ChevronRight class="h-4 w-4" />
							</Pagination.NextTrigger>
						</Pagination>
					</nav>
				</div>
			{/if}
		{/if}
	{/if}
</div>

<style>
	.inventory-page {
		max-width: 1400px;
		margin: 0 auto;
		padding: 2rem 1rem;
	}

	.page-header {
		margin-bottom: 2rem;
	}

	.header-content {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 1rem;
		margin-bottom: 0.5rem;
	}

	.header-text {
		flex: 1;
	}

	.page-title {
		font-size: 2rem;
		font-weight: 700;
		color: #111827;
		margin: 0 0 0.5rem;
	}

	.item-count {
		color: #6b7280;
		font-size: 1rem;
		margin: 0;
	}

	.search-btn {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.625rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		white-space: nowrap;
	}

	.search-btn:hover {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}

	.alert {
		padding: 1rem;
		border-radius: 0.5rem;
		margin-bottom: 1rem;
		display: flex;
		gap: 0.5rem;
		align-items: flex-start;
	}

	.alert-error {
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #991b1b;
	}

	.controls-bar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.no-results {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
	}

	.no-results p {
		color: #6b7280;
		font-size: 1.125rem;
		margin: 0 0 1rem;
	}

	:global(.dark) .no-results p {
		color: #9ca3af;
	}

	.clear-filter-btn {
		padding: 0.5rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.clear-filter-btn:hover {
		background: #2563eb;
	}

	:global(.dark) .page-title {
		color: #f9fafb;
	}

	:global(.dark) .item-count {
		color: #9ca3af;
	}

	:global(.dark) .alert-error {
		background: #7f1d1d;
		border-color: #991b1b;
		color: #fecaca;
	}

	.pagination-container {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: 2rem;
		gap: 1rem;
		flex-wrap: wrap;
	}

	.page-size-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		color: #6b7280;
	}

	:global(.dark) .page-size-label {
		color: #9ca3af;
	}

	.page-size-select {
		padding: 0.5rem 2rem 0.5rem 0.75rem;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%236b7280'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 9l-7 7-7-7'%3E%3C/path%3E%3C/svg%3E");
		background-repeat: no-repeat;
		background-position: right 0.5rem center;
		background-size: 1rem;
	}

	.page-size-select:hover {
		border-color: #9ca3af;
	}

	.page-size-select:focus {
		outline: 2px solid #3b82f6;
		outline-offset: 2px;
		border-color: #3b82f6;
	}

	:global(.dark) .page-size-select {
		background: #1f2937;
		border-color: #374151;
		color: #f9fafb;
		-webkit-appearance: none;
		-moz-appearance: none;
		appearance: none;
		background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%239ca3af'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 9l-7 7-7-7'%3E%3C/path%3E%3C/svg%3E");
		background-repeat: no-repeat;
		background-position: right 0.5rem center;
		background-size: 1rem;
	}

	:global(.dark) .page-size-select:hover {
		border-color: #6b7280;
	}

	.pagination-nav {
		flex: 1;
		display: flex;
		justify-content: center;
	}

	@media (max-width: 768px) {
		.controls-bar {
			flex-direction: column;
			align-items: stretch;
		}

		.header-content {
			flex-direction: column;
			align-items: flex-start;
		}

		.search-btn {
			width: 100%;
			justify-content: center;
		}

		.pagination-container {
			flex-direction: column;
			align-items: stretch;
		}

		.pagination-nav {
			justify-content: center;
		}
	}
</style>
