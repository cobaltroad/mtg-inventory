<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { base } from '$app/paths';
	import { formatCurrency } from '$lib/utils/currency';
	import type { Chart as ChartType } from 'chart.js';

	// Chart will be imported dynamically on mount to avoid SSR issues
	let Chart: any = null;

	// Component props
	let { cardId }: { cardId: string } = $props();

	// Component state
	let loading = $state(true);
	let error = $state<string | null>(null);
	let timePeriod = $state<number | string>(30);
	let priceData = $state<any>(null);
	let chartInstance: ChartType | null = null;
	let canvasElement = $state<HTMLCanvasElement | undefined>(undefined);

	// Treatment visibility toggles
	let showNormal = $state(true);
	let showFoil = $state(true);
	let showEtched = $state(true);

	// Available treatments based on data
	let availableTreatments = $derived(() => {
		if (!priceData?.summary) return [];
		return Object.keys(priceData.summary);
	});

	// Fetch price history data
	async function fetchPriceHistory() {
		loading = true;
		error = null;

		try {
			const response = await fetch(
				`${base}/api/cards/${cardId}/price_history?time_period=${timePeriod}`
			);

			if (!response.ok) {
				throw new Error('Failed to load price history');
			}

			const data = await response.json();
			priceData = data;

			// Create or update chart
			if (canvasElement) {
				createChart();
			}
		} catch (err) {
			console.error('Error fetching price history:', err);
			error = 'Failed to load price history. Please try again.';
		} finally {
			loading = false;
		}
	}

	// Treatment configuration for datasets
	const treatmentConfig = {
		normal: {
			label: 'Normal',
			field: 'usd_cents',
			color: 'rgb(59, 130, 246)',
			show: () => showNormal
		},
		foil: {
			label: 'Foil',
			field: 'usd_foil_cents',
			color: 'rgb(251, 146, 60)',
			show: () => showFoil
		},
		etched: {
			label: 'Etched',
			field: 'usd_etched_cents',
			color: 'rgb(168, 85, 247)',
			show: () => showEtched
		}
	};

	// Create dataset for a treatment type
	function createDataset(treatment: keyof typeof treatmentConfig) {
		const config = treatmentConfig[treatment];
		const data = priceData.prices
			.map((p: any) => ({
				x: new Date(p.fetched_at),
				y: p[config.field] ? p[config.field] / 100 : null
			}))
			.filter((d: any) => d.y !== null);

		return {
			label: config.label,
			data,
			borderColor: config.color,
			backgroundColor: config.color.replace('rgb', 'rgba').replace(')', ', 0.1)'),
			tension: 0.1,
			spanGaps: false
		};
	}

	// Create Chart.js chart
	function createChart() {
		if (!Chart || !priceData || !canvasElement) return;

		// Destroy existing chart
		if (chartInstance) {
			chartInstance.destroy();
		}

		// Prepare datasets for active treatments
		const datasets: any[] = [];

		for (const [treatment, config] of Object.entries(treatmentConfig)) {
			if (config.show() && priceData.summary[treatment]) {
				datasets.push(createDataset(treatment as keyof typeof treatmentConfig));
			}
		}

		// Create chart
		const ctx = canvasElement.getContext('2d');
		if (!ctx) return;

		chartInstance = new Chart(ctx, {
			type: 'line',
			data: { datasets },
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
								const label = context.dataset.label || '';
								const value = formatCurrency((context.parsed.y || 0) * 100);
								return `${label}: ${value}`;
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
								hour: 'MMM d, h a',
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
						beginAtZero: false,
						title: {
							display: true,
							text: 'Price (USD)'
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
		if (timePeriod === 365) return 'month';
		return 'month';
	}

	// Change time period
	function changeTimePeriod(newPeriod: number | string) {
		timePeriod = newPeriod;
		fetchPriceHistory();
	}

	// Toggle treatment visibility
	function toggleTreatment(treatment: string) {
		if (treatment === 'normal') showNormal = !showNormal;
		if (treatment === 'foil') showFoil = !showFoil;
		if (treatment === 'etched') showEtched = !showEtched;
		createChart();
	}

	// Get direction indicator
	function getDirectionIndicator(direction: string): string {
		if (direction === 'up') return '↑';
		if (direction === 'down') return '↓';
		return '—';
	}

	// Get color class for direction
	function getDirectionColor(direction: string): string {
		if (direction === 'up') return 'text-green-600 dark:text-green-400';
		if (direction === 'down') return 'text-red-600 dark:text-red-400';
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
			chartModule.Legend
		);

		fetchPriceHistory();
	});

	onDestroy(() => {
		if (chartInstance) {
			chartInstance.destroy();
		}
	});

	// Reactive statement to update chart when toggles change
	$effect(() => {
		if (priceData && canvasElement) {
			// Dependencies: showNormal, showFoil, showEtched
			(showNormal, showFoil, showEtched);
			createChart();
		}
	});
</script>

<div class="price-history-chart">
	<h2 class="chart-title">Price History</h2>

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
		<button
			class="period-button {timePeriod === 365 ? 'active' : ''}"
			onclick={() => changeTimePeriod(365)}
		>
			1 Year
		</button>
		<button
			class="period-button {timePeriod === 'all' ? 'active' : ''}"
			onclick={() => changeTimePeriod('all')}
		>
			All Time
		</button>
	</div>

	{#if loading}
		<div class="loading-container">
			<div class="spinner"></div>
			<p>Loading price history...</p>
		</div>
	{:else if error}
		<div class="error-container">
			<p class="error-message">{error}</p>
			<button onclick={() => fetchPriceHistory()} class="retry-button">Retry</button>
		</div>
	{:else if !priceData || priceData.prices.length === 0}
		<div class="empty-state">
			<p>No price history available for this card.</p>
		</div>
	{:else}
		<!-- Treatment Toggles -->
		<div class="treatment-toggles">
			{#each availableTreatments() as treatment}
				{@const isNormal = treatment === 'normal'}
				{@const isFoil = treatment === 'foil'}
				{@const isEtched = treatment === 'etched'}
				{@const isActive =
					(isNormal && showNormal) || (isFoil && showFoil) || (isEtched && showEtched)}

				<button
					class="treatment-toggle {isActive ? 'active' : ''}"
					onclick={() => toggleTreatment(treatment)}
				>
					{treatment.charAt(0).toUpperCase() + treatment.slice(1)}
				</button>
			{/each}
		</div>

		<!-- Chart Canvas -->
		<div class="chart-container">
			<canvas bind:this={canvasElement}></canvas>
		</div>

		<!-- Price Change Summary -->
		<div class="summary-container">
			{#each Object.entries(priceData.summary) as [treatment, summary]}
				{@const s = summary as any}
				{@const isNormal = treatment === 'normal'}
				{@const isFoil = treatment === 'foil'}
				{@const isEtched = treatment === 'etched'}
				{@const isVisible =
					(isNormal && showNormal) || (isFoil && showFoil) || (isEtched && showEtched)}

				{#if isVisible}
					<div class="summary-card">
						<div class="summary-header">
							<span class="treatment-name"
								>{treatment.charAt(0).toUpperCase() + treatment.slice(1)}</span
							>
							<span class="percentage-change {getDirectionColor(s.direction)}">
								{getDirectionIndicator(s.direction)}{s.percentage_change > 0
									? '+'
									: ''}{s.percentage_change.toFixed(1)}%
							</span>
						</div>
						<div class="price-change">
							{formatCurrency(s.start_price_cents)} → {formatCurrency(s.end_price_cents)}
						</div>
					</div>
				{/if}
			{/each}
		</div>
	{/if}
</div>

<style>
	.price-history-chart {
		padding: 1.5rem;
		background: var(--color-surface-50);
		border-radius: 0.75rem;
		border: 1px solid var(--color-surface-200);
	}

	.chart-title {
		font-size: 1.25rem;
		font-weight: 600;
		margin-bottom: 1rem;
		color: var(--color-surface-900);
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

	.treatment-toggles {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1rem;
		flex-wrap: wrap;
	}

	.treatment-toggle {
		padding: 0.375rem 0.75rem;
		background: var(--color-surface-100);
		border: 1px solid var(--color-surface-300);
		border-radius: 0.375rem;
		font-size: 0.875rem;
		color: var(--color-surface-700);
		cursor: pointer;
		transition: all 0.2s;
	}

	.treatment-toggle:hover {
		background: var(--color-surface-200);
	}

	.treatment-toggle.active {
		background: var(--color-primary-100);
		border-color: var(--color-primary-500);
		color: var(--color-primary-700);
	}

	.chart-container {
		position: relative;
		height: 300px;
		margin-bottom: 1.5rem;
	}

	.summary-container {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
	}

	.summary-card {
		padding: 1rem;
		background: var(--color-surface-100);
		border-radius: 0.5rem;
		border: 1px solid var(--color-surface-200);
	}

	.summary-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
	}

	.treatment-name {
		font-size: 0.875rem;
		font-weight: 600;
		color: var(--color-surface-700);
	}

	.percentage-change {
		font-size: 1rem;
		font-weight: 700;
	}

	.price-change {
		font-size: 0.875rem;
		color: var(--color-surface-600);
	}

	/* Dark mode support */
	:global(.dark) .price-history-chart {
		background: var(--color-surface-800);
		border-color: var(--color-surface-700);
	}

	:global(.dark) .chart-title {
		color: var(--color-surface-50);
	}

	:global(.dark) .period-button {
		background: var(--color-surface-700);
		border-color: var(--color-surface-600);
		color: var(--color-surface-200);
	}

	:global(.dark) .period-button:hover {
		background: var(--color-surface-600);
	}

	:global(.dark) .treatment-toggle {
		background: var(--color-surface-700);
		border-color: var(--color-surface-600);
		color: var(--color-surface-200);
	}

	:global(.dark) .treatment-toggle:hover {
		background: var(--color-surface-600);
	}

	:global(.dark) .treatment-toggle.active {
		background: var(--color-primary-900);
		border-color: var(--color-primary-500);
		color: var(--color-primary-200);
	}

	:global(.dark) .summary-card {
		background: var(--color-surface-700);
		border-color: var(--color-surface-600);
	}

	:global(.dark) .treatment-name {
		color: var(--color-surface-200);
	}

	:global(.dark) .price-change {
		color: var(--color-surface-400);
	}

	:global(.dark) .empty-state {
		color: var(--color-surface-400);
	}

	@media (max-width: 640px) {
		.price-history-chart {
			padding: 1rem;
		}

		.chart-container {
			height: 250px;
		}

		.summary-container {
			grid-template-columns: 1fr;
		}
	}
</style>
