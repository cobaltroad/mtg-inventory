<script lang="ts">
	import './layout.css';
	import { base } from '$app/paths';
	import favicon from '$lib/assets/favicon.svg';

	let { children } = $props();

	export const trailingSlash = 'ignore';
</script>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>

<nav class="main-nav">
	<a href="{base}/" class="nav-link">Home</a>
	<a href="{base}/search" class="nav-link">Search</a>
	<a href="{base}/inventory" class="nav-link">Inventory</a>
</nav>

<main class="main-content">
	{@render children()}
</main>

<style>
	.main-nav {
		display: flex;
		gap: 1.5rem;
		padding: 1rem 2rem;
		background: #1f2937;
		border-bottom: 2px solid #374151;
	}

	.nav-link {
		color: #e5e7eb;
		text-decoration: none;
		font-weight: 600;
		padding: 0.5rem 1rem;
		border-radius: 4px;
		transition: all 0.2s;
	}

	.nav-link:hover {
		background: #374151;
		color: white;
	}

	.main-content {
		min-height: calc(100vh - 70px);
	}
</style>
