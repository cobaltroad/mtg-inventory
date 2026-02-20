<script lang="ts">
	import { X } from 'lucide-svelte';

	interface Props {
		selectedColors: string[];
		onColorChange: (colors: string[]) => void;
	}

	let { selectedColors, onColorChange }: Props = $props();

	// MTG color definitions with mana symbols
	const colors = [
		{ code: 'W', name: 'White', symbol: 'W', bg: 'bg-amber-50', border: 'border-amber-300', activeBg: 'bg-amber-200' },
		{ code: 'U', name: 'Blue', symbol: 'U', bg: 'bg-blue-50', border: 'border-blue-400', activeBg: 'bg-blue-200' },
		{ code: 'B', name: 'Black', symbol: 'B', bg: 'bg-gray-50', border: 'border-gray-800', activeBg: 'bg-gray-300' },
		{ code: 'R', name: 'Red', symbol: 'R', bg: 'bg-red-50', border: 'border-red-500', activeBg: 'bg-red-200' },
		{ code: 'G', name: 'Green', symbol: 'G', bg: 'bg-green-50', border: 'border-green-500', activeBg: 'bg-green-200' }
	] as const;

	const specialFilters = [
		{ code: 'multicolor', name: 'Multicolor', symbol: 'M' },
		{ code: 'colorless', name: 'Colorless', symbol: 'C' }
	] as const;

	function toggleColor(colorCode: string) {
		if (selectedColors.includes(colorCode)) {
			onColorChange(selectedColors.filter((c) => c !== colorCode));
		} else {
			onColorChange([...selectedColors, colorCode]);
		}
	}

	function clearFilters() {
		onColorChange([]);
	}

	let hasActiveFilters = $derived(selectedColors.length > 0);
</script>

<div class="color-filter">
	<div class="color-buttons">
		<!-- Main colors -->
		{#each colors as color}
			<button
				class="color-button {selectedColors.includes(color.code) ? 'active' : ''}"
				class:active={selectedColors.includes(color.code)}
				onclick={() => toggleColor(color.code)}
				aria-label="Filter by {color.name}"
				aria-pressed={selectedColors.includes(color.code)}
				title={color.name}
			>
				<span class="mana-symbol mana-{color.code.toLowerCase()}">{color.symbol}</span>
			</button>
		{/each}

		<div class="divider"></div>

		<!-- Special filters -->
		{#each specialFilters as filter}
			<button
				class="color-button special-filter {selectedColors.includes(filter.code) ? 'active' : ''}"
				class:active={selectedColors.includes(filter.code)}
				onclick={() => toggleColor(filter.code)}
				aria-label="Filter by {filter.name}"
				aria-pressed={selectedColors.includes(filter.code)}
				title={filter.name}
			>
				<span class="mana-symbol mana-{filter.code}">{filter.symbol}</span>
			</button>
		{/each}

		{#if hasActiveFilters}
			<button
				class="clear-all-button"
				onclick={clearFilters}
				aria-label="Clear all color filters"
				title="Clear all color filters"
			>
				<X size={16} />
			</button>
		{/if}
	</div>
</div>

<style>
	.color-filter {
		display: flex;
		align-items: center;
	}

	.clear-all-button {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 2rem;
		height: 2rem;
		padding: 0;
		background: #ef4444;
		border: none;
		border-radius: 0.375rem;
		color: white;
		cursor: pointer;
		transition: background 0.2s;
		flex-shrink: 0;
	}

	.clear-all-button:hover {
		background: #dc2626;
	}

	.color-buttons {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.divider {
		width: 1px;
		height: 2rem;
		background: #d1d5db;
		margin: 0 0.25rem;
	}

	:global(.dark) .divider {
		background: #4b5563;
	}

	.color-button {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 2.5rem;
		height: 2.5rem;
		padding: 0;
		background: white;
		border: 2px solid #d1d5db;
		border-radius: 50%;
		cursor: pointer;
		transition: all 0.2s;
		position: relative;
	}

	.color-button:hover {
		transform: scale(1.1);
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
	}

	.color-button:focus {
		outline: 2px solid #3b82f6;
		outline-offset: 2px;
	}

	.color-button.active {
		border-width: 3px;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
	}

	:global(.dark) .color-button {
		background: #374151;
		border-color: #4b5563;
	}

	:global(.dark) .color-button:hover {
		background: #4b5563;
	}

	:global(.dark) .color-button.active {
		box-shadow: 0 0 0 3px rgba(96, 165, 250, 0.3);
	}

	.mana-symbol {
		font-size: 1.25rem;
		font-weight: bold;
		line-height: 1;
	}

	/* Color-specific styling */
	.mana-w {
		color: #f9fafb;
		text-shadow: 0 0 2px #d97706, 0 1px 2px rgba(0, 0, 0, 0.3);
	}

	.color-button:has(.mana-w) {
		background: linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%);
		border-color: #f59e0b;
	}

	.color-button.active:has(.mana-w) {
		border-color: #d97706;
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
	}

	.mana-u {
		color: #1e40af;
	}

	.color-button:has(.mana-u) {
		background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
		border-color: #3b82f6;
	}

	.color-button.active:has(.mana-u) {
		border-color: #2563eb;
		background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
	}

	.mana-b {
		color: #1f2937;
	}

	.color-button:has(.mana-b) {
		background: linear-gradient(135deg, #f9fafb 0%, #e5e7eb 100%);
		border-color: #1f2937;
	}

	.color-button.active:has(.mana-b) {
		border-color: #111827;
		background: linear-gradient(135deg, #e5e7eb 0%, #d1d5db 100%);
	}

	.mana-r {
		color: #dc2626;
	}

	.color-button:has(.mana-r) {
		background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
		border-color: #ef4444;
	}

	.color-button.active:has(.mana-r) {
		border-color: #dc2626;
		background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
	}

	.mana-g {
		color: #16a34a;
	}

	.color-button:has(.mana-g) {
		background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
		border-color: #22c55e;
	}

	.color-button.active:has(.mana-g) {
		border-color: #16a34a;
		background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
	}

	/* Special filters styling - Multicolor (M) and Colorless (C) */
	.mana-multicolor {
		color: #f59e0b;
		font-weight: bold;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	.color-button:has(.mana-multicolor) {
		background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
		border-color: #f59e0b;
	}

	.color-button.active:has(.mana-multicolor) {
		border-color: #d97706;
		background: linear-gradient(135deg, #fde68a 0%, #fcd34d 100%);
	}

	.mana-colorless {
		color: #6b7280;
		font-weight: bold;
	}

	.color-button:has(.mana-colorless) {
		background: linear-gradient(135deg, #f9fafb 0%, #e5e7eb 100%);
		border-color: #9ca3af;
	}

	.color-button.active:has(.mana-colorless) {
		border-color: #6b7280;
		background: linear-gradient(135deg, #e5e7eb 0%, #d1d5db 100%);
	}

	/* Responsive adjustments */
	@media (max-width: 640px) {
		.color-buttons {
			gap: 0.375rem;
		}

		.color-button {
			width: 2.25rem;
			height: 2.25rem;
		}

		.mana-symbol {
			font-size: 1rem;
		}

		.special-filter {
			min-width: 4rem;
			height: 2.25rem;
		}
	}
</style>
