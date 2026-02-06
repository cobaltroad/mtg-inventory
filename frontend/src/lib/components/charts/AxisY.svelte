<script>
	import { getContext } from 'svelte';

	export let ticks = 4;
	export let formatTick = (d) => d;

	const { height, yScale } = getContext('LayerCake');

	$: tickValues = $yScale.ticks(ticks);
</script>

<g class="axis y-axis">
	{#each tickValues as tick}
		<g class="tick" transform="translate(0,{$yScale(tick)})">
			<line x2="-6" stroke="currentColor" />
			<text x="-10" dy="0.32em" text-anchor="end">{formatTick(tick)}</text>
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
