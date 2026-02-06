<script lang="ts">
	import type { InventoryItem } from '$lib/types/inventory';
	import { Filter, X } from 'lucide-svelte';

	interface Props {
		items: InventoryItem[];
		currentFilter: string;
		onFilterChange: (filter: string) => void;
	}

	let { items, currentFilter, onFilterChange }: Props = $props();

	// Extract unique sets from items
	let uniqueSets = $derived(
		Array.from(
			new Map(items.map((item) => [item.set, { code: item.set, name: item.set_name }])).values()
		).sort((a, b) => a.name.localeCompare(b.name))
	);

	let showDropdown = $state(false);
	let searchTerm = $state('');

	// Filter sets based on search term
	let filteredSets = $derived(
		uniqueSets.filter(
			(set) =>
				set.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
				set.code.toLowerCase().includes(searchTerm.toLowerCase())
		)
	);

	function selectSet(setCode: string) {
		onFilterChange(setCode);
		showDropdown = false;
		searchTerm = '';
	}

	function clearFilter() {
		onFilterChange('');
		searchTerm = '';
	}

	// Get the current set name for display
	let currentSetName = $derived(
		currentFilter ? uniqueSets.find((s) => s.code === currentFilter)?.name || currentFilter : ''
	);
</script>

<div class="filter-bar">
	<div class="filter-container">
		<button
			class="filter-button"
			onclick={() => (showDropdown = !showDropdown)}
			aria-label="Filter by set"
		>
			<Filter size={16} />
			{#if currentFilter}
				<span class="filter-label">{currentSetName}</span>
			{:else}
				<span class="filter-label">All Sets</span>
			{/if}
		</button>

		{#if currentFilter}
			<button class="clear-button" onclick={clearFilter} aria-label="Clear filter">
				<X size={16} />
			</button>
		{/if}

		{#if showDropdown}
			<div class="dropdown">
				<input
					type="text"
					class="search-input"
					placeholder="Search sets..."
					bind:value={searchTerm}
				/>
				<div class="set-list">
					<button class="set-option" onclick={() => selectSet('')}>
						<span class="set-name">All Sets</span>
					</button>
					{#each filteredSets as set}
						<button class="set-option" onclick={() => selectSet(set.code)}>
							<span class="set-code">{set.code.toUpperCase()}</span>
							<span class="set-name">{set.name}</span>
						</button>
					{/each}
					{#if filteredSets.length === 0}
						<div class="no-results">No matching sets found</div>
					{/if}
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	.filter-bar {
		margin-bottom: 1rem;
	}

	.filter-container {
		position: relative;
		display: inline-flex;
		gap: 0.5rem;
		align-items: center;
	}

	.filter-button {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.5rem 1rem;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		color: #374151;
		cursor: pointer;
		transition: all 0.2s;
	}

	.filter-button:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	:global(.dark) .filter-button {
		background: #374151;
		border-color: #4b5563;
		color: #e5e7eb;
	}

	:global(.dark) .filter-button:hover {
		background: #4b5563;
		border-color: #6b7280;
	}

	.filter-label {
		font-weight: 500;
	}

	.clear-button {
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
	}

	.clear-button:hover {
		background: #dc2626;
	}

	.dropdown {
		position: absolute;
		top: 100%;
		left: 0;
		margin-top: 0.5rem;
		width: 20rem;
		max-height: 24rem;
		background: white;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		box-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.1);
		z-index: 50;
		display: flex;
		flex-direction: column;
	}

	:global(.dark) .dropdown {
		background: #374151;
		border-color: #4b5563;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem;
		border: none;
		border-bottom: 1px solid #e5e7eb;
		font-size: 0.875rem;
		outline: none;
	}

	.search-input:focus {
		border-bottom-color: #3b82f6;
	}

	:global(.dark) .search-input {
		background: #1f2937;
		border-bottom-color: #4b5563;
		color: #e5e7eb;
	}

	:global(.dark) .search-input:focus {
		border-bottom-color: #60a5fa;
	}

	.set-list {
		overflow-y: auto;
		max-height: 18rem;
	}

	.set-option {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem;
		background: transparent;
		border: none;
		text-align: left;
		cursor: pointer;
		transition: background 0.2s;
	}

	.set-option:hover {
		background: #f3f4f6;
	}

	:global(.dark) .set-option:hover {
		background: #4b5563;
	}

	.set-code {
		font-weight: 600;
		font-size: 0.75rem;
		color: #6b7280;
		min-width: 3rem;
	}

	:global(.dark) .set-code {
		color: #9ca3af;
	}

	.set-name {
		font-size: 0.875rem;
		color: #111827;
		flex: 1;
	}

	:global(.dark) .set-name {
		color: #e5e7eb;
	}

	.no-results {
		padding: 1rem;
		text-align: center;
		color: #6b7280;
		font-size: 0.875rem;
	}

	:global(.dark) .no-results {
		color: #9ca3af;
	}
</style>
