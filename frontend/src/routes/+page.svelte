<script lang="ts">
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import PriceAlertWidget from '$lib/components/PriceAlertWidget.svelte';

	const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED === 'true';

	let isAuthenticated = $state(false);
	let authLoading = $state(AUTH_ENABLED);

	async function checkAuth() {
		if (!AUTH_ENABLED) {
			authLoading = false;
			return;
		}

		try {
			const response = await fetch(`${base}/api/auth/status`);
			const data = await response.json();
			isAuthenticated = data.authenticated;
		} catch {
			isAuthenticated = false;
		} finally {
			authLoading = false;
		}
	}

	onMount(() => {
		checkAuth();
	});
</script>

<div class="container mx-auto space-y-6 p-4">
	<h1 class="h1">MTG Inventory</h1>

	<div class="mb-6">
		<a href="{base}/search" class="btn bg-primary-500 text-white hover:bg-primary-600"
			>Search Cards</a
		>
	</div>

	{#if AUTH_ENABLED && !authLoading}
		{#if isAuthenticated}
			<PriceAlertWidget />
		{:else}
			<div class="card p-4">
				<p class="mb-4">Sign in to view your price alerts.</p>
				<a href="{base}/login" class="btn bg-primary-500 text-white hover:bg-primary-600">Log in</a>
			</div>
		{/if}
	{:else if !AUTH_ENABLED}
		<PriceAlertWidget />
	{/if}
</div>
