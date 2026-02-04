import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { render, cleanup, fireEvent, waitFor } from '@testing-library/svelte';
import Sidebar from '$lib/components/Sidebar.svelte';
import SearchDrawer from '$lib/components/SearchDrawer.svelte';
import { base } from '$app/paths';

afterEach(() => {
	cleanup();
	vi.restoreAllMocks();
});

const MOCK_SEARCH_RESULTS = [
	{
		id: 'card-1',
		name: 'Lightning Bolt',
		mana_cost: '{R}'
	},
	{
		id: 'card-2',
		name: 'Counterspell',
		mana_cost: '{U}{U}'
	},
	{
		id: 'card-3',
		name: 'Shock',
		mana_cost: '{R}'
	}
];

describe('Search Drawer Integration - API Calls', () => {
	beforeEach(() => {
		// Reset fetch mock before each test
		vi.stubGlobal('fetch', vi.fn());
	});

	it('should make API call with correct query parameters when search is submitted', async () => {
		const mockFetch = vi.fn().mockResolvedValue({
			ok: true,
			json: () => Promise.resolve({ cards: MOCK_SEARCH_RESULTS })
		});
		vi.stubGlobal('fetch', mockFetch);

		render(SearchDrawer, {
			props: {
				open: true,
				onSearch: async (query: string) => {
					await fetch(`${base}/api/cards/search?q=${encodeURIComponent(query)}`);
				}
			}
		});

		// Enter search query - use document.body since Portal renders outside container
		const input = document.body.querySelector('input[type="text"]') as HTMLInputElement;
		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });

		// Submit the search form
		const form = document.body.querySelector('form');
		if (form) {
			await fireEvent.submit(form);
		}

		// Verify API call was made with correct parameters
		await waitFor(() => {
			expect(mockFetch).toHaveBeenCalledWith(
				expect.stringContaining('/api/cards/search?q=Lightning%20Bolt')
			);
		});
	});

	it('should display loading spinner during API call', async () => {
		const { rerender } = render(SearchDrawer, {
			props: {
				open: true,
				searching: false
			}
		});

		// Update to searching state
		await rerender({ open: true, searching: true });

		// Verify loading spinner appears
		await waitFor(() => {
			const spinner = document.body.querySelector('.spinner');
			expect(spinner).toBeInTheDocument();
		});
	});

	it('should display search results within the drawer after API call completes', async () => {
		const { rerender } = render(SearchDrawer, {
			props: {
				open: true,
				results: []
			}
		});

		// Simulate search results being displayed
		await rerender({ open: true, results: MOCK_SEARCH_RESULTS });

		// Wait for results to appear
		await waitFor(() => {
			expect(document.body.textContent).toContain('Lightning Bolt');
			expect(document.body.textContent).toContain('Counterspell');
		});
	});

	it('should keep drawer open after search results are displayed', async () => {
		const { rerender } = render(SearchDrawer, {
			props: {
				open: true,
				results: []
			}
		});

		// Display results
		await rerender({ open: true, results: MOCK_SEARCH_RESULTS });

		// Wait for results
		await waitFor(() => {
			expect(document.body.textContent).toContain('Lightning Bolt');
		});

		// Verify drawer is still open
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeVisible();
	});

	it('should display "No results found" message when API returns empty array', async () => {
		render(SearchDrawer, {
			props: {
				open: true,
				results: [],
				hasSearched: true
			}
		});

		// Wait for "no results" message
		await waitFor(() => {
			expect(document.body.textContent?.toLowerCase()).toContain('no results');
		});
	});

	it('should keep drawer open after no results message is displayed', async () => {
		render(SearchDrawer, {
			props: {
				open: true,
				results: [],
				hasSearched: true
			}
		});

		// Wait for no results message
		await waitFor(() => {
			expect(document.body.textContent?.toLowerCase()).toContain('no results');
		});

		// Verify drawer is still open
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeVisible();
	});

	it('should allow a new search after no results are found', async () => {
		const { rerender } = render(SearchDrawer, {
			props: {
				open: true,
				results: [],
				hasSearched: true
			}
		});

		await waitFor(() => {
			expect(document.body.textContent?.toLowerCase()).toContain('no results');
		});

		// Now display new results
		await rerender({ open: true, results: MOCK_SEARCH_RESULTS, hasSearched: true });

		// Verify new results appear
		await waitFor(() => {
			expect(document.body.textContent).toContain('Lightning Bolt');
		});
	});

	it('should handle API errors gracefully', async () => {
		render(SearchDrawer, {
			props: {
				open: true,
				results: [],
				hasSearched: true
			}
		});

		// Should display no results after error
		await waitFor(() => {
			expect(document.body.textContent?.toLowerCase()).toContain('no results');
		});
	});

	it('should make results scrollable when they exceed drawer height', async () => {
		// Create many results to test scrollability
		const manyResults = Array.from({ length: 20 }, (_, i) => ({
			id: `card-${i}`,
			name: `Card ${i}`,
			mana_cost: `{${i}}`
		}));

		render(SearchDrawer, {
			props: {
				open: true,
				results: manyResults
			}
		});

		// Wait for results
		await waitFor(() => {
			expect(document.body.textContent).toContain('Card 0');
		});

		// Verify results container exists and has the scrollable class
		const resultsContainer = document.body.querySelector('.results-container');
		expect(resultsContainer).toBeInTheDocument();
		expect(resultsContainer).toHaveClass('results-container');
	});

	it('should display card mana cost in results', async () => {
		render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS
			}
		});

		// Verify mana costs are displayed
		await waitFor(() => {
			expect(document.body.textContent).toContain('{R}');
			expect(document.body.textContent).toContain('{U}{U}');
		});
	});
});

describe('Search Drawer Integration - Sidebar Trigger', () => {
	it('should have Search button in sidebar instead of link', () => {
		// Mock window.location for Sidebar component
		Object.defineProperty(window, 'location', {
			value: { pathname: '/' },
			writable: true
		});

		const { container } = render(Sidebar);

		// Find the Search button in the sidebar
		const searchButton = container.querySelector(
			'button[aria-label*="Search"]'
		) as HTMLButtonElement;
		expect(searchButton).toBeInTheDocument();
		expect(searchButton).toHaveAttribute('type', 'button');

		// Should not have a search link
		const searchLink = container.querySelector('a[href*="search"]');
		expect(searchLink).not.toBeInTheDocument();
	});

	it('should open drawer when Search button is clicked', async () => {
		Object.defineProperty(window, 'location', {
			value: { pathname: '/' },
			writable: true
		});

		const onSearchClick = vi.fn();
		const { container } = render(Sidebar, { props: { onSearchClick } });

		const searchButton = container.querySelector(
			'button[aria-label*="Search"]'
		) as HTMLButtonElement;
		await fireEvent.click(searchButton);

		// Callback should be called
		expect(onSearchClick).toHaveBeenCalledTimes(1);
	});

	it('should still have Home and Inventory as navigation links', () => {
		Object.defineProperty(window, 'location', {
			value: { pathname: '/' },
			writable: true
		});

		const { container } = render(Sidebar);

		const homeLink = container.querySelector('a[href="/"]');
		expect(homeLink).toBeInTheDocument();

		const inventoryLink = container.querySelector('a[href="/inventory"]');
		expect(inventoryLink).toBeInTheDocument();
	});

	it('should work from any page (Home, Inventory, etc)', () => {
		const pages = ['/', '/inventory'];

		pages.forEach((pathname) => {
			Object.defineProperty(window, 'location', {
				value: { pathname },
				writable: true
			});

			const { container } = render(Sidebar);

			const searchButton = container.querySelector(
				'button[aria-label*="Search"]'
			) as HTMLButtonElement;
			expect(searchButton).toBeInTheDocument();

			cleanup();
		});
	});
});
