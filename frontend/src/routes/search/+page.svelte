<script lang="ts">
	import { base } from '$app/paths';
	import PrintingModal from '$lib/components/PrintingModal.svelte';
	import { Button, Card, Input } from 'flowbite-svelte';
	import { SearchOutline } from 'flowbite-svelte-icons';
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
	<Card class="search-card">
		<h1 class="page-title">Card Search</h1>
		<p class="page-description">Search for Magic: The Gathering cards to add to your inventory</p>

		<form onsubmit={handleSearch} class="search-form">
			<Input
				type="text"
				bind:value={query}
				placeholder="Enter card name..."
				size="lg"
				class="search-input"
			>
				<SearchOutline slot="left" class="h-5 w-5" />
			</Input>
			<Button type="submit" disabled={searching || !query.trim()} size="lg">
				{searching ? 'Searching...' : 'Search'}
			</Button>
		</form>
	</Card>

	{#if searching}
		<div class="search-state">
			<div class="spinner"></div>
			<p>Searching...</p>
		</div>
	{:else if hasSearched && results.length === 0}
		<Card class="search-state-card">
			<p class="no-results">No cards found. Try a different search term.</p>
		</Card>
	{:else if results.length > 0}
		<div class="results-grid">
			{#each results as card (card.id)}
				<Card hoverable class="result-card">
					<button class="result-button" onclick={() => openPrintingsModal(card)}>
						<h3 class="card-name">{card.name}</h3>
						{#if card.mana_cost}
							<span class="mana-cost">{card.mana_cost}</span>
						{/if}
					</button>
				</Card>
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

	.search-page :global(.search-card) {
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

	:global(.search-input) {
		flex: 1;
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

	.search-page :global(.search-state-card) {
		padding: 2rem;
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

	.results-grid :global(.result-card) {
		cursor: pointer;
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

	:global(.dark) .page-title {
		color: #e5e7eb;
	}

	:global(.dark) .page-description {
		color: #9ca3af;
	}

	:global(.dark) .card-name {
		color: #e5e7eb;
	}

	@media (max-width: 768px) {
		.search-form {
			flex-direction: column;
		}

		.results-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
