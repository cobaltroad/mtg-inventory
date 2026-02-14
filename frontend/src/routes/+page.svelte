<script lang="ts">
	import { base } from '$app/paths';
	import PriceAlertWidget from '$lib/components/PriceAlertWidget.svelte';
</script>

<div class="container mx-auto space-y-6 p-4">
	<h1 class="h1">MTG Inventory</h1>

	<div class="mb-6">
		<a href="{base}/search" class="btn variant-filled-primary">Search Cards</a>
	</div>

	<PriceAlertWidget />
</div>
