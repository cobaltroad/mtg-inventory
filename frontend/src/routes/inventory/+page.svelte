<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import InventoryItem from '$lib/components/InventoryItem.svelte';
	import EmptyInventory from '$lib/components/EmptyInventory.svelte';
	import type { InventoryItem as InventoryItemType } from '$lib/types/inventory';

	const API_BASE = base;

	let items: InventoryItemType[] = $state([]);
	let loading = $state(true);
	let error = $state<string | null>(null);

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
		<h1>My Inventory</h1>
		{#if items.length > 0}
			<p class="item-count">{items.length} {items.length === 1 ? 'card' : 'cards'}</p>
		{/if}
	</header>

	{#if loading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>Loading your inventory...</p>
		</div>
	{:else if error}
		<div class="error-state">
			<p class="error-message">{error}</p>
			<button onclick={fetchInventory} class="retry-button">Try Again</button>
		</div>
	{:else if items.length === 0}
		<EmptyInventory />
	{:else}
		<div class="inventory-list">
			{#each items as item (item.id)}
				<InventoryItem {item} />
			{/each}
		</div>
	{/if}
</div>

<style>
	.inventory-page {
		max-width: 1200px;
		margin: 0 auto;
		padding: 2rem 1rem;
	}

	.page-header {
		margin-bottom: 2rem;
	}

	h1 {
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

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		min-height: 400px;
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid #e5e7eb;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.loading-state p {
		margin-top: 1rem;
		color: #6b7280;
		font-size: 1rem;
	}

	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		min-height: 400px;
	}

	.error-message {
		color: #dc2626;
		font-size: 1rem;
		margin: 0 0 1rem;
		text-align: center;
	}

	.retry-button {
		padding: 0.75rem 1.5rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}

	.retry-button:hover {
		background: #2563eb;
	}

	.inventory-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}
</style>
