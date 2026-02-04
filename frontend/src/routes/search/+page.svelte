<script lang="ts">
	import { base } from '$app/paths';
	import PrintingModal from '$lib/components/PrintingModal.svelte';
	import { Search } from 'lucide-svelte';
	// API requests use the base path and are proxied by hooks.server.ts
	const API_BASE = base;

	interface CardType {
		id: string;
		name: string;
		mana_cost?: string;
	}

	let query = $state('');
	let results: CardType[] = $state([]);
	let searching = $state(false);
	let hasSearched = $state(false);
	let selectedCard: CardType | null = $state(null);
	let modalOpen = $state(false);

	// Derived state to ensure button reactivity
	let isButtonDisabled = $derived(searching || !query.trim());

	async function handleSearch() {
		if (!query.trim()) return;
		searching = true;
		hasSearched = true;
		try {
			const res = await fetch(`${API_BASE}/api/cards/search?q=${encodeURIComponent(query)}`);
			const data = await res.json();
			results = data.cards || [];
		} catch {
			results = [];
		} finally {
			searching = false;
		}
	}

	function openPrintingsModal(card: CardType) {
		selectedCard = card;
		modalOpen = true;
	}

	function closePrintingsModal() {
		modalOpen = false;
		selectedCard = null;
	}
</script>

<div class="search-page">
	<div class="search-card">
		<h1 class="page-title">Card Search</h1>
		<p class="page-description">Search for Magic: The Gathering cards to add to your inventory</p>

		<form onsubmit={handleSearch} class="search-form">
			<div class="search-input-wrapper">
				<Search class="search-icon h-5 w-5" />
				<input
					type="text"
					bind:value={query}
					placeholder="Enter card name..."
					class="search-input"
					aria-label="Search for cards"
				/>
			</div>
			<button type="submit" disabled={isButtonDisabled} class="search-button">
				{searching ? 'Searching...' : 'Search'}
			</button>
		</form>
	</div>

	{#if searching}
		<div class="search-state">
			<div class="spinner"></div>
			<p>Searching...</p>
		</div>
	{:else if hasSearched && results.length === 0}
		<div class="search-state-card">
			<p class="no-results">No cards found. Try a different search term.</p>
		</div>
	{:else if results.length > 0}
		<div class="results-grid">
			{#each results as card (card.id)}
				<div class="result-card">
					<button class="result-button" onclick={() => openPrintingsModal(card)}>
						<h3 class="card-name">{card.name}</h3>
						{#if card.mana_cost}
							<span class="mana-cost">{card.mana_cost}</span>
						{/if}
					</button>
				</div>
			{/each}
		</div>
	{/if}
</div>

{#if selectedCard}
	<PrintingModal card={selectedCard} bind:open={modalOpen} onclose={closePrintingsModal} />
{/if}

<style>
	.search-page {
		max-width: 1200px;
		margin: 0 auto;
		padding: 2rem 1rem;
	}

	.search-card {
		background: white;
		border-radius: 0.5rem;
		padding: 1.5rem;
		box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
		margin-bottom: 2rem;
	}

	.page-title {
		font-size: 2rem;
		font-weight: 700;
		color: #111827;
		margin: 0 0 0.5rem;
	}

	.page-description {
		color: #6b7280;
		margin: 0 0 1.5rem;
	}

	.search-form {
		display: flex;
		gap: 0.75rem;
		align-items: flex-start;
	}

	.search-input-wrapper {
		position: relative;
		flex: 1;
	}

	.search-input-wrapper :global(.search-icon) {
		position: absolute;
		left: 1rem;
		top: 50%;
		transform: translateY(-50%);
		color: #6b7280;
		pointer-events: none;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 1rem 0.75rem 2.75rem;
		border: 1px solid #d1d5db;
		border-radius: 0.5rem;
		font-size: 1rem;
		background: #f9fafb;
		color: #111827;
		transition: all 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: #3b82f6;
		background: white;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.search-button {
		padding: 0.75rem 1.5rem;
		background: #3b82f6;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s;
		white-space: nowrap;
	}

	.search-button:hover:not(:disabled) {
		background: #2563eb;
	}

	.search-button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.search-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid #e5e7eb;
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

	.search-state p {
		color: #6b7280;
	}

	.search-state-card {
		background: white;
		border-radius: 0.5rem;
		padding: 2rem;
		box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
		text-align: center;
	}

	.no-results {
		color: #6b7280;
		margin: 0;
	}

	.results-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
		gap: 1rem;
	}

	.result-card {
		background: white;
		border-radius: 0.5rem;
		padding: 1.25rem;
		box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
		transition: all 0.2s;
		cursor: pointer;
	}

	.result-card:hover {
		box-shadow:
			0 4px 6px -1px rgb(0 0 0 / 0.1),
			0 2px 4px -2px rgb(0 0 0 / 0.1);
		transform: translateY(-2px);
	}

	.result-button {
		width: 100%;
		text-align: left;
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
	}

	.card-name {
		font-size: 1.125rem;
		font-weight: 600;
		color: #111827;
		margin: 0 0 0.5rem;
	}

	.mana-cost {
		font-size: 0.875rem;
		color: #6b7280;
		font-family: monospace;
	}

	:global(.dark) .search-card,
	:global(.dark) .search-state-card,
	:global(.dark) .result-card {
		background: #1f2937;
	}

	:global(.dark) .page-title {
		color: #e5e7eb;
	}

	:global(.dark) .page-description {
		color: #9ca3af;
	}

	:global(.dark) .search-input {
		background: #374151;
		border-color: #4b5563;
		color: #e5e7eb;
	}

	:global(.dark) .search-input:focus {
		background: #1f2937;
		border-color: #3b82f6;
	}

	:global(.dark) .card-name {
		color: #e5e7eb;
	}

	@media (max-width: 768px) {
		.search-form {
			flex-direction: column;
		}

		.search-button {
			width: 100%;
		}

		.results-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
