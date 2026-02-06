<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { LayerCake, Svg } from 'layercake';
	import Line from '$lib/components/charts/Line.svelte';
	import AxisX from '$lib/components/charts/AxisX.svelte';
	import AxisY from '$lib/components/charts/AxisY.svelte';

	// Component state
	let loading = $state(true);
	let error = $state<string | null>(null);
	let timePeriod = $state<number>(30);
	let timelineData = $state<any>(null);

	// Format currency
	function formatCurrency(cents: number): string {
		return `$${(cents / 100).toFixed(2)}`;
	}

	// Fetch inventory value timeline data
	async function fetchTimeline() {
		loading = true;
		error = null;

		try {
			const response = await fetch(
				`${base}/api/inventory/value_timeline?time_period=${timePeriod}`
			);

			if (!response.ok) {
				throw new Error('Failed to load inventory value timeline');
			}

			const data = await response.json();
			timelineData = data;
		} catch (err) {
			console.error('Error fetching inventory value timeline:', err);
			error = 'Failed to load inventory value timeline. Please try again.';
		} finally {
			loading = false;
		}
	}

	// Change time period
	function changeTimePeriod(days: number) {
		timePeriod = days;
		fetchTimeline();
	}

	// Prepare data for chart
	let chartData = $derived.by(() => {
		if (!timelineData) return [];
		return timelineData.timeline.map((point: any) => ({
			date: new Date(point.date),
			value: point.value_cents / 100
		}));
	});

	onMount(() => {
		fetchTimeline();
	});
</script>

{#if !loading && timelineData && timelineData.summary.end_value_cents > 0}
	<div class="inventory-value-widget card variant-ghost-surface p-4">
		<h2 class="h3 mb-4">Inventory Value Over Time</h2>

		<!-- Time Period Selector -->
		<div class="btn-group variant-ghost mb-4">
			<button
				class="btn {timePeriod === 7 ? 'variant-filled-primary' : 'variant-ghost-surface'}"
				onclick={() => changeTimePeriod(7)}
			>
				7 Days
			</button>
			<button
				class="btn {timePeriod === 30 ? 'variant-filled-primary' : 'variant-ghost-surface'}"
				onclick={() => changeTimePeriod(30)}
			>
				30 Days
			</button>
			<button
				class="btn {timePeriod === 90 ? 'variant-filled-primary' : 'variant-ghost-surface'}"
				onclick={() => changeTimePeriod(90)}
			>
				90 Days
			</button>
		</div>

		{#if loading}
			<div class="flex items-center justify-center p-8">
				<div class="animate-pulse">Loading value timeline...</div>
			</div>
		{:else if error}
			<div class="alert variant-ghost-error p-4">
				<p>{error}</p>
				<button onclick={() => fetchTimeline()} class="btn variant-filled-error mt-2">
					Retry
				</button>
			</div>
		{:else if timelineData.timeline.length === 0}
			<div class="text-center p-8 text-surface-600-300-token">
				<p>No value timeline data available.</p>
			</div>
		{:else}
			<!-- Value Summary -->
			<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
				<div class="card variant-ghost p-4">
					<div class="text-sm text-surface-600-300-token">Current Value</div>
					<div class="text-2xl font-bold">
						{formatCurrency(timelineData.summary.end_value_cents)}
					</div>
				</div>
				<div class="card variant-ghost p-4">
					<div class="text-sm text-surface-600-300-token">Change ({timePeriod}d)</div>
					<div
						class="text-2xl font-bold"
						class:text-success-500={timelineData.summary.change_cents >= 0}
						class:text-error-500={timelineData.summary.change_cents < 0}
					>
						{timelineData.summary.change_cents >= 0 ? '+' : ''}
						{formatCurrency(timelineData.summary.change_cents)}
						({timelineData.summary.change_cents >= 0 ? '+' : ''}{timelineData.summary.change_percentage.toFixed(
							2
						)}%)
					</div>
				</div>
			</div>

			<!-- Chart -->
			<div class="chart-container" style="height: 300px;">
				<LayerCake
					padding={{ top: 20, right: 20, bottom: 40, left: 60 }}
					x="date"
					y="value"
					xScale="time"
					yScale="linear"
					data={timelineData.timeline.map((point: any) => ({
						date: new Date(point.date),
						value: point.value_cents / 100
					}))}
				>
					<Svg>
						<AxisX />
						<AxisY ticks={5} formatTick={(d) => `$${d}`} />
						<Line />
					</Svg>
				</LayerCake>
			</div>
		{/if}
	</div>
{:else if loading}
	<div class="card variant-ghost-surface p-4">
		<div class="placeholder animate-pulse space-y-3">
			<div class="h-6 w-48 bg-surface-300-600-token rounded"></div>
			<div class="h-48 bg-surface-300-600-token rounded"></div>
		</div>
	</div>
{/if}

<style>
	.inventory-value-widget {
		max-width: 100%;
	}

	.chart-container {
		position: relative;
		width: 100%;
	}
</style>
