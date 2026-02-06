<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { base } from '$app/paths';
	import { formatCurrency } from '$lib/utils/currency';
	import type { Chart as ChartType } from 'chart.js';

	// Chart will be imported dynamically on mount to avoid SSR issues
	let Chart: any = null;

	// Component state
	let loading = $state(true);
	let error = $state<string | null>(null);
	let timePeriod = $state<number>(30);
	let timelineData = $state<any>(null);
	let chartInstance: ChartType | null = null;
	let canvasElement = $state<HTMLCanvasElement | undefined>(undefined);

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

			// Create or update chart
			if (canvasElement) {
				createChart();
			}
		} catch (err) {
			console.error('Error fetching inventory value timeline:', err);
			error = 'Failed to load inventory value timeline. Please try again.';
		} finally {
			loading = false;
		}
	}

	// Create Chart.js chart
	function createChart() {
		if (!Chart || !timelineData || !canvasElement) return;

		// Destroy existing chart
		if (chartInstance) {
			chartInstance.destroy();
		}

		// Prepare data from timeline
		const data = timelineData.timeline.map((point: any) => ({
			x: new Date(point.date),
			y: point.value_cents / 100 // Convert cents to dollars
		}));

		// Create chart
		const ctx = canvasElement.getContext('2d');
		if (!ctx) return;

		chartInstance = new Chart(ctx, {
			type: 'line',
			data: {
				datasets: [
					{
						label: 'Inventory Value',
						data,
						borderColor: 'rgb(59, 130, 246)',
						backgroundColor: 'rgba(59, 130, 246, 0.1)',
						tension: 0.1,
						fill: true
					}
				]
			},
			options: {
				responsive: true,
				maintainAspectRatio: false,
				interaction: {
					mode: 'index',
					intersect: false
				},
				plugins: {
					legend: {
						display: false
					},
					tooltip: {
						callbacks: {
							label: function (context) {
								const value = formatCurrency((context.parsed.y || 0) * 100);
								return `Value: ${value}`;
							}
						}
					}
				},
				scales: {
					x: {
						type: 'time',
						time: {
							unit: getTimeUnit(),
							displayFormats: {
								day: 'MMM d',
								week: 'MMM d',
								month: 'MMM yyyy'
							}
						},
						title: {
							display: true,
							text: 'Date'
						}
					},
					y: {
						beginAtZero: true,
						title: {
							display: true,
							text: 'Value (USD)'
						},
						ticks: {
							callback: function (value) {
								return '$' + value.toLocaleString();
							}
						}
					}
				}
			}
		});
	}

	// Determine appropriate time unit for x-axis
	function getTimeUnit(): string {
		if (timePeriod === 7) return 'day';
		if (timePeriod === 30) return 'day';
		if (timePeriod === 90) return 'week';
		return 'day';
	}

	// Change time period
	function changeTimePeriod(newPeriod: number) {
		timePeriod = newPeriod;
		fetchTimeline();
	}

	// Get direction indicator
	function getDirectionIndicator(change: number): string {
		if (change > 0) return '↑';
		if (change < 0) return '↓';
		return '—';
	}

	// Get color class for direction
	function getDirectionColor(change: number): string {
		if (change > 0) return 'text-green-600 dark:text-green-400';
		if (change < 0) return 'text-red-600 dark:text-red-400';
		return 'text-gray-600 dark:text-gray-400';
	}

	// Lifecycle
	onMount(async () => {
		// Dynamically import Chart.js to avoid SSR issues
		const chartModule = await import('chart.js');
		Chart = chartModule.Chart;

		// Import date adapter
		await import('chartjs-adapter-date-fns');

		// Register Chart.js components
		Chart.register(
			chartModule.LineController,
			chartModule.LineElement,
			chartModule.PointElement,
			chartModule.LinearScale,
			chartModule.TimeScale,
			chartModule.Title,
			chartModule.Tooltip,
			chartModule.Legend,
			chartModule.Filler
		);

		fetchTimeline();
	});

	onDestroy(() => {
		if (chartInstance) {
			chartInstance.destroy();
		}
	});

	// Reactive statement to update chart when data changes
	$effect(() => {
		if (timelineData && canvasElement) {
			createChart();
		}
	});
</script>

{#if !loading && timelineData && timelineData.summary.end_value_cents > 0}
	<div class="inventory-value-widget card variant-ghost-surface p-4">
		<h2 class="h3 mb-4">Inventory Value Over Time</h2>

		<!-- Time Period Selector -->
		<div class="time-period-selector">
			<button
				class="period-button {timePeriod === 7 ? 'active' : ''}"
				onclick={() => changeTimePeriod(7)}
			>
				7 Days
			</button>
			<button
				class="period-button {timePeriod === 30 ? 'active' : ''}"
				onclick={() => changeTimePeriod(30)}
			>
				30 Days
			</button>
			<button
				class="period-button {timePeriod === 90 ? 'active' : ''}"
				onclick={() => changeTimePeriod(90)}
			>
				90 Days
			</button>
		</div>

		{#if loading}
			<div class="loading-container">
				<div class="spinner"></div>
				<p>Loading value timeline...</p>
			</div>
		{:else if error}
			<div class="error-container">
				<p class="error-message">{error}</p>
				<button onclick={() => fetchTimeline()} class="retry-button">Retry</button>
			</div>
		{:else if !timelineData || timelineData.timeline.length === 0}
			<div class="empty-state">
				<p>No value timeline data available.</p>
			</div>
		{:else}
			<!-- Chart Canvas -->
			<div class="chart-container">
				<canvas bind:this={canvasElement}></canvas>
			</div>

			<!-- Value Change Summary -->
			<div class="summary-container">
				<div class="summary-card">
					<div class="summary-label">Starting Value</div>
					<div class="summary-value">
						{formatCurrency(timelineData.summary.start_value_cents)}
					</div>
				</div>

				<div class="summary-card">
					<div class="summary-label">Current Value</div>
					<div class="summary-value">
						{formatCurrency(timelineData.summary.end_value_cents)}
					</div>
				</div>

				<div class="summary-card">
					<div class="summary-label">Change</div>
					<div class="summary-value {getDirectionColor(timelineData.summary.change_cents)}">
						{getDirectionIndicator(timelineData.summary.change_cents)}
						{formatCurrency(Math.abs(timelineData.summary.change_cents))}
						<span class="text-sm">
							({timelineData.summary.percentage_change > 0 ? '+' : ''}{timelineData.summary.percentage_change.toFixed(
								1
							)}%)
						</span>
					</div>
				</div>
			</div>
		{/if}
	</div>
{:else if loading}
	<div class="inventory-value-widget card variant-ghost-surface p-4">
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

	.time-period-selector {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1.5rem;
		flex-wrap: wrap;
	}

	.period-button {
		padding: 0.5rem 1rem;
		background: var(--color-surface-100);
		border: 1px solid var(--color-surface-300);
		border-radius: 0.5rem;
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--color-surface-700);
		cursor: pointer;
		transition: all 0.2s;
	}

	.period-button:hover {
		background: var(--color-surface-200);
	}

	.period-button.active {
		background: var(--color-primary-500);
		color: white;
		border-color: var(--color-primary-600);
	}

	.loading-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem 1rem;
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
		font-size: 1rem;
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

	.empty-state {
		padding: 3rem 1rem;
		text-align: center;
		color: var(--color-surface-600);
	}

	.chart-container {
		position: relative;
		height: 250px;
		margin-bottom: 1.5rem;
	}

	.summary-container {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
		gap: 1rem;
	}

	.summary-card {
		padding: 1rem;
		background: var(--color-surface-100);
		border-radius: 0.5rem;
		border: 1px solid var(--color-surface-200);
		text-align: center;
	}

	.summary-label {
		font-size: 0.75rem;
		font-weight: 600;
		color: var(--color-surface-600);
		text-transform: uppercase;
		margin-bottom: 0.5rem;
	}

	.summary-value {
		font-size: 1.25rem;
		font-weight: 700;
		color: var(--color-surface-900);
	}

	/* Dark mode support */
	:global(.dark) .period-button {
		background: var(--color-surface-700);
		border-color: var(--color-surface-600);
		color: var(--color-surface-200);
	}

	:global(.dark) .period-button:hover {
		background: var(--color-surface-600);
	}

	:global(.dark) .summary-card {
		background: var(--color-surface-700);
		border-color: var(--color-surface-600);
	}

	:global(.dark) .summary-label {
		color: var(--color-surface-400);
	}

	:global(.dark) .summary-value {
		color: var(--color-surface-50);
	}

	:global(.dark) .empty-state {
		color: var(--color-surface-400);
	}

	@media (max-width: 640px) {
		.chart-container {
			height: 200px;
		}

		.summary-container {
			grid-template-columns: 1fr;
		}
	}
</style>
