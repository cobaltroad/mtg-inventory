<script>
	import { getContext } from 'svelte';

	const { data, xGet, yGet } = getContext('LayerCake');

	$: path = 'M' + $data.map((d) => `${$xGet(d)},${$yGet(d)}`).join('L');
</script>

<path class="path-line" d={path} />

<style>
	.path-line {
		fill: none;
		stroke: rgb(var(--color-primary-500));
		stroke-linejoin: round;
		stroke-linecap: round;
		stroke-width: 2;
	}

	:global(.dark) .path-line {
		stroke: rgb(var(--color-primary-400));
	}
</style>
