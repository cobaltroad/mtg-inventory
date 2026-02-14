<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import ReportsStats from '$lib/components/ReportsStats.svelte';

	// Component state
	let loading = $state(true);
	let error = $state<string | null>(null);
	let totalValueCents = $state(0);
	let cardsOverTenDollars = $state(0);
	let totalSets = $state(0);

	// Fetch inventory stats data
	async function fetchInventoryStats() {
		loading = true;
		error = null;

		try {
			const response = await fetch(`${base}/api/reports/inventory_stats?uu`);

			if (!response.ok) {
				throw new Error('Failed to fetch inventory statistics');
			}

			const data = await response.json();
			totalValueCents = data.total_value_cents;
			cardsOverTenDollars = data.cards_over_ten_dollars;
			totalSets = data.total_sets;
		} catch (err) {
			console.error('Error fetching inventory statistics:', err);
			error = 'Failed to load inventory statistics. Please try again.';
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		fetchInventoryStats();
	});
</script>

<div class="reports-container">
	<h1 class="page-title">Inventory Reports</h1>

	{#if loading}
		<div class="loading-container">
			<div class="spinner"></div>
			<p>Loading inventory statistics...</p>
		</div>
	{:else if error}
		<div class="error-container">
			<p class="error-message">{error}</p>
			<button onclick={() => fetchInventoryStats()} class="retry-button">Retry</button>
		</div>
	{:else}
		<ReportsStats
			totalValueCents={totalValueCents}
			cardsOverTenDollars={cardsOverTenDollars}
			totalSets={totalSets}
		/>
	{/if}
</div>

<style>
	.reports-container {
		padding: 2rem;
		max-width: 1200px;
		margin: 0 auto;
	}

	.page-title {
		font-size: 2rem;
		font-weight: 700;
		margin-bottom: 2rem;
		color: var(--color-surface-900);
	}

	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		gap: 1rem;
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid rgba(0, 0, 0, 0.1);
		border-left-color: var(--color-primary-500);
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.error-container {
		padding: 2rem;
		text-align: center;
	}

	.error-message {
		color: var(--color-error-500);
		margin-bottom: 1rem;
		font-size: 1.125rem;
	}

	.retry-button {
		padding: 0.75rem 1.5rem;
		background: var(--color-primary-500);
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.retry-button:hover {
		background: var(--color-primary-600);
	}

	/* Dark mode support */
	:global(.dark) .page-title {
		color: var(--color-surface-50);
	}

	@media (max-width: 640px) {
		.reports-container {
			padding: 1rem;
		}

		.page-title {
			font-size: 1.5rem;
		}
	}
</style>
