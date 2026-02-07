<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { fetchCommanders, type Commander } from '$lib/services/commanderService';
	import { formatRelativeTime } from '$lib/utils/format';

	let commanders = $state<Commander[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);

	async function loadCommanders() {
		loading = true;
		error = null;

		try {
			commanders = await fetchCommanders();
		} catch (err) {
			console.error('Error fetching commanders:', err);
			error = 'Failed to load commanders. Please try again.';
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		loadCommanders();
	});

	function handleCommanderClick(id: number) {
		goto(`${base}/metagame/edh/${id}`);
	}
</script>

<div class="container mx-auto px-4 py-8">
	<h1 class="mb-8 h1">Top EDH Commanders</h1>

	{#if loading}
		<div class="py-12 text-center">
			<p class="text-lg">Loading commanders...</p>
		</div>
	{:else if error}
		<div class="variant-ghost-error card p-6">
			<p class="mb-4">{error}</p>
			<button class="variant-filled-primary btn" onclick={() => loadCommanders()}> Retry </button>
		</div>
	{:else if commanders.length === 0}
		<div class="variant-ghost card p-8 text-center">
			<h2 class="mb-4 h2">No commanders available yet</h2>
			<p class="mb-2">Check back after the next scrape!</p>
			<p class="text-surface-600-300-token text-sm">
				Commander data is updated weekly on Saturdays.
			</p>
		</div>
	{:else}
		<div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
			{#each commanders as commander (commander.id)}
				<article class="variant-ghost-surface hover:variant-ghost-primary card transition-all">
					<button
						class="w-full cursor-pointer text-left"
						onclick={() => handleCommanderClick(commander.id)}
					>
						<header class="card-header">
							<div class="flex items-start justify-between gap-2">
								<h3 class="flex-1 h3">{commander.name}</h3>
								<span class="variant-filled-primary badge">#{commander.rank}</span>
							</div>
						</header>
						<section class="p-4">
							<p class="mb-2 text-sm">
								<strong>{commander.card_count}</strong>
								{commander.card_count === 1 ? 'card' : 'cards'}
							</p>
							<p class="text-surface-600-300-token text-xs">
								Updated {formatRelativeTime(commander.last_scraped_at)}
							</p>
						</section>
					</button>
				</article>
			{/each}
		</div>
	{/if}
</div>
