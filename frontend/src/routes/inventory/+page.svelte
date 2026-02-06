<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
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
	let refreshingPrices = $state(false);
	let refreshMessage = $state('');

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

	async function refreshPrices() {
		refreshingPrices = true;
		refreshMessage = '';

		try {
			const response = await fetch(`${base}/api/prices/update`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				}
			});

			if (!response.ok) {
				throw new Error('Failed to refresh prices');
			}

			const result = await response.json();
			refreshMessage = `Price update started for ${result.cards_to_update} cards. Refresh the page in a few moments to see updated prices.`;

			// Auto-clear message after 10 seconds
			setTimeout(() => {
				refreshMessage = '';
			}, 10000);
		} catch (err) {
			refreshMessage = 'Failed to refresh prices. Please try again.';
			console.error('Price refresh error:', err);
		} finally {
			refreshingPrices = false;
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
				<button
					class="refresh-prices-btn"
					onclick={refreshPrices}
					disabled={refreshingPrices}
				>
					{#if refreshingPrices}
						<span class="spinner"></span>
						Refreshing...
					{:else}
						<svg
							xmlns="http://www.w3.org/2000/svg"
							width="16"
							height="16"
							viewBox="0 0 24 24"
							fill="none"
							stroke="currentColor"
							stroke-width="2"
							stroke-linecap="round"
							stroke-linejoin="round"
						>
							<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
							<path d="M21 3v5h-5" />
							<path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
							<path d="M3 21v-5h5" />
						</svg>
						Refresh Prices
					{/if}
				</button>
			{/if}
		</div>
		{#if refreshMessage}
			<div class="refresh-message" class:success={refreshMessage.includes('started')}>
				{refreshMessage}
			</div>
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

	.refresh-prices-btn {
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

	.refresh-prices-btn:hover:not(:disabled) {
		background: #2563eb;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}

	.refresh-prices-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.refresh-prices-btn svg {
		flex-shrink: 0;
	}

	.spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255, 255, 255, 0.3);
		border-top-color: white;
		border-radius: 50%;
		animation: spin 0.6s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.refresh-message {
		padding: 0.75rem 1rem;
		border-radius: 0.5rem;
		font-size: 0.875rem;
		margin-top: 1rem;
		background: #fef2f2;
		border: 1px solid #fecaca;
		color: #991b1b;
	}

	.refresh-message.success {
		background: #f0fdf4;
		border-color: #bbf7d0;
		color: #166534;
	}

	:global(.dark) .refresh-message {
		background: #7f1d1d;
		border-color: #991b1b;
		color: #fecaca;
	}

	:global(.dark) .refresh-message.success {
		background: #14532d;
		border-color: #166534;
		color: #bbf7d0;
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

	@media (max-width: 768px) {
		.controls-bar {
			flex-direction: column;
			align-items: stretch;
		}

		.header-content {
			flex-direction: column;
			align-items: flex-start;
		}

		.refresh-prices-btn {
			width: 100%;
			justify-content: center;
		}
	}
</style>
