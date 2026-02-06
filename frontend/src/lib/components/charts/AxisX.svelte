<script>
	import { getContext } from 'svelte';

	const { width, height, xScale } = getContext('LayerCake');

	$: ticks = $xScale.ticks(5);

	function formatDate(date) {
		return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' }).format(date);
	}
</script>

<g class="axis x-axis">
	{#each ticks as tick}
		<g class="tick" transform="translate({$xScale(tick)},{$height})">
			<line y2="6" stroke="currentColor" />
			<text y="20" text-anchor="middle">{formatDate(tick)}</text>
		</g>
	{/each}
</g>

<style>
	.tick text {
		fill: rgb(var(--color-surface-600));
		font-size: 12px;
	}

	:global(.dark) .tick text {
		fill: rgb(var(--color-surface-400));
	}

	.tick line {
		stroke: rgb(var(--color-surface-300));
	}

	:global(.dark) .tick line {
		stroke: rgb(var(--color-surface-600));
	}
</style>
