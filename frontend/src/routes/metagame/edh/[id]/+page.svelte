<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { base } from '$app/paths';
	import { fetchCommander, type CommanderWithDecklist } from '$lib/services/commanderService';
	import { sortDecklistCards, type SortOption } from '$lib/utils/decklistSorting';
	import {
		filterDecklistCards,
		getUniqueCardTypes,
		getUniqueRarities,
		type FilterOptions
	} from '$lib/utils/decklistFiltering';
	import { ExternalLink, Crown, SlidersHorizontal, X } from 'lucide-svelte';

	let commander = $state<CommanderWithDecklist | null>(null);
	let loading = $state(true);
	let error = $state<string | null>(null);

	// Sort and filter state
	let sortBy = $state<SortOption>('alphabetical');
	let filterOptions = $state<FilterOptions>({});
	let showFilters = $state(false);

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
		if (id) {
			loadCommander(id);
		}
	});

	// Get unique types and rarities for filter dropdowns
	let availableTypes = $derived(commander?.cards ? getUniqueCardTypes(commander.cards) : []);
	let availableRarities = $derived(
		commander?.cards ? getUniqueRarities(commander.cards) : []
	);

	// Apply sorting and filtering
	let processedCards = $derived.by(() => {
		if (!commander?.cards) return [];

		// First filter, then sort
		const filtered = filterDecklistCards(commander.cards, filterOptions);
		return sortDecklistCards(filtered, sortBy);
	});

	// Check if any filters are active
	let hasActiveFilters = $derived(
		(filterOptions.cardTypes && filterOptions.cardTypes.length > 0) ||
			(filterOptions.rarities && filterOptions.rarities.length > 0) ||
			filterOptions.hideBasicLands ||
			filterOptions.minPrice !== undefined ||
			filterOptions.maxPrice !== undefined
	);

	// Reset all filters
	function resetFilters() {
		filterOptions = {};
	}

	// Toggle card type filter
	function toggleCardType(type: string) {
		const current = filterOptions.cardTypes || [];
		if (current.includes(type)) {
			filterOptions = {
				...filterOptions,
				cardTypes: current.filter((t) => t !== type)
			};
		} else {
			filterOptions = {
				...filterOptions,
				cardTypes: [...current, type]
			};
		}
	}

	// Toggle rarity filter
	function toggleRarity(rarity: string) {
		const current = filterOptions.rarities || [];
		if (current.includes(rarity)) {
			filterOptions = {
				...filterOptions,
				rarities: current.filter((r) => r !== rarity)
			};
		} else {
			filterOptions = {
				...filterOptions,
				rarities: [...current, rarity]
			};
		}
	}
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
			<a
				href="{base}/metagame/edh"
				class="mb-4 inline-block text-sm text-primary-500 hover:underline"
			>
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

		{#if !commander.cards || commander.cards.length === 0}
			<div class="variant-ghost card p-8 text-center">
				<p class="text-lg">No cards in this decklist yet.</p>
			</div>
		{:else}
			<section>
				<!-- Controls header -->
				<div class="mb-4 flex flex-wrap items-center justify-between gap-4">
					<h2 class="h2">
						Decklist ({processedCards.length}
						{processedCards.length === 1 ? 'card' : 'cards'})
					</h2>

					<div class="flex flex-wrap items-center gap-3">
						<!-- Sort dropdown -->
						<label class="flex items-center gap-2">
							<span class="text-sm font-semibold">Sort:</span>
							<select bind:value={sortBy} class="select variant-form-material w-auto">
								<option value="alphabetical">A-Z</option>
								<option value="value">$ Value</option>
								<option value="edh-rank">EDH Rank</option>
								<option value="release-date">Newest</option>
								<option value="type">Type</option>
								<option value="rarity">Rarity</option>
							</select>
						</label>

						<!-- Filter toggle button -->
						<button
							type="button"
							onclick={() => (showFilters = !showFilters)}
							class="btn {showFilters ? 'variant-filled-primary' : 'variant-ghost-surface'}"
							class:variant-filled-warning={hasActiveFilters && !showFilters}
						>
							<SlidersHorizontal size={16} />
							{hasActiveFilters ? `Filters (${Object.keys(filterOptions).length})` : 'Filters'}
						</button>

						<!-- Reset filters button -->
						{#if hasActiveFilters}
							<button
								type="button"
								onclick={resetFilters}
								class="btn variant-ghost-error"
								title="Clear all filters"
							>
								<X size={16} />
								Clear
							</button>
						{/if}
					</div>
				</div>

				<!-- Filter panel (collapsible) -->
				{#if showFilters}
					<div class="variant-ghost-surface card mb-4 p-4">
						<div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
							<!-- Card Type Filter -->
							<div>
								<h3 class="mb-2 text-sm font-semibold">Card Type</h3>
								<div class="flex flex-wrap gap-2">
									{#each availableTypes as type}
										<button
											type="button"
											onclick={() => toggleCardType(type)}
											class="chip {filterOptions.cardTypes?.includes(type)
												? 'variant-filled-primary'
												: 'variant-soft-surface'}"
										>
											{type}
										</button>
									{/each}
								</div>
							</div>

							<!-- Rarity Filter -->
							<div>
								<h3 class="mb-2 text-sm font-semibold">Rarity</h3>
								<div class="flex flex-wrap gap-2">
									{#each availableRarities as rarity}
										<button
											type="button"
											onclick={() => toggleRarity(rarity)}
											class="chip capitalize {filterOptions.rarities?.includes(rarity)
												? 'variant-filled-primary'
												: 'variant-soft-surface'}"
										>
											{rarity}
										</button>
									{/each}
								</div>
							</div>

							<!-- Basic Lands Toggle -->
							<div>
								<h3 class="mb-2 text-sm font-semibold">Options</h3>
								<label class="flex items-center gap-2">
									<input
										type="checkbox"
										class="checkbox"
										bind:checked={filterOptions.hideBasicLands}
									/>
									<span class="text-sm">Hide Basic Lands</span>
								</label>
							</div>

							<!-- Price Range Filter -->
							<div class="md:col-span-2">
								<h3 class="mb-2 text-sm font-semibold">Price Range (USD)</h3>
								<div class="flex flex-wrap items-center gap-3">
									<label class="flex items-center gap-2">
										<span class="text-sm">Min:</span>
										<input
											type="number"
											step="0.01"
											min="0"
											placeholder="0.00"
											bind:value={filterOptions.minPrice}
											class="input variant-form-material w-24"
										/>
									</label>
									<label class="flex items-center gap-2">
										<span class="text-sm">Max:</span>
										<input
											type="number"
											step="0.01"
											min="0"
											placeholder="100.00"
											bind:value={filterOptions.maxPrice}
											class="input variant-form-material w-24"
										/>
									</label>
								</div>
							</div>
						</div>
					</div>
				{/if}

				<!-- Card list -->
				<div class="variant-ghost-surface card">
					<div class="p-4">
						<ul class="grid grid-cols-1 gap-1 md:grid-cols-2 lg:grid-cols-3">
							{#each processedCards as card (card.card_id)}
								<li
									class="hover:bg-surface-hover-token flex items-center gap-2 rounded px-3 py-2 transition-colors {card.is_commander
										? 'variant-soft-primary font-semibold'
										: ''}"
								>
									<!-- Commander crown icon -->
									{#if card.is_commander}
										<Crown size={16} class="shrink-0 text-warning-500" />
									{/if}

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

									<!-- Show price if available -->
									{#if card.usd_price}
										<span class="text-surface-600-300-token shrink-0 text-xs">
											${card.usd_price}
										</span>
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
