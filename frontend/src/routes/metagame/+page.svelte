<script lang="ts">
	import { base } from '$app/paths';
	import { Wand2, Zap, Users } from 'lucide-svelte';

	interface Format {
		name: string;
		description: string;
		href: string;
		icon: typeof Wand2;
		available: boolean;
	}

	const formats: Format[] = [
		{
			name: 'Commander / EDH',
			description: 'Browse the top 20 EDH commanders from EDHREC with their complete decklists.',
			href: `${base}/metagame/edh`,
			icon: Users,
			available: true
		},
		{
			name: 'Modern',
			description: 'Explore competitive Modern metagame data and popular decklists.',
			href: `${base}/metagame/modern`,
			icon: Zap,
			available: false
		},
		{
			name: 'Standard',
			description: 'Stay up to date with the current Standard metagame and trending decks.',
			href: `${base}/metagame/standard`,
			icon: Wand2,
			available: false
		}
	];
</script>

<div class="container mx-auto px-4 py-8">
	<header class="mb-8">
		<h1 class="mb-4 h1">Metagame Browser</h1>
		<p class="text-surface-600-300-token text-lg">
			Explore competitive metagames across different Magic: The Gathering formats.
		</p>
	</header>

	<div class="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
		{#each formats as format}
			{@const Icon = format.icon}
			{#if format.available}
				<a
					href={format.href}
					class="variant-ghost-surface hover:variant-ghost-primary card transition-all"
				>
					<header class="card-header">
						<div class="flex items-center gap-3">
							<div class="variant-filled-primary rounded-lg p-3">
								<Icon size={24} />
							</div>
							<h2 class="h3">{format.name}</h2>
						</div>
					</header>
					<section class="p-4">
						<p class="text-surface-600-300-token">{format.description}</p>
					</section>
					<footer class="card-footer">
						<span class="text-primary-500 text-sm font-semibold">Browse format →</span>
					</footer>
				</a>
			{:else}
				<div class="variant-ghost card opacity-60">
					<header class="card-header">
						<div class="flex items-center gap-3">
							<div class="variant-soft-surface rounded-lg p-3">
								<Icon size={24} />
							</div>
							<h2 class="h3">{format.name}</h2>
						</div>
					</header>
					<section class="p-4">
						<p class="text-surface-600-300-token">{format.description}</p>
					</section>
					<footer class="card-footer">
						<span class="variant-soft-surface badge">Coming Soon</span>
					</footer>
				</div>
			{/if}
		{/each}
	</div>
</div>
