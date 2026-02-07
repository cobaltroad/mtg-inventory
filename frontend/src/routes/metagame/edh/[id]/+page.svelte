<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { base } from '$app/paths';
	import { fetchCommander, type CommanderWithDecklist } from '$lib/services/commanderService';
	import { ExternalLink } from 'lucide-svelte';

	let commander = $state<CommanderWithDecklist | null>(null);
	let loading = $state(true);
	let error = $state<string | null>(null);

	async function loadCommander(id: string) {
		loading = true;
		error = null;

		try {
			commander = await fetchCommander(id);
		} catch (err) {
			console.error('Error fetching commander:', err);
			error = err instanceof Error ? err.message : 'Failed to load commander. Please try again.';
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		const id = $page.params.id;
		loadCommander(id);
	});

	// Sort cards alphabetically by name
	let sortedCards = $derived(
		commander?.cards
			? [...commander.cards].sort((a, b) => a.card_name.localeCompare(b.card_name))
			: []
	);
</script>

<div class="container mx-auto px-4 py-8">
	{#if loading}
		<div class="py-12 text-center">
			<p class="text-lg">Loading commander...</p>
		</div>
	{:else if error}
		<div class="variant-ghost-error card p-6">
			<p class="mb-4">{error}</p>
			<a href="{base}/metagame/edh" class="variant-filled-primary btn"> Back to Commanders </a>
		</div>
	{:else if commander}
		<div class="mb-6">
			<a href="{base}/metagame/edh" class="mb-4 inline-block text-sm text-primary-500 hover:underline">
				&larr; Back to Commanders
			</a>
		</div>

		<header class="mb-8">
			<div class="mb-4 flex items-start justify-between gap-4">
				<h1 class="flex-1 h1">{commander.name}</h1>
				<span class="variant-filled-primary badge px-4 py-2 text-lg">#{commander.rank}</span>
			</div>
			<div class="flex items-center gap-4">
				<a
					href={commander.edhrec_url}
					target="_blank"
					rel="noopener noreferrer"
					class="variant-ghost-surface btn"
				>
					<ExternalLink size={16} />
					View on EDHREC
				</a>
				<p class="text-surface-600-300-token text-sm">
					{commander.card_count}
					{commander.card_count === 1 ? 'card' : 'cards'}
				</p>
			</div>
		</header>

		{#if sortedCards.length === 0}
			<div class="variant-ghost card p-8 text-center">
				<p class="text-lg">No cards in this decklist yet.</p>
			</div>
		{:else}
			<section>
				<h2 class="mb-4 h2">Decklist ({sortedCards.length} cards)</h2>
				<div class="variant-ghost-surface card">
					<div class="p-4">
						<ul class="grid grid-cols-1 gap-1 md:grid-cols-2 lg:grid-cols-3">
							{#each sortedCards as card (card.card_id)}
								<li
									class="hover:bg-surface-hover-token flex items-center gap-2 rounded px-3 py-2 transition-colors"
								>
									{#if card.quantity > 1}
										<span
											class="text-surface-600-300-token min-w-[3ch] shrink-0 text-sm font-semibold"
										>
											{card.quantity}x
										</span>
									{/if}
									{#if card.card_url}
										<a
											href={card.card_url}
											target="_blank"
											rel="noopener noreferrer"
											class="flex min-w-0 flex-1 items-center gap-1 text-primary-500 hover:underline"
											title="View {card.card_name} on Scryfall"
										>
											<span class="truncate">{card.card_name}</span>
											<ExternalLink size={12} class="shrink-0" />
										</a>
									{:else}
										<span class="flex-1 truncate">{card.card_name}</span>
									{/if}
								</li>
							{/each}
						</ul>
					</div>
				</div>
			</section>
		{/if}
	{/if}
</div>
