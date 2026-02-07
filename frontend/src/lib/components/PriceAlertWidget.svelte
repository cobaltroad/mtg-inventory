<script lang="ts">
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { TrendingUp, TrendingDown, X } from 'lucide-svelte';

	interface PriceAlert {
		id: number;
		card_id: string;
		alert_type: 'price_increase' | 'price_decrease';
		old_price_cents: number;
		new_price_cents: number;
		percentage_change: string;
		treatment: string | null;
		created_at: string;
	}

	let alerts = $state<PriceAlert[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);

	async function fetchAlerts() {
		try {
			loading = true;
			error = null;
			const response = await fetch(`${base}/api/price_alerts`);

			if (!response.ok) {
				throw new Error('Failed to fetch price alerts');
			}

			alerts = await response.json();
		} catch (err) {
			console.error('Error fetching price alerts:', err);
			error = err instanceof Error ? err.message : 'Failed to load price alerts';
		} finally {
			loading = false;
		}
	}

	async function dismissAlert(alertId: number) {
		try {
			const response = await fetch(`${base}/api/price_alerts/${alertId}/dismiss`, {
				method: 'PATCH'
			});

			if (!response.ok) {
				throw new Error('Failed to dismiss alert');
			}

			// Remove the alert from the list
			alerts = alerts.filter((a) => a.id !== alertId);
		} catch (err) {
			console.error('Error dismissing alert:', err);
		}
	}

	function formatPrice(cents: number): string {
		return `$${(cents / 100).toFixed(2)}`;
	}

	function formatDate(dateString: string): string {
		const date = new Date(dateString);
		const now = new Date();
		const diffMs = now.getTime() - date.getTime();
		const diffHours = Math.floor(diffMs / (1000 * 60 * 60));

		if (diffHours < 1) {
			return 'Just now';
		} else if (diffHours < 24) {
			return `${diffHours}h ago`;
		} else {
			const diffDays = Math.floor(diffHours / 24);
			return `${diffDays}d ago`;
		}
	}

	onMount(() => {
		fetchAlerts();
	});
</script>

{#if !loading && alerts.length > 0}
	<div class="price-alert-widget variant-ghost-surface card p-4">
		<h2 class="mb-4 h3">Price Alerts</h2>

		<div class="space-y-3">
			{#each alerts as alert (alert.id)}
				<div
					class="alert-item variant-soft flex items-start gap-3 card p-3"
					class:variant-soft-success={alert.alert_type === 'price_increase'}
					class:variant-soft-error={alert.alert_type === 'price_decrease'}
				>
					<!-- Icon -->
					<div class="mt-0.5 flex-shrink-0">
						{#if alert.alert_type === 'price_increase'}
							<TrendingUp class="text-success-500" size={20} />
						{:else}
							<TrendingDown class="text-error-500" size={20} />
						{/if}
					</div>

					<!-- Content -->
					<div class="min-w-0 flex-grow">
						<div class="flex items-start justify-between gap-2">
							<div class="flex-grow">
								<p class="text-sm font-medium">
									{#if alert.alert_type === 'price_increase'}
										Price Increase
									{:else}
										Price Drop
									{/if}
									{#if alert.treatment && alert.treatment !== 'normal'}
										<span class="text-surface-600-300-token">({alert.treatment})</span>
									{/if}
								</p>
								<p class="text-surface-600-300-token mt-1 text-xs">
									{formatPrice(alert.old_price_cents)} → {formatPrice(alert.new_price_cents)}
									<span
										class="font-semibold"
										class:text-success-500={alert.alert_type === 'price_increase'}
										class:text-error-500={alert.alert_type === 'price_decrease'}
									>
										({parseFloat(alert.percentage_change) > 0 ? '+' : ''}{alert.percentage_change}%)
									</span>
								</p>
								<p class="text-surface-500-400-token mt-1 text-xs">
									{formatDate(alert.created_at)}
								</p>
							</div>

							<!-- Dismiss button -->
							<button
								type="button"
								class="variant-ghost-surface btn-icon btn-icon-sm"
								onclick={() => dismissAlert(alert.id)}
								aria-label="Dismiss alert"
							>
								<X size={16} />
							</button>
						</div>
					</div>
				</div>
			{/each}
		</div>

		{#if alerts.length === 10}
			<p class="text-surface-500-400-token mt-3 text-center text-xs">
				Showing top 10 most recent alerts
			</p>
		{/if}
	</div>
{:else if loading}
	<div class="price-alert-widget variant-ghost-surface card p-4">
		<div class="placeholder animate-pulse space-y-3">
			<div class="bg-surface-300-600-token h-6 w-32 rounded"></div>
			<div class="bg-surface-300-600-token h-16 rounded"></div>
			<div class="bg-surface-300-600-token h-16 rounded"></div>
		</div>
	</div>
{:else if error}
	<div class="price-alert-widget variant-ghost-error card p-4">
		<p class="text-sm text-error-500">{error}</p>
	</div>
{/if}

<style>
	.price-alert-widget {
		max-width: 600px;
	}

	.alert-item {
		transition: all 0.2s ease;
	}

	.alert-item:hover {
		transform: translateX(4px);
	}
</style>
