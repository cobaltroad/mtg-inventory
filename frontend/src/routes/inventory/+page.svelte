<script lang="ts">
	import { onMount, getContext } from 'svelte';
	import { Search, ChevronLeft, ChevronRight } from 'lucide-svelte';
	import { Pagination } from '@skeletonlabs/skeleton-svelte';
	import InventoryTable from '$lib/components/InventoryTable.svelte';
	import EmptyInventory from '$lib/components/EmptyInventory.svelte';
	import FilterBar from '$lib/components/FilterBar.svelte';
	import SortDropdown from '$lib/components/SortDropdown.svelte';
	import InventoryStats from '$lib/components/InventoryStats.svelte';
	import { pluralize } from '$lib/utils/format';
	import { filterBySet, sortInventory, calculateStats } from '$lib/utils/inventory';
	import type { PageData } from './$types';
	import type { SortOption } from '$lib/types/inventory';

	let { data }: { data: PageData } = $props();

	// Get search drawer opener from context
	const openSearchDrawer = getContext<() => void>('openSearchDrawer');

	// State management
	let allItems = $state(data.items || []);
	let error = $derived(data.error || null);
	let loading = $state(false);

	// Update allItems when data changes
	$effect(() => {
		allItems = data.items || [];
	});

	// Handle items change from InventoryTable
	function handleItemsChange(updatedItems: typeof allItems) {
		allItems = updatedItems;
	}

	// Filtering and sorting state
	let currentFilter = $state('');
	let currentSort = $state<SortOption>('name-asc');

	// Pagination state
	let currentPage = $state(1);
	let pageSize = $state(20);

	// Apply filtering and sorting
	let filteredItems = $derived(filterBySet(allItems, currentFilter));
	let sortedItems = $derived(sortInventory(filteredItems, currentSort));
	let stats = $derived(calculateStats(filteredItems));

	// Apply pagination
	let paginationStart = $derived((currentPage - 1) * pageSize);
	let paginationEnd = $derived(paginationStart + pageSize);
	let displayItems = $derived(sortedItems.slice(paginationStart, paginationEnd));

	// Pagination visibility
	let showPagination = $derived(filteredItems.length > pageSize);

	// Count display
	let itemCountText = $derived(() => {
		if (currentFilter && filteredItems.length !== allItems.length) {
			return `Showing ${filteredItems.length} of ${allItems.length} ${pluralize(allItems.length, 'card')}`;
		}
		return `${allItems.length} ${pluralize(allItems.length, 'card')}`;
	});

	// Load preferences from localStorage
	onMount(() => {
		const savedSort = localStorage.getItem('inventory-sort');
		if (savedSort) {
			currentSort = savedSort as SortOption;
		}

		const savedPageSize = localStorage.getItem('inventory-page-size');
		if (savedPageSize) {
			pageSize = parseInt(savedPageSize, 10);
		}
	});

	// Save sort preference to localStorage
	function handleSortChange(newSort: SortOption) {
		currentSort = newSort;
		localStorage.setItem('inventory-sort', newSort);
	}

	// Handle filter change
	function handleFilterChange(newFilter: string) {
		currentFilter = newFilter;
		// Reset to first page when filter changes
		currentPage = 1;
	}

	// Handle page size change
	function handlePageSizeChange(event: Event) {
		const target = event.currentTarget as HTMLSelectElement;
		pageSize = parseInt(target.value, 10);
		localStorage.setItem('inventory-page-size', target.value);
		// Reset to first page when page size changes
		currentPage = 1;
	}

	// Handle page change
	function handlePageChange(event: { page: number }) {
		currentPage = event.page;
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

	{#if !error && allItems.length === 0 && !loading}
		<EmptyInventory />
	{:else if allItems.length > 0}
		<InventoryStats {stats} />

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
			<InventoryTable items={displayItems} {loading} onItemsChange={handleItemsChange} />

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
							count={filteredItems.length}
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
									{#each pag().pages as pageItem, index (pageItem.value)}
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
		background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%239ca3af'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 9l-7 7-7-7'%3E%3C/path%3E%3C/svg%3E");
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
