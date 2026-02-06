<script lang="ts">
	import { onMount } from 'svelte';
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

	// Apply filtering and sorting
	let filteredItems = $derived(filterBySet(allItems, currentFilter));
	let displayItems = $derived(sortInventory(filteredItems, currentSort));
	let stats = $derived(calculateStats(filteredItems));

	// Count display
	let itemCountText = $derived(() => {
		if (currentFilter && filteredItems.length !== allItems.length) {
			return `Showing ${filteredItems.length} of ${allItems.length} ${pluralize(allItems.length, 'card')}`;
		}
		return `${allItems.length} ${pluralize(allItems.length, 'card')}`;
	});

	// Load sort preference from localStorage
	onMount(() => {
		const savedSort = localStorage.getItem('inventory-sort');
		if (savedSort) {
			currentSort = savedSort as SortOption;
		}
	});

	// Save sort preference to localStorage
	function handleSortChange(newSort: SortOption) {
		currentSort = newSort;
		localStorage.setItem('inventory-sort', newSort);
	}

	function handleFilterChange(newFilter: string) {
		currentFilter = newFilter;
	}
</script>

<div class="inventory-page">
	<header class="page-header">
		<h1 class="page-title">My Inventory</h1>
		{#if allItems.length > 0 && !loading}
			<p class="item-count">{itemCountText()}</p>
		{/if}
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
		color: #e5e7eb;
	}

	:global(.dark) .item-count {
		color: #9ca3af;
	}

	:global(.dark) .alert-error {
		background: #7f1d1d;
		border-color: #991b1b;
		color: #fecaca;
	}

	@media (max-width: 768px) {
		.controls-bar {
			flex-direction: column;
			align-items: stretch;
		}
	}
</style>
