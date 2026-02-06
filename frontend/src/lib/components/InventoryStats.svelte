<script lang="ts">
	import type { InventoryStats } from '$lib/types/inventory';
	import { Library, Package, Layers, Trophy } from 'lucide-svelte';

	interface Props {
		stats: InventoryStats;
	}

	let { stats }: Props = $props();
</script>

<div class="stats-container">
	<div class="stat-card">
		<div class="stat-icon">
			<Library size={20} />
		</div>
		<div class="stat-content">
			<div class="stat-value">{stats.totalUniqueCards}</div>
			<div class="stat-label">Unique Cards</div>
		</div>
	</div>

	<div class="stat-card">
		<div class="stat-icon">
			<Package size={20} />
		</div>
		<div class="stat-content">
			<div class="stat-value">{stats.totalQuantity}</div>
			<div class="stat-label">Total Quantity</div>
		</div>
	</div>

	<div class="stat-card">
		<div class="stat-icon">
			<Layers size={20} />
		</div>
		<div class="stat-content">
			<div class="stat-value">{stats.totalSets}</div>
			<div class="stat-label">Different Sets</div>
		</div>
	</div>

	{#if stats.mostCollectedSet}
		<div class="stat-card">
			<div class="stat-icon">
				<Trophy size={20} />
			</div>
			<div class="stat-content">
				<div class="stat-value">{stats.mostCollectedSet}</div>
				<div class="stat-label">Most Collected Set</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.stats-container {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 1rem;
		margin-bottom: 1.5rem;
	}

	.stat-card {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 1rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		transition: all 0.2s;
	}

	.stat-card:hover {
		border-color: #3b82f6;
		box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
	}

	:global(.dark) .stat-card {
		background: #374151;
		border-color: #4b5563;
	}

	:global(.dark) .stat-card:hover {
		border-color: #60a5fa;
	}

	.stat-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 2.5rem;
		height: 2.5rem;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 0.5rem;
	}

	:global(.dark) .stat-icon {
		background: #1e3a8a;
		color: #93c5fd;
	}

	.stat-content {
		flex: 1;
	}

	.stat-value {
		font-size: 1.5rem;
		font-weight: 700;
		color: #111827;
		line-height: 1.2;
	}

	:global(.dark) .stat-value {
		color: #e5e7eb;
	}

	.stat-label {
		font-size: 0.875rem;
		color: #6b7280;
		margin-top: 0.25rem;
	}

	:global(.dark) .stat-label {
		color: #9ca3af;
	}

	@media (max-width: 768px) {
		.stats-container {
			grid-template-columns: 1fr;
		}

		.stat-value {
			font-size: 1.25rem;
		}
	}
</style>
