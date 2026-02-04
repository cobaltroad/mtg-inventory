<script lang="ts">
	import './layout.css';
	import favicon from '$lib/assets/favicon.svg';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import SearchDrawer from '$lib/components/SearchDrawer.svelte';

	let { children } = $props();
	let sidebarOpen = $state(false);
	let searchDrawerOpen = $state(false);

	function handleSearchClick() {
		searchDrawerOpen = true;
	}
</script>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>

<div class="app-container">
	<Sidebar bind:open={sidebarOpen} onSearchClick={handleSearchClick} />

	<main class="main-content">
		{@render children()}
	</main>

	<SearchDrawer bind:open={searchDrawerOpen} />
</div>

<style>
	.app-container {
		display: flex;
		min-height: 100vh;
	}

	.main-content {
		flex: 1;
		margin-left: 0;
		transition: margin-left 0.3s ease-in-out;
	}

	@media (min-width: 768px) {
		.main-content {
			margin-left: 16rem; /* Width of sidebar */
		}
	}
</style>
