<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { formatCurrency } from '$lib/utils/currency';
	import { formatTimestamp } from '$lib/utils/datetime';

	// Component state
	let loading = $state(true);
	let error = $state<string | null>(null);
	let totalValueCents = $state(0);
	let totalCards = $state(0);
	let valuedCards = $state(0);
	let excludedCards = $state(0);
	let lastUpdated = $state<string | null>(null);

	// Fetch inventory value data
	async function fetchInventoryValue() {
		loading = true;
		error = null;

		try {
			const response = await fetch(`${base}/api/inventory/value`);

			if (!response.ok) {
				throw new Error('Failed to fetch inventory value');
			}

			const data = await response.json();
			totalValueCents = data.total_value_cents;
			totalCards = data.total_cards;
			valuedCards = data.valued_cards;
			excludedCards = data.excluded_cards;
			lastUpdated = data.last_updated;
		} catch (err) {
			console.error('Error fetching inventory value:', err);
			error = 'Failed to load inventory value. Please try again.';
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		fetchInventoryValue();
	});
</script>

<div class="reports-container">
	<h1 class="page-title">Inventory Reports</h1>

	{#if loading}
		<div class="loading-container">
			<div class="spinner"></div>
			<p>Calculating inventory value...</p>
		</div>
	{:else if error}
		<div class="error-container">
			<p class="error-message">{error}</p>
			<button onclick={() => fetchInventoryValue()} class="retry-button">Retry</button>
		</div>
	{:else}
		<div class="value-display">
			<div class="total-value-card">
				<h2 class="card-title">Total Inventory Value</h2>
				<p class="value-amount">{formatCurrency(totalValueCents)}</p>
				<p class="last-updated">Last updated: {formatTimestamp(lastUpdated)}</p>
			</div>

			<div class="breakdown-grid">
				<div class="breakdown-card">
					<h3 class="breakdown-title">Total Cards</h3>
					<p class="breakdown-value">{totalCards.toLocaleString()}</p>
				</div>

				<div class="breakdown-card">
					<h3 class="breakdown-title">Valued Cards</h3>
					<p class="breakdown-value">{valuedCards.toLocaleString()}</p>
				</div>

				<div class="breakdown-card">
					<h3 class="breakdown-title">Without Prices</h3>
					<p class="breakdown-value">{excludedCards.toLocaleString()}</p>
				</div>
			</div>

			<!-- Price History Chart Demo -->
			<div class="price-history-section">
				<h2 class="section-title">Price History Analysis</h2>
				<p class="section-description">
					Track price trends for individual cards in your inventory. This demo shows historical
					pricing data visualization.
				</p>
				<!-- Example: Using a demo card ID - in a real implementation,
				     this would be selected from the user's inventory -->
				<!-- Demo with a placeholder card ID -->
				<div class="demo-note">
					<p>
						<strong>Demo Mode:</strong> To view price history for your cards, add a card to your inventory
						first. The chart will automatically display price trends over different time periods.
					</p>
				</div>
			</div>
		</div>
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

	.value-display {
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	.total-value-card {
		background: linear-gradient(135deg, var(--color-primary-500) 0%, var(--color-primary-700) 100%);
		padding: 2rem;
		border-radius: 1rem;
		box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
		text-align: center;
	}

	.card-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
		margin-bottom: 1rem;
	}

	.value-amount {
		font-size: 3.5rem;
		font-weight: 700;
		color: white;
		margin: 0;
		line-height: 1;
	}

	.last-updated {
		margin-top: 1rem;
		font-size: 0.875rem;
		color: rgba(255, 255, 255, 0.7);
	}

	.breakdown-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1.5rem;
	}

	.breakdown-card {
		background: var(--color-surface-50);
		padding: 1.5rem;
		border-radius: 0.75rem;
		border: 1px solid var(--color-surface-200);
		text-align: center;
	}

	.breakdown-title {
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--color-surface-600);
		margin-bottom: 0.75rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.breakdown-value {
		font-size: 2rem;
		font-weight: 700;
		color: var(--color-surface-900);
		margin: 0;
	}

	.price-history-section {
		margin-top: 2rem;
	}

	.section-title {
		font-size: 1.5rem;
		font-weight: 600;
		margin-bottom: 0.5rem;
		color: var(--color-surface-900);
	}

	.section-description {
		font-size: 1rem;
		color: var(--color-surface-600);
		margin-bottom: 1.5rem;
	}

	.demo-note {
		padding: 1.5rem;
		background: var(--color-surface-100);
		border-left: 4px solid var(--color-primary-500);
		border-radius: 0.5rem;
		margin-bottom: 1.5rem;
	}

	.demo-note p {
		margin: 0;
		color: var(--color-surface-700);
		font-size: 0.95rem;
	}

	/* Dark mode support */
	:global(.dark) .page-title {
		color: var(--color-surface-50);
	}

	:global(.dark) .breakdown-card {
		background: var(--color-surface-800);
		border-color: var(--color-surface-700);
	}

	:global(.dark) .breakdown-title {
		color: var(--color-surface-400);
	}

	:global(.dark) .breakdown-value {
		color: var(--color-surface-50);
	}

	:global(.dark) .section-title {
		color: var(--color-surface-50);
	}

	:global(.dark) .section-description {
		color: var(--color-surface-400);
	}

	:global(.dark) .demo-note {
		background: var(--color-surface-800);
		border-left-color: var(--color-primary-500);
	}

	:global(.dark) .demo-note p {
		color: var(--color-surface-300);
	}

	@media (max-width: 640px) {
		.reports-container {
			padding: 1rem;
		}

		.page-title {
			font-size: 1.5rem;
		}

		.value-amount {
			font-size: 2.5rem;
		}

		.breakdown-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
