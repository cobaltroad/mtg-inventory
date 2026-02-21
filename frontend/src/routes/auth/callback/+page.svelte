<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { checkAuthStatus } from '$lib/services/authService.svelte';
	import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';

	onMount(async () => {
		try {
			await checkAuthStatus();
			// eslint-disable-next-line svelte/no-navigation-within-svelte
			goto(`${base}/inventory`);
		} catch {
			goto(`${base}/login`);
		}
	});
</script>

<div class="callback-page">
	<LoadingSpinner message="Verifying authentication..." />
</div>

<style>
	.callback-page {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: calc(100vh - 200px);
		padding: 2rem;
	}
</style>
