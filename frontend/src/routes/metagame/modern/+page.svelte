<script lang="ts">
	import { base } from '$app/paths';
	import { Construction } from 'lucide-svelte';
</script>

<div class="container mx-auto px-4 py-8">
	<div class="flex min-h-[60vh] items-center justify-center">
		<div class="max-w-2xl card bg-surface-200 p-8 text-center dark:bg-surface-800">
			<div class="mb-6 flex justify-center">
				<div class="rounded-full bg-surface-300 p-6 dark:bg-surface-700">
					<Construction size={48} />
				</div>
			</div>
			<h1 class="mb-4 h1">Modern Metagame</h1>
			<p class="text-surface-600-300-token mb-6 text-lg">
				Modern metagame tracking is coming soon. This feature will include popular decks, archetype
				breakdowns, and card usage statistics.
			</p>
			<a href="{base}/metagame" class="btn bg-primary-500 text-white hover:bg-primary-600">
				Back to Metagame Browser
			</a>
		</div>
	</div>
</div>
