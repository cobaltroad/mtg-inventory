<script lang="ts">
	import { onMount } from 'svelte';
	import { Search as SearchIcon } from 'lucide-svelte';
	import { performSearch } from '$lib/services/searchService';
	import type { SearchResults, SearchTab } from '$lib/types/search';
	import DecklistResult from '$lib/components/search/DecklistResult.svelte';

	// Constants
	const MIN_QUERY_LENGTH = 2;

	// State using Svelte 5 runes
	let query = $state('');
	let isLoading = $state(false);
	let activeTab = $state<SearchTab>('all');
	let results = $state<SearchResults | null>(null);
	let error = $state<string | null>(null);
	let validationError = $state<string | null>(null);
	let hasSearched = $state(false);
	let searchInputRef: HTMLInputElement | undefined;

	/**
	 * Focus the search input when the page loads
	 */
	onMount(() => {
		searchInputRef?.focus();
	});

	/**
	 * Validates the search query
	 * @returns true if valid, false otherwise
	 */
	function validateQuery(): boolean {
		const trimmedQuery = query.trim();
		if (trimmedQuery.length < MIN_QUERY_LENGTH) {
			validationError = `Search query must be at least ${MIN_QUERY_LENGTH} characters`;
			return false;
		}
		validationError = null;
		return true;
	}

	/**
	 * Handles search form submission
	 */
	async function handleSearch() {
		if (!validateQuery()) {
			return;
		}

		isLoading = true;
		error = null;
		hasSearched = true;

		try {
			const trimmedQuery = query.trim();
			const searchResults = await performSearch(trimmedQuery);
			results = searchResults;
		} catch (err) {
			console.error('Search error:', err);
			error = 'Search failed. Please try again.';
			results = null;
		} finally {
			isLoading = false;
		}
	}

	/**
	 * Handles Enter key press in search input
	 */
	function handleKeyPress(event: KeyboardEvent) {
		if (event.key === 'Enter') {
			handleSearch();
		}
	}

	/**
	 * Handles input changes - clears validation error
	 */
	function handleInput() {
		validationError = null;
	}

	/**
	 * Changes the active tab
	 */
	function setActiveTab(tab: SearchTab) {
		activeTab = tab;
	}

	/**
	 * Determines if there are no results
	 */
	const hasNoResults = $derived(
		results !== null &&
			results.results.decklists.length === 0 &&
			results.results.inventory.length === 0
	);

	/**
	 * Computed counts for tab labels
	 */
	const decklistCount = $derived(results?.results.decklists.length || 0);
	const inventoryCount = $derived(results?.results.inventory.length || 0);
	const totalCount = $derived(results?.total_results || 0);

	/**
	 * Filtered results based on active tab
	 */
	const shouldShowDecklists = $derived(activeTab === 'all' || activeTab === 'decklists');
	const shouldShowInventory = $derived(activeTab === 'all' || activeTab === 'inventory');

	/**
	 * Empty state for decklists in the Decklists tab
	 */
	const showDecklistEmptyState = $derived(
		activeTab === 'decklists' && results !== null && results.results.decklists.length === 0
	);
</script>

<div class="search-page">
	<div class="search-container">
		<!-- Page Title -->
		<h1 class="page-title">Search</h1>

		<!-- Search Form -->
		<div class="search-form">
			<div class="input-wrapper">
				<SearchIcon class="search-icon" size={20} />
				<input
					bind:this={searchInputRef}
					bind:value={query}
					type="text"
					placeholder="Enter a card name to search across decklists and inventory"
					class="search-input"
					oninput={handleInput}
					onkeypress={handleKeyPress}
					aria-label="Search query"
				/>
			</div>
			<button onclick={handleSearch} disabled={isLoading} class="search-button" aria-label="Search">
				{isLoading ? 'Searching...' : 'Search'}
			</button>
		</div>

		<!-- Validation Error -->
		{#if validationError}
			<div class="validation-error" role="alert">
				{validationError}
			</div>
		{/if}

		<!-- Tabs -->
		<div class="tabs" role="tablist">
			<button
				role="tab"
				aria-selected={activeTab === 'all'}
				onclick={() => setActiveTab('all')}
				class="tab {activeTab === 'all' ? 'active' : ''}"
			>
				All {hasSearched ? `(${totalCount})` : ''}
			</button>
			<button
				role="tab"
				aria-selected={activeTab === 'decklists'}
				onclick={() => setActiveTab('decklists')}
				class="tab {activeTab === 'decklists' ? 'active' : ''}"
			>
				Decklists {hasSearched ? `(${decklistCount})` : ''}
			</button>
			<button
				role="tab"
				aria-selected={activeTab === 'inventory'}
				onclick={() => setActiveTab('inventory')}
				class="tab {activeTab === 'inventory' ? 'active' : ''}"
			>
				Inventory {hasSearched ? `(${inventoryCount})` : ''}
			</button>
		</div>

		<!-- Results Area -->
		<div class="results-area">
			{#if isLoading}
				<!-- Loading State -->
				<div class="loading-state" role="status">
					<div class="spinner"></div>
					<p>Searching...</p>
				</div>
			{:else if error}
				<!-- Error State -->
				<div class="error-state" role="alert">
					<p class="error-message">{error}</p>
				</div>
			{:else if !hasSearched}
				<!-- Initial Empty State -->
				<div class="empty-state">
					<SearchIcon size={48} class="empty-icon" />
					<p class="empty-message">Enter a card name to search across decklists and inventory</p>
				</div>
			{:else if hasNoResults}
				<!-- No Results State -->
				<div class="empty-state">
					<SearchIcon size={48} class="empty-icon" />
					<p class="empty-message">No results found for "{results?.query}"</p>
					<p class="empty-suggestion">Try different search terms</p>
				</div>
			{:else if showDecklistEmptyState}
				<!-- Empty state for Decklists tab -->
				<div class="empty-state">
					<SearchIcon size={48} class="empty-icon" />
					<p class="empty-message">No commanders found matching "{results?.query}"</p>
					<p class="empty-suggestion">Try different search terms or check the Inventory tab</p>
				</div>
			{:else}
				<!-- Results Display -->
				<div class="results-display">
					{#if shouldShowDecklists && results && results.results.decklists.length > 0}
						<section class="results-section">
							<h2 class="section-heading">Decklists</h2>
							<div class="decklist-results">
								{#each results.results.decklists as result (result.commander_id)}
									<DecklistResult {result} />
								{/each}
							</div>
						</section>
					{/if}

					{#if shouldShowInventory && results && results.results.inventory.length > 0}
						<section class="results-section">
							<h2 class="section-heading">Inventory</h2>
							<div class="inventory-results">
								<p class="results-placeholder">
									Inventory results will be displayed here (Story 11.5)
								</p>
							</div>
						</section>
					{/if}
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	.search-page {
		padding: 2rem;
		max-width: 1200px;
		margin: 0 auto;
	}

	.search-container {
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.page-title {
		font-size: 2rem;
		font-weight: 700;
		color: var(--color-surface-900);
		margin: 0;
	}

	:global(.dark) .page-title {
		color: var(--color-surface-50);
	}

	.search-form {
		display: flex;
		gap: 1rem;
		align-items: flex-start;
	}

	.input-wrapper {
		flex: 1;
		position: relative;
		display: flex;
		align-items: center;
	}

	:global(.search-icon) {
		position: absolute;
		left: 1rem;
		color: rgb(107 114 128);
		pointer-events: none;
	}

	.search-input {
		width: 100%;
		padding: 0.75rem 1rem 0.75rem 3rem;
		font-size: 1rem;
		border: 2px solid rgb(229 231 235);
		border-radius: 0.5rem;
		background: white;
		color: rgb(17 24 39);
		transition: border-color 0.2s;
	}

	.search-input:focus {
		outline: none;
		border-color: rgb(59 130 246);
	}

	:global(.dark) .search-input {
		background: rgb(31 41 55);
		color: rgb(229 231 235);
		border-color: rgb(55 65 81);
	}

	:global(.dark) .search-input:focus {
		border-color: rgb(59 130 246);
	}

	.search-button {
		padding: 0.75rem 2rem;
		font-size: 1rem;
		font-weight: 600;
		color: white;
		background: rgb(59 130 246);
		border: none;
		border-radius: 0.5rem;
		cursor: pointer;
		transition: background 0.2s;
		white-space: nowrap;
	}

	.search-button:hover:not(:disabled) {
		background: rgb(37 99 235);
	}

	.search-button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.validation-error {
		padding: 0.75rem 1rem;
		background: rgb(254 226 226);
		color: rgb(153 27 27);
		border-radius: 0.5rem;
		font-size: 0.875rem;
	}

	:global(.dark) .validation-error {
		background: rgb(127 29 29);
		color: rgb(254 202 202);
	}

	.tabs {
		display: flex;
		gap: 0.5rem;
		border-bottom: 2px solid rgb(229 231 235);
		padding-bottom: 0;
	}

	:global(.dark) .tabs {
		border-bottom-color: rgb(55 65 81);
	}

	.tab {
		padding: 0.75rem 1.5rem;
		font-size: 1rem;
		font-weight: 500;
		color: rgb(107 114 128);
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		cursor: pointer;
		transition: all 0.2s;
		margin-bottom: -2px;
	}

	.tab:hover {
		color: rgb(59 130 246);
	}

	.tab.active {
		color: rgb(59 130 246);
		border-bottom-color: rgb(59 130 246);
	}

	:global(.dark) .tab {
		color: rgb(156 163 175);
	}

	:global(.dark) .tab:hover {
		color: rgb(96 165 250);
	}

	:global(.dark) .tab.active {
		color: rgb(96 165 250);
		border-bottom-color: rgb(96 165 250);
	}

	.results-area {
		min-height: 300px;
		padding: 2rem;
		background: white;
		border-radius: 0.5rem;
		border: 1px solid rgb(229 231 235);
	}

	:global(.dark) .results-area {
		background: rgb(31 41 55);
		border-color: rgb(55 65 81);
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 4rem 0;
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid rgb(229 231 235);
		border-top-color: rgb(59 130 246);
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	:global(.dark) .spinner {
		border-color: rgb(55 65 81);
		border-top-color: rgb(96 165 250);
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 1rem;
		padding: 4rem 0;
		text-align: center;
	}

	:global(.empty-icon) {
		color: rgb(156 163 175);
	}

	:global(.dark .empty-icon) {
		color: rgb(107 114 128);
	}

	.empty-message {
		font-size: 1.125rem;
		color: rgb(107 114 128);
		margin: 0;
	}

	:global(.dark) .empty-message {
		color: rgb(156 163 175);
	}

	.empty-suggestion {
		font-size: 0.875rem;
		color: rgb(156 163 175);
		margin: 0;
	}

	:global(.dark) .empty-suggestion {
		color: rgb(107 114 128);
	}

	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 0;
	}

	.error-message {
		font-size: 1.125rem;
		color: rgb(220 38 38);
		margin: 0;
	}

	:global(.dark) .error-message {
		color: rgb(248 113 113);
	}

	.results-placeholder {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 0.5rem;
		padding: 2rem 0;
		color: rgb(107 114 128);
	}

	:global(.dark) .results-placeholder {
		color: rgb(156 163 175);
	}

	.results-display {
		display: flex;
		flex-direction: column;
		gap: 2rem;
	}

	.results-section {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.section-heading {
		font-size: 1.25rem;
		font-weight: 700;
		color: rgb(17 24 39);
		margin: 0;
		padding-bottom: 0.5rem;
		border-bottom: 2px solid rgb(229 231 235);
	}

	:global(.dark) .section-heading {
		color: rgb(229 231 235);
		border-bottom-color: rgb(55 65 81);
	}

	.decklist-results {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.inventory-results {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	/* Responsive adjustments */
	@media (max-width: 768px) {
		.search-page {
			padding: 1rem;
		}

		.section-heading {
			font-size: 1.125rem;
		}
	}
</style>
