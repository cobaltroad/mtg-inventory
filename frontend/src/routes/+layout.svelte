<script lang="ts">
	import './layout.css';
  import '@fontsource-variable/montserrat';
	import { base } from '$app/paths';
	import favicon from '$lib/assets/favicon.svg';
	import { AppBar } from '@skeletonlabs/skeleton-svelte';
	import Sidebar from '$lib/components/Sidebar.svelte';
	import SearchDrawer from '$lib/components/SearchDrawer.svelte';
	import PrintingModal from '$lib/components/PrintingModal.svelte';
	import type { Card } from '$lib/types/card';
	import { onMount, setContext } from 'svelte';

	let { children } = $props();

	// Provide search drawer control to child components
	setContext('openSearchDrawer', () => {
		searchDrawerOpen = true;
	});

	// Dark mode management
	onMount(() => {
		// Check for saved preference or use system preference
		const savedTheme = localStorage.getItem('theme');
		const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

		if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
			document.documentElement.classList.add('dark');
		} else {
			document.documentElement.classList.remove('dark');
		}

		// Listen for system theme changes
		const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
		const handleChange = (e: MediaQueryListEvent) => {
			if (!localStorage.getItem('theme')) {
				if (e.matches) {
					document.documentElement.classList.add('dark');
				} else {
					document.documentElement.classList.remove('dark');
				}
			}
		};
		mediaQuery.addEventListener('change', handleChange);

		return () => {
			mediaQuery.removeEventListener('change', handleChange);
		};
	});
	// UI state
	let sidebarOpen = $state(false);
	let searchDrawerOpen = $state(false);
	let sidebarMode = $state<'sidebar' | 'rail'>('sidebar');

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
	 * Toggles between sidebar and rail navigation modes.
	 */
	function toggleSidebarMode() {
		sidebarMode = sidebarMode === 'sidebar' ? 'rail' : 'sidebar';
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
	<Sidebar
		bind:open={sidebarOpen}
		mode={sidebarMode}
		onSearchClick={handleSearchClick}
		onToggleMode={toggleSidebarMode}
	/>

	<div class="content-wrapper" class:rail-mode={sidebarMode === 'rail'}>
		<AppBar class="app-bar-root">
			{#snippet headline()}
				<span class="app-title">MTG Inventory</span>
			{/snippet}
		</AppBar>

		<main class="main-content">
			{@render children()}
		</main>
	</div>

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

	.content-wrapper {
		flex: 1;
		display: flex;
		flex-direction: column;
		margin-left: 0;
		transition: margin-left 0.3s ease-in-out;
	}

	@media (min-width: 768px) {
		.content-wrapper {
			margin-left: 16rem; /* Sidebar width */
		}

		.content-wrapper.rail-mode {
			margin-left: 5rem; /* Rail width */
		}
	}

	:global(.app-bar-root) {
		position: sticky;
		top: 0;
		height: 3em;
		z-index: 10;
		background-color: var(--color-surface-900);
		border-bottom: 1px solid var(--color-surface-700);
	}

	.app-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: var(--color-surface-50);
	}

	.main-content {
		flex: 1;
	}
</style>
