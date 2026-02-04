<script lang="ts">
	import { Dialog, Portal } from '@skeletonlabs/skeleton-svelte';
	import { X } from 'lucide-svelte';
	import type { Card } from '$lib/types/card';

	interface Props {
		open?: boolean;
		results?: Card[];
		searching?: boolean;
		hasSearched?: boolean;
		onCardSelect?: (card: Card) => void;
		onSearch?: (query: string) => void;
	}

	let {
		open = $bindable(false),
		results = [],
		searching = false,
		hasSearched = false,
		onCardSelect,
		onSearch
	}: Props = $props();

	let query = $state('');
	let inputElement = $state<HTMLInputElement | null>(null);

	/**
	 * Auto-focuses the search input when the drawer opens.
	 * Uses a short delay to ensure the drawer is fully rendered before focusing.
	 */
	$effect(() => {
		if (open && inputElement) {
			setTimeout(() => {
				inputElement?.focus();
			}, 100);
		}
	});

	/**
	 * Handles search form submission.
	 * Prevents default form behavior and triggers the parent's search handler.
	 * @param event - The form submit event
	 */
	function handleSearch(event: Event) {
		event.preventDefault();
		if (onSearch && query.trim()) {
			onSearch(query.trim());
		}
	}

	/**
	 * Handles card selection from the results list.
	 * @param card - The selected card
	 */
	function selectCard(card: Card) {
		if (onCardSelect) {
			onCardSelect(card);
		}
	}
</script>

<Dialog
	{open}
	onOpenChange={(details) => {
		open = details.open;
	}}
	closeOnEscape={true}
	trapFocus={true}
	closeOnInteractOutside={true}
>
	<Portal>
		<Dialog.Backdrop
			class="data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-50 bg-black/50 transition-opacity"
		/>
		<Dialog.Positioner class="fixed inset-0 z-50 flex justify-end">
			<Dialog.Content
				class="drawer-container data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:slide-out-to-right data-[state=open]:slide-in-from-right flex h-screen w-full flex-col bg-white shadow-xl transition-transform md:w-96 dark:bg-gray-800"
				data-testid="search-drawer"
				role="dialog"
				aria-label="Search cards"
			>
				<div class="drawer-header">
					<Dialog.Title class="text-xl font-bold text-gray-900 dark:text-gray-100"
						>Search Cards</Dialog.Title
					>
					<Dialog.CloseTrigger
						class="rounded-md p-2 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-100"
						aria-label="Close search drawer"
					>
						<X class="h-5 w-5" />
					</Dialog.CloseTrigger>
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
					<button
						type="submit"
						class="search-button"
						aria-label="Search for cards"
						disabled={!query.trim()}>Search</button
					>
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
										onkeydown={(e) => {
											if (e.key === 'Enter' || e.key === ' ') {
												e.preventDefault();
												selectCard(card);
											}
										}}
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
			</Dialog.Content>
		</Dialog.Positioner>
	</Portal>
</Dialog>

<style>
	.drawer-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
	}

	.search-form {
		padding: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.search-button {
		padding: 0.625rem 1rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-weight: 500;
		cursor: pointer;
		transition: background 0.2s;
	}

	.search-button:hover:not(:disabled) {
		background: #2563eb;
	}

	.search-button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.results-container {
		padding: 1rem;
		overflow-y: auto;
		flex: 1;
		min-height: 0; /* Ensure flex child can shrink */
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
