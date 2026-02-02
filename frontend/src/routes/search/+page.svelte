<script lang="ts">
	import { base } from '$app/paths';
	const API_BASE = import.meta.env.VITE_API_URL || base;

	interface Card {
		id: string;
		name: string;
		mana_cost?: string;
	}

	type AddState = 'idle' | 'loading' | 'success' | 'error';

	let query = $state('');
	let results: Card[] = $state([]);
	let searching = $state(false);
	let cardStates: Map<string, { state: AddState; quantity: number }> = $state(new Map());

	async function handleSearch() {
		if (!query.trim()) return;
		searching = true;
		try {
			const res = await fetch(`${API_BASE}/api/cards/search?q=${encodeURIComponent(query)}`);
			const data = await res.json();
			results = data.cards || [];
			cardStates = new Map();
		} catch {
			results = [];
		} finally {
			searching = false;
		}
	}

	function getCardState(cardId: string): { state: AddState; quantity: number } {
		return cardStates.get(cardId) || { state: 'idle', quantity: 0 };
	}

	async function addToInventory(cardId: string) {
		cardStates = new Map(cardStates).set(cardId, { state: 'loading', quantity: 0 });
		try {
			const res = await fetch(`${API_BASE}/api/inventory`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ card_id: cardId, quantity: 1 })
			});
			if (!res.ok) {
				cardStates = new Map(cardStates).set(cardId, { state: 'error', quantity: 0 });
				return;
			}
			const data = await res.json();
			cardStates = new Map(cardStates).set(cardId, { state: 'success', quantity: data.quantity });
		} catch {
			cardStates = new Map(cardStates).set(cardId, { state: 'error', quantity: 0 });
		}
	}
</script>

<h1>Card Search</h1>

<div class="search-form">
	<input type="text" bind:value={query} placeholder="Search for a card..." onkeydown={(e) => { if (e.key === 'Enter') handleSearch(); }} />
	<button onclick={handleSearch} disabled={searching}>Search</button>
</div>

{#if searching}
	<p>Searching...</p>
{/if}

{#if results.length > 0}
	<ul class="results">
		{#each results as card}
			{@const cs = getCardState(card.id)}
			<li class="result-row">
				<span class="card-name">{card.name}</span>
				{#if card.mana_cost}
					<span class="mana-cost">{card.mana_cost}</span>
				{/if}
				<span class="card-action">
					{#if cs.state === 'success'}
						<span class="confirmation">In Inventory: {cs.quantity}</span>
					{:else if cs.state === 'error'}
						<span class="error-msg">Something went wrong. Try again.</span>
						<button onclick={() => addToInventory(card.id)}>Add to Inventory</button>
					{:else}
						<button onclick={() => addToInventory(card.id)} disabled={cs.state === 'loading'}>
							{cs.state === 'loading' ? 'Adding...' : 'Add to Inventory'}
						</button>
					{/if}
				</span>
			</li>
		{/each}
	</ul>
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

	.card-name {
		font-weight: 600;
		flex: 1;
	}

	.mana-cost {
		color: #666;
		font-size: 0.875rem;
	}

	.card-action button {
		padding: 0.35rem 0.75rem;
		border: 1px solid #3b82f6;
		border-radius: 4px;
		background: white;
		color: #3b82f6;
		cursor: pointer;
		font-size: 0.875rem;
	}

	.card-action button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.confirmation {
		color: #16a34a;
		font-weight: 600;
		font-size: 0.875rem;
	}

	.error-msg {
		color: #dc2626;
		font-size: 0.875rem;
		margin-right: 0.5rem;
	}
</style>
