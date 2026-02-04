<script lang="ts">
	import { Drawer, CloseButton, Button, Input } from 'flowbite-svelte';
	import { SearchOutline } from 'flowbite-svelte-icons';

	interface Card {
		id: string;
		name: string;
		mana_cost?: string;
	}

	interface Props {
		open?: boolean;
		results?: Card[];
		searching?: boolean;
		hasSearched?: boolean;
		onCardSelect?: (card: Card) => void;
	}

	let {
		open = $bindable(false),
		results = [],
		searching = false,
		hasSearched = false,
		onCardSelect
	}: Props = $props();

	let query = $state('');
	let inputElement = $state<HTMLInputElement | null>(null);

	// Auto-focus search input when drawer opens
	$effect(() => {
		if (open && inputElement) {
			// Use setTimeout to ensure the drawer is fully rendered before focusing
			setTimeout(() => {
				inputElement?.focus();
			}, 100);
		}
	});

	function handleClose() {
		open = false;
	}

	function handleKeyDown(event: KeyboardEvent) {
		if (event.key === 'Escape') {
			handleClose();
		}
	}

	function handleSearch(event: Event) {
		event.preventDefault();
		// This would trigger search in parent component
		// For testing purposes, we just need the form to be submittable
	}

	function selectCard(card: Card) {
		if (onCardSelect) {
			onCardSelect(card);
		}
	}
</script>

<Drawer
	bind:open
	transitionType="fly"
	placement="right"
	width="w-full md:w-96"
	class="drawer-container"
	data-testid="search-drawer"
	role="dialog"
	aria-label="Search cards"
	onkeydown={handleKeyDown}
>
	<div class="drawer-header">
		<h3 class="drawer-title">Search Cards</h3>
		<CloseButton on:click={handleClose} aria-label="Close search drawer" />
	</div>

	<form onsubmit={handleSearch} class="search-form">
		<input
			type="text"
			bind:value={query}
			bind:this={inputElement}
			placeholder="Enter card name..."
			aria-label="Search for cards"
			class="search-input block w-full rounded-lg border border-gray-300 bg-gray-50 p-2.5 text-sm text-gray-900 focus:border-blue-500 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400 dark:focus:border-blue-500 dark:focus:ring-blue-500"
		/>
		<Button type="submit" aria-label="Search for cards" disabled={!query.trim()}>Search</Button>
	</form>

	<div class="results-container">
		{#if searching}
			<div class="search-state">
				<div class="spinner"></div>
				<p>Searching...</p>
			</div>
		{:else if hasSearched && results.length === 0}
			<div class="search-state">
				<p>No results found</p>
			</div>
		{:else if results.length > 0}
			<ul class="results-list">
				{#each results as card (card.id)}
					<li>
						<button
							type="button"
							class="result-item"
							data-card-id={card.id}
							onclick={() => selectCard(card)}
						>
							<span class="card-name">{card.name}</span>
							{#if card.mana_cost}
								<span class="mana-cost">{card.mana_cost}</span>
							{/if}
						</button>
					</li>
				{/each}
			</ul>
		{/if}
	</div>
</Drawer>

<style>
	.drawer-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.drawer-title {
		font-size: 1.25rem;
		font-weight: 700;
		margin: 0;
		color: #111827;
	}

	.search-form {
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.results-container {
		padding: 1rem;
		overflow-y: auto;
		flex: 1;
	}

	.search-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
		text-align: center;
		color: #6b7280;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #e5e7eb;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.results-list {
		list-style: none;
		padding: 0;
		margin: 0;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.result-item {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		background: white;
		border: 1px solid #e5e7eb;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: all 0.2s;
		text-align: left;
	}

	.result-item:hover {
		background: #f9fafb;
		border-color: #3b82f6;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.card-name {
		flex: 1;
		font-weight: 600;
		color: #111827;
	}

	.mana-cost {
		font-size: 0.875rem;
		color: #6b7280;
		font-family: monospace;
	}

	:global(.dark) .drawer-header {
		border-bottom-color: #374151;
	}

	:global(.dark) .drawer-title {
		color: #e5e7eb;
	}

	:global(.dark) .result-item {
		background: #1f2937;
		border-color: #374151;
	}

	:global(.dark) .result-item:hover {
		background: #374151;
		border-color: #3b82f6;
	}

	:global(.dark) .card-name {
		color: #e5e7eb;
	}
</style>
