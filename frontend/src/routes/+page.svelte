<script lang="ts">
	import { base } from '$app/paths';
	import PriceAlertWidget from '$lib/components/PriceAlertWidget.svelte';
	import InventoryValueWidget from '$lib/components/InventoryValueWidget.svelte';
</script>

<div class="container mx-auto space-y-6 p-4">
	<h1 class="h1">MTG Inventory</h1>

	<PriceAlertWidget />

	<InventoryValueWidget />

	<div class="variant-ghost-surface card p-4">
		<p><a href="{base}/search" class="anchor">Search Cards</a></p>
	</div>
</div>
