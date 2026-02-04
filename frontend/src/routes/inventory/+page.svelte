<script lang="ts">
	import InventoryTable from '$lib/components/InventoryTable.svelte';
	import EmptyInventory from '$lib/components/EmptyInventory.svelte';
	import { pluralize } from '$lib/utils/format';
	import type { InventoryItem as InventoryItemType } from '$lib/types/inventory';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	// Derive state from page data
	let items = $derived(data.items || []);
	let error = $derived(data.error || null);
	let loading = $state(false);
</script>

<div class="inventory-page">
	<header class="page-header">
		<h1 class="page-title">My Inventory</h1>
		{#if items.length > 0 && !loading}
			<p class="item-count">{items.length} {pluralize(items.length, 'card')}</p>
		{/if}
	</header>

	{#if error}
		<div class="alert alert-error" role="alert">
			<span class="font-medium">Error!</span>
			{error}
		</div>
	{/if}

	{#if !error && items.length === 0 && !loading}
		<EmptyInventory />
	{:else}
		<InventoryTable {items} {loading} />
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
</style>
