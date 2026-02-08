<script lang="ts">
	import { base } from '$app/paths';
	import type { DecklistResult } from '$lib/types/search';

	interface Props {
		result: DecklistResult;
	}

	let { result }: Props = $props();

	// Compute the URL for the commander detail page
	const commanderUrl = $derived(`${base}/metagame/edh/${result.commander_id}`);

	// Determine which matches to display
	const displayedMatches = $derived(result.card_matches.slice(0, 4));
	const hasMoreMatches = $derived(result.card_matches.length > 4);
	const moreMatchesCount = $derived(result.card_matches.length - 4);

	// Determine singular/plural for match count
	const matchLabel = $derived(result.match_count === 1 ? 'match' : 'matches');
</script>

<article class="decklist-result">
	<div class="commander-info">
		<h3>
			<a href={commanderUrl}>{result.commander_name}</a>
		</h3>
		<div class="commander-meta">
			<span class="rank">Rank #{result.commander_rank}</span>
			<span class="match-count">{result.match_count} {matchLabel}</span>
		</div>
	</div>

	<div class="card-matches">
		<span class="matches-label">Contains:</span>
		<ul class="matches-list">
			{#each displayedMatches as match}
				<li class="match-item">
					{match.card_name} ({match.quantity}x)
				</li>
			{/each}
		</ul>
		{#if hasMoreMatches}
			<span class="more-matches">+{moreMatchesCount} more</span>
		{/if}
	</div>

	<div class="actions">
		<a href={commanderUrl} class="view-link">View Decklist →</a>
	</div>
</article>

<style>
	.decklist-result {
		padding: 1.5rem;
		background: white;
		border: 1px solid rgb(229 231 235);
		border-radius: 0.5rem;
		transition: all 0.2s;
	}

	.decklist-result:hover {
		border-color: rgb(59 130 246);
		box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
	}

	:global(.dark) .decklist-result {
		background: rgb(31 41 55);
		border-color: rgb(55 65 81);
	}

	:global(.dark) .decklist-result:hover {
		border-color: rgb(96 165 250);
	}

	.commander-info {
		margin-bottom: 1rem;
	}

	.commander-info h3 {
		margin: 0 0 0.5rem 0;
		font-size: 1.25rem;
		font-weight: 700;
		color: rgb(17 24 39);
	}

	:global(.dark) .commander-info h3 {
		color: rgb(229 231 235);
	}

	.commander-info h3 a {
		color: rgb(59 130 246);
		text-decoration: none;
		transition: color 0.2s;
	}

	.commander-info h3 a:hover {
		color: rgb(37 99 235);
		text-decoration: underline;
	}

	:global(.dark) .commander-info h3 a {
		color: rgb(96 165 250);
	}

	:global(.dark) .commander-info h3 a:hover {
		color: rgb(147 197 253);
	}

	.commander-meta {
		display: flex;
		gap: 1rem;
		font-size: 0.875rem;
		color: rgb(107 114 128);
	}

	:global(.dark) .commander-meta {
		color: rgb(156 163 175);
	}

	.rank {
		font-weight: 600;
	}

	.card-matches {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 1rem;
		font-size: 0.875rem;
		color: rgb(55 65 81);
	}

	:global(.dark) .card-matches {
		color: rgb(209 213 219);
	}

	.matches-label {
		font-weight: 600;
		color: rgb(107 114 128);
	}

	:global(.dark) .matches-label {
		color: rgb(156 163 175);
	}

	.matches-list {
		display: flex;
		flex-wrap: wrap;
		gap: 0.5rem;
		list-style: none;
		margin: 0;
		padding: 0;
	}

	.match-item {
		padding: 0.25rem 0.75rem;
		background: rgb(239 246 255);
		color: rgb(30 64 175);
		border-radius: 1rem;
		font-weight: 500;
	}

	:global(.dark) .match-item {
		background: rgb(30 58 138);
		color: rgb(191 219 254);
	}

	.more-matches {
		padding: 0.25rem 0.75rem;
		background: rgb(243 244 246);
		color: rgb(75 85 99);
		border-radius: 1rem;
		font-weight: 500;
		font-style: italic;
	}

	:global(.dark) .more-matches {
		background: rgb(55 65 81);
		color: rgb(156 163 175);
	}

	.actions {
		display: flex;
		justify-content: flex-end;
	}

	.view-link {
		font-size: 0.875rem;
		font-weight: 600;
		color: rgb(59 130 246);
		text-decoration: none;
		transition: color 0.2s;
	}

	.view-link:hover {
		color: rgb(37 99 235);
		text-decoration: underline;
	}

	:global(.dark) .view-link {
		color: rgb(96 165 250);
	}

	:global(.dark) .view-link:hover {
		color: rgb(147 197 253);
	}

	/* Responsive adjustments */
	@media (max-width: 768px) {
		.decklist-result {
			padding: 1rem;
		}

		.commander-info h3 {
			font-size: 1.125rem;
		}

		.card-matches {
			font-size: 0.8125rem;
		}

		.actions {
			margin-top: 0.5rem;
		}
	}
</style>
