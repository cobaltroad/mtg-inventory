<script lang="ts">
	import './layout.css';
	import { base } from '$app/paths';
	import favicon from '$lib/assets/favicon.svg';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import SearchDrawer from '$lib/components/SearchDrawer.svelte';
	import PrintingModal from '$lib/components/PrintingModal.svelte';
	import type { Card } from '$lib/types/card';

	let { children } = $props();
	// UI state
	let sidebarOpen = $state(false);
	let searchDrawerOpen = $state(false);

	// Search state
	let searching = $state(false);
	let results: Card[] = $state([]);
	let hasSearched = $state(false);

	// PrintingModal state
	let selectedCard = $state<Card | null>(null);
	let modalOpen = $state(false);

	/**
	 * Opens the search drawer when the search button in the sidebar is clicked.
	 */
	function handleSearchClick() {
		searchDrawerOpen = true;
	}

	/**
	 * Performs a card search via the API.
	 * @param query - The search query string
	 */
	async function handleSearch(query: string) {
		if (!query.trim()) return;

		searching = true;
		hasSearched = true;

		try {
			const res = await fetch(`${base}/api/cards/search?q=${encodeURIComponent(query)}`);
			const data = await res.json();
			results = data.cards || [];
		} catch (error) {
			console.error('Search failed:', error);
			results = [];
		} finally {
			searching = false;
		}
	}

	/**
	 * Handles card selection from search drawer.
	 * Opens the PrintingModal with the selected card.
	 * @param card - The selected card
	 */
	function handleCardSelect(card: Card) {
		selectedCard = card;
		modalOpen = true;
	}

	/**
	 * Handles closing the PrintingModal.
	 * Clears the selected card.
	 */
	function handleModalClose() {
		modalOpen = false;
		selectedCard = null;
	}
</script>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>

<div class="app-container">
	<Sidebar bind:open={sidebarOpen} onSearchClick={handleSearchClick} />

	<main class="main-content">
		{@render children()}
	</main>

	<SearchDrawer
		bind:open={searchDrawerOpen}
		{results}
		{searching}
		{hasSearched}
		onSearch={handleSearch}
		onCardSelect={handleCardSelect}
	/>

	{#if selectedCard}
		<PrintingModal card={selectedCard} bind:open={modalOpen} onclose={handleModalClose} />
	{/if}
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
