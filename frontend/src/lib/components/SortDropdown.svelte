<script lang="ts">
	import type { SortOption } from '$lib/types/inventory';
	import { ArrowUpDown } from 'lucide-svelte';

	interface Props {
		currentSort: SortOption;
		onSortChange: (sort: SortOption) => void;
	}

	let { currentSort, onSortChange }: Props = $props();

	const sortOptions: { value: SortOption; label: string }[] = [
		{ value: 'name-asc', label: 'Card Name (A-Z)' },
		{ value: 'name-desc', label: 'Card Name (Z-A)' },
		{ value: 'set-asc', label: 'Set Name (A-Z)' },
		{ value: 'set-desc', label: 'Set Name (Z-A)' },
		{ value: 'release-newest', label: 'Release Date (Newest First)' },
		{ value: 'release-oldest', label: 'Release Date (Oldest First)' },
		{ value: 'quantity-high', label: 'Quantity (Highest to Lowest)' },
		{ value: 'quantity-low', label: 'Quantity (Lowest to Highest)' },
		{ value: 'date-newest', label: 'Date Added (Most Recent)' },
		{ value: 'date-oldest', label: 'Date Added (Oldest)' }
	];

	let currentLabel = $derived(
		sortOptions.find((opt) => opt.value === currentSort)?.label || 'Sort by...'
	);
</script>

<div class="sort-dropdown">
	<label for="sort-select" class="sort-label">
		<ArrowUpDown size={16} />
		Sort:
	</label>
	<select
		id="sort-select"
		class="sort-select"
		value={currentSort}
		onchange={(e) => onSortChange(e.currentTarget.value as SortOption)}
	>
		{#each sortOptions as option}
			<option value={option.value}>{option.label}</option>
		{/each}
	</select>
</div>

<style>
	.sort-dropdown {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.sort-label {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	:global(.dark) .sort-label {
		color: #e5e7eb;
	}

	.sort-select {
		padding: 0.5rem 2rem 0.5rem 0.75rem;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		color: #374151;
		cursor: pointer;
		transition: all 0.2s;
		appearance: none;
		background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e");
		background-position: right 0.5rem center;
		background-repeat: no-repeat;
		background-size: 1.5em 1.5em;
	}

	.sort-select:hover {
		border-color: #9ca3af;
	}

	.sort-select:focus {
		outline: 2px solid #93c5fd;
		outline-offset: 2px;
		border-color: #3b82f6;
	}

	:global(.dark) .sort-select {
		background-color: #374151;
		border-color: #4b5563;
		color: #e5e7eb;
		background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%239ca3af' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e");
	}

	:global(.dark) .sort-select:hover {
		border-color: #6b7280;
	}

	:global(.dark) .sort-select:focus {
		border-color: #60a5fa;
	}
</style>
