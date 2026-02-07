<script lang="ts">
	import { base } from '$app/paths';
	import PriceAlertWidget from '$lib/components/PriceAlertWidget.svelte';
</script>

<div class="container mx-auto p-4 space-y-6">
	<h1 class="h1">MTG Inventory</h1>

	<PriceAlertWidget />

	<div class="card variant-ghost-surface p-4">
		<p><a href="{base}/search" class="anchor">Search Cards</a></p>
	</div>
</div>
