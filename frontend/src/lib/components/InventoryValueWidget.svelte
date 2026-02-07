<script lang="ts">
	import { onMount } from 'svelte';
	import { base } from '$app/paths';
	import { LayerCake, Svg } from 'layercake';
	import Line from '$lib/components/charts/Line.svelte';
	import AxisX from '$lib/components/charts/AxisX.svelte';
	import AxisY from '$lib/components/charts/AxisY.svelte';

	// ============================================================================
	// Type Definitions
	// ============================================================================

	/**
	 * Represents a single point in the inventory value timeline.
	 */
	interface TimelinePoint {
		date: string;
		value_cents: number;
	}

	/**
	 * Summary statistics for the inventory value timeline.
	 */
	interface Summary {
		start_value_cents: number;
		end_value_cents: number;
		change_cents: number;
		change_percentage: number;
	}

	/**
	 * Complete timeline data response from the API.
	 */
	interface TimelineData {
		time_period: string;
		timeline: TimelinePoint[];
		summary: Summary;
	}

	/**
	 * Transformed data point for chart rendering.
	 */
	interface ChartDataPoint {
		date: Date;
		value: number;
	}

	// ============================================================================
	// Component State
	// ============================================================================

	let loading = $state(true);
	let error = $state<string | null>(null);
	let timePeriod = $state<number>(30);
	let timelineData = $state<TimelineData | null>(null);

	// ============================================================================
	// Utility Functions
	// ============================================================================

	/**
	 * Formats a value in cents as a currency string.
	 * @param cents - The value in cents to format
	 * @returns Formatted currency string (e.g., "$123.45")
	 */
	function formatCurrency(cents: number): string {
		return `$${(cents / 100).toFixed(2)}`;
	}

	/**
	 * Type guard to validate a timeline data point.
	 * @param point - The object to validate
	 * @returns True if the point has all required properties
	 */
	function isValidTimelinePoint(point: any): point is TimelinePoint {
		return (
			point &&
			typeof point === 'object' &&
			typeof point.date === 'string' &&
			typeof point.value_cents === 'number'
		);
	}

	/**
	 * Type guard to validate summary data.
	 * @param summary - The object to validate
	 * @returns True if the summary has all required properties
	 */
	function isValidSummary(summary: any): summary is Summary {
		return (
			summary &&
			typeof summary === 'object' &&
			typeof summary.start_value_cents === 'number' &&
			typeof summary.end_value_cents === 'number' &&
			typeof summary.change_cents === 'number' &&
			typeof summary.change_percentage === 'number'
		);
	}

	/**
	 * Gets the appropriate sign prefix for a value change.
	 * @param changeCents - The change value in cents
	 * @returns "+" for positive or zero, "" for negative (minus sign is in the number)
	 */
	function getChangeSign(changeCents: number): string {
		return changeCents >= 0 ? '+' : '';
	}

	// ============================================================================
	// Data Fetching
	// ============================================================================

	/**
	 * Fetches inventory value timeline data from the API.
	 * Updates component state based on success or failure.
	 */
	async function fetchTimeline(): Promise<void> {
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

			// Validate the response structure
			if (!data || typeof data !== 'object') {
				throw new Error('Invalid response format');
			}

			timelineData = data;
		} catch (err) {
			console.error('Error fetching inventory value timeline:', err);
			error =
				err instanceof Error
					? err.message
					: 'Failed to load inventory value timeline. Please try again.';
			timelineData = null;
		} finally {
			loading = false;
		}
	}

	/**
	 * Changes the time period and refetches timeline data.
	 * @param days - Number of days for the timeline period
	 */
	function changeTimePeriod(days: number): void {
		timePeriod = days;
		fetchTimeline();
	}

	// ============================================================================
	// Derived State
	// ============================================================================

	/**
	 * Checks if we have valid timeline data to display.
	 * Returns false if timeline is missing, not an array, or empty.
	 */
	let hasValidTimeline = $derived.by(() => {
		if (!timelineData?.timeline || !Array.isArray(timelineData.timeline)) {
			return false;
		}
		return timelineData.timeline.length > 0;
	});

	/**
	 * Checks if we have valid summary data to display.
	 * Uses type guard to ensure all required properties exist.
	 */
	let hasValidSummary = $derived.by(() => {
		return timelineData?.summary && isValidSummary(timelineData.summary);
	});

	/**
	 * Transforms timeline data into chart-ready format.
	 * Filters out invalid points and converts cents to dollars.
	 */
	let chartData = $derived.by((): ChartDataPoint[] => {
		if (!hasValidTimeline) return [];

		// Filter and validate timeline points before mapping
		return timelineData!.timeline.filter(isValidTimelinePoint).map((point) => ({
			date: new Date(point.date),
			value: point.value_cents / 100
		}));
	});

	/**
	 * Checks if we have valid data for chart rendering.
	 * Ensures we have at least one data point with valid values.
	 */
	let hasValidChartData = $derived.by(() => {
		return chartData.length > 0 && chartData.every((point) => !isNaN(point.value));
	});

	// ============================================================================
	// Lifecycle
	// ============================================================================

	onMount(() => {
		fetchTimeline();
	});
</script>

<div class="inventory-value-widget variant-ghost-surface card p-4">
	{#if loading}
		<div class="placeholder animate-pulse space-y-3">
			<div class="bg-surface-300-600-token h-6 w-48 rounded"></div>
			<div class="bg-surface-300-600-token h-48 rounded"></div>
		</div>
	{:else if error}
		<h2 class="mb-4 h3">Inventory Value Over Time</h2>
		<div class="alert variant-ghost-error p-4">
			<p>{error}</p>
			<button onclick={() => fetchTimeline()} class="variant-filled-error mt-2 btn"> Retry </button>
		</div>
	{:else if !hasValidTimeline}
		<h2 class="mb-4 h3">Inventory Value Over Time</h2>
		<div class="text-surface-600-300-token p-8 text-center">
			<p>No value timeline data available.</p>
		</div>
	{:else}
		<h2 class="mb-4 h3">Inventory Value Over Time</h2>

		<!-- Time Period Selector -->
		<div class="variant-ghost mb-4 btn-group">
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

		{#if hasValidSummary}
			<!-- Value Summary -->
			<div class="mb-4 grid grid-cols-1 gap-4 md:grid-cols-2">
				<div class="variant-ghost card p-4">
					<div class="text-surface-600-300-token text-sm">Current Value</div>
					<div class="text-2xl font-bold">
						{formatCurrency(timelineData.summary.end_value_cents)}
					</div>
				</div>
				<div class="variant-ghost card p-4">
					<div class="text-surface-600-300-token text-sm">Change ({timePeriod}d)</div>
					<div
						class="text-2xl font-bold"
						class:text-success-500={timelineData.summary.change_cents >= 0}
						class:text-error-500={timelineData.summary.change_cents < 0}
					>
						{getChangeSign(timelineData.summary.change_cents)}
						{formatCurrency(timelineData.summary.change_cents)}
						({getChangeSign(
							timelineData.summary.change_cents
						)}{timelineData.summary.change_percentage.toFixed(2)}%)
					</div>
				</div>
			</div>
		{/if}

		<!-- Chart -->
		{#if hasValidChartData}
			<div class="chart-container" style="height: 300px;">
				<LayerCake
					padding={{ top: 20, right: 20, bottom: 40, left: 60 }}
					x="date"
					y="value"
					xScale="time"
					yScale="linear"
					data={chartData}
				>
					<Svg>
						<AxisX />
						<AxisY ticks={5} formatTick={(d) => `$${d}`} />
						<Line />
					</Svg>
				</LayerCake>
			</div>
		{/if}
	{/if}
</div>

<style>
	.inventory-value-widget {
		max-width: 100%;
	}

	.chart-container {
		position: relative;
		width: 100%;
	}
</style>
