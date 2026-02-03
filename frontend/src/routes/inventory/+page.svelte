<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import InventoryTable from '$lib/components/InventoryTable.svelte';
	import EmptyInventory from '$lib/components/EmptyInventory.svelte';
	import { Button, Alert } from 'flowbite-svelte';
	import { pluralize } from '$lib/utils/format';
	import type { InventoryItem as InventoryItemType } from '$lib/types/inventory';

	const API_BASE = base;

	let items: InventoryItemType[] = $state([]);
	let loading = $state(true);
	let error = $state<string | null>(null);

	/**
	 * Fetches the user's inventory from the API
	 */
	async function fetchInventory() {
		loading = true;
		error = null;
		try {
			const res = await fetch(`${API_BASE}/api/inventory`);
			if (!res.ok) {
				throw new Error(`Failed to fetch inventory: ${res.statusText}`);
			}
			const data = await res.json();
			items = data;
		} catch (err) {
			error = err instanceof Error ? err.message : 'An error occurred while loading inventory';
			console.error('Failed to fetch inventory:', err);
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		fetchInventory();
	});
</script>

<div class="inventory-page">
	<header class="page-header">
		<h1 class="page-title">My Inventory</h1>
		{#if items.length > 0 && !loading}
			<p class="item-count">{items.length} {pluralize(items.length, 'card')}</p>
		{/if}
	</header>

	{#if error}
		<Alert color="red" class="mb-4">
			<span class="font-medium">Error!</span>
			{error}
			<div class="mt-2">
				<Button size="sm" color="red" onclick={fetchInventory}>Try Again</Button>
			</div>
		</Alert>
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

	:global(.dark) .page-title {
		color: #e5e7eb;
	}

	:global(.dark) .item-count {
		color: #9ca3af;
	}
</style>
