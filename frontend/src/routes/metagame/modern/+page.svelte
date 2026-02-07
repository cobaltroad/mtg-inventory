<script lang="ts">
	import { base } from '$app/paths';
	import { Construction } from 'lucide-svelte';
</script>

<div class="container mx-auto px-4 py-8">
	<div class="flex min-h-[60vh] items-center justify-center">
		<div class="variant-ghost card max-w-2xl p-8 text-center">
			<div class="mb-6 flex justify-center">
				<div class="variant-soft-surface rounded-full p-6">
					<Construction size={48} />
				</div>
			</div>
			<h1 class="mb-4 h1">Modern Metagame</h1>
			<p class="text-surface-600-300-token mb-6 text-lg">
				Modern metagame tracking is coming soon. This feature will include popular decks,
				archetype breakdowns, and card usage statistics.
			</p>
			<a href="{base}/metagame" class="variant-filled-primary btn">
				Back to Metagame Browser
			</a>
		</div>
	</div>
</div>
