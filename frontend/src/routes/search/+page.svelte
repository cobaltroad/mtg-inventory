<script lang="ts">
	import { base } from '$app/paths';
	import PrintingModal from '$lib/components/PrintingModal.svelte';
	// API requests use the base path and are proxied by hooks.server.ts
	const API_BASE = base;

	interface Card {
		id: string;
		name: string;
		mana_cost?: string;
	}

	let query = $state('');
	let results: Card[] = $state([]);
	let searching = $state(false);
	let selectedCard: Card | null = $state(null);
	let modalOpen = $state(false);

	async function handleSearch() {
		if (!query.trim()) return;
		searching = true;
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

	function openPrintingsModal(card: Card) {
		selectedCard = card;
		modalOpen = true;
	}

	function closePrintingsModal() {
		modalOpen = false;
		selectedCard = null;
	}
</script>

<h1>Card Search</h1>

<div class="search-form">
	<input
		type="text"
		bind:value={query}
		placeholder="Search for a card..."
		onkeydown={(e) => {
			if (e.key === 'Enter') handleSearch();
		}}
	/>
	<button onclick={handleSearch} disabled={searching}>Search</button>
</div>

{#if searching}
	<p>Searching...</p>
{/if}

{#if results.length > 0}
	<ul class="results">
		{#each results as card (card.id)}
			<li class="result-row">
				<button class="card-name-button" onclick={() => openPrintingsModal(card)}>
					{card.name}
				</button>
				{#if card.mana_cost}
					<span class="mana-cost">{card.mana_cost}</span>
				{/if}
			</li>
		{/each}
	</ul>
{/if}

{#if selectedCard}
	<PrintingModal card={selectedCard} bind:open={modalOpen} onclose={closePrintingsModal} />
{/if}

<style>
	.search-form {
		display: flex;
		gap: 0.5rem;
		margin: 1rem 0;
	}

	.search-form input {
		flex: 1;
		padding: 0.5rem 0.75rem;
		border: 1px solid #ccc;
		border-radius: 4px;
		font-size: 1rem;
	}

	.search-form button {
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 4px;
		background: #3b82f6;
		color: white;
		cursor: pointer;
		font-size: 1rem;
	}

	.search-form button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.results {
		list-style: none;
		padding: 0;
		margin: 1rem 0;
	}

	.result-row {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.6rem 0.75rem;
		border-bottom: 1px solid #eee;
	}

	.card-name-button {
		font-weight: 600;
		flex: 1;
		text-align: left;
		background: none;
		border: none;
		padding: 0;
		color: #3b82f6;
		cursor: pointer;
		font-size: 1rem;
		transition: color 0.2s;
	}

	.card-name-button:hover {
		color: #1d4ed8;
		text-decoration: underline;
	}

	.mana-cost {
		color: #666;
		font-size: 0.875rem;
	}
</style>
