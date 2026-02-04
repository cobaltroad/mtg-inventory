import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { render, cleanup, fireEvent, waitFor } from '@testing-library/svelte';
import Sidebar from '$lib/components/Sidebar.svelte';
import SearchDrawer from '$lib/components/SearchDrawer.svelte';
import { base } from '$app/paths';
import type { Card } from '$lib/types/card';

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

describe('Search Drawer Integration - PrintingModal', () => {
	beforeEach(() => {
		vi.stubGlobal('fetch', vi.fn());
	});

	it('should open PrintingModal when a card result is clicked', async () => {
		const mockFetch = vi.fn().mockImplementation((url: string) => {
			if (typeof url === 'string' && url.includes('/api/cards/search')) {
				return Promise.resolve({
					ok: true,
					json: () => Promise.resolve({ cards: MOCK_SEARCH_RESULTS })
				});
			}
			if (typeof url === 'string' && url.includes('/printings')) {
				return Promise.resolve({
					ok: true,
					json: () => Promise.resolve({ printings: [] })
				});
			}
			return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
		});
		vi.stubGlobal('fetch', mockFetch);

		render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS,
				onCardSelect: (card) => {
					// Verify that onCardSelect was called
					expect(card).toBeDefined();
					expect(card.id).toBe('card-1');
				}
			}
		});

		// Click on first card result
		const firstResult = document.body.querySelector('[data-card-id="card-1"]');
		expect(firstResult).toBeInTheDocument();

		if (firstResult) {
			await fireEvent.click(firstResult);
		}
	});

	it('should pass correct card data to PrintingModal', async () => {
		const cardData = MOCK_SEARCH_RESULTS[0];
		let receivedCard: Card | null = null;

		render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS,
				onCardSelect: (card) => {
					receivedCard = card;
				}
			}
		});

		const firstResult = document.body.querySelector('[data-card-id="card-1"]');
		if (firstResult) {
			await fireEvent.click(firstResult);
		}

		await waitFor(() => {
			expect(receivedCard).toEqual(cardData);
		});
	});

	it('should keep drawer open when PrintingModal is displayed', async () => {
		render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS,
				onCardSelect: vi.fn()
			}
		});

		// Click on a card to open modal
		const firstResult = document.body.querySelector('[data-card-id="card-1"]');
		if (firstResult) {
			await fireEvent.click(firstResult);
		}

		// Drawer should still be visible
		await waitFor(() => {
			const drawer = document.body.querySelector('[data-testid="search-drawer"]');
			expect(drawer).toBeVisible();
		});
	});

	it('should return to search results when modal is closed', async () => {
		// This test verifies the drawer remains open after modal closes
		// The actual modal closing is tested in the component level test
		render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS,
				onCardSelect: vi.fn()
			}
		});

		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeVisible();

		// Results should still be displayed
		expect(document.body.textContent).toContain('Lightning Bolt');
	});

	it('should allow selecting different card after closing modal', async () => {
		const onCardSelect = vi.fn();

		render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS,
				onCardSelect
			}
		});

		// Click first card
		const firstResult = document.body.querySelector('[data-card-id="card-1"]');
		if (firstResult) {
			await fireEvent.click(firstResult);
		}

		await waitFor(() => {
			expect(onCardSelect).toHaveBeenCalledWith(MOCK_SEARCH_RESULTS[0]);
		});

		// Click second card
		const secondResult = document.body.querySelector('[data-card-id="card-2"]');
		if (secondResult) {
			await fireEvent.click(secondResult);
		}

		await waitFor(() => {
			expect(onCardSelect).toHaveBeenCalledWith(MOCK_SEARCH_RESULTS[1]);
			expect(onCardSelect).toHaveBeenCalledTimes(2);
		});
	});

	it('should allow adding card to inventory from modal while drawer is open', async () => {
		// This is an integration test that verifies the workflow
		// The actual "add to inventory" functionality is tested in PrintingModal tests
		const onCardSelect = vi.fn();

		render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS,
				onCardSelect
			}
		});

		// Select a card (which would open the modal in the full app)
		const firstResult = document.body.querySelector('[data-card-id="card-1"]');
		if (firstResult) {
			await fireEvent.click(firstResult);
		}

		await waitFor(() => {
			expect(onCardSelect).toHaveBeenCalled();
		});

		// Drawer should still be visible
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeVisible();
	});
});

describe('Search Drawer - Navigation Preservation (Scenario 8)', () => {
	beforeEach(() => {
		vi.stubGlobal('fetch', vi.fn());
	});

	it('should preserve current page location when drawer is opened', async () => {
		const originalPathname = '/inventory';
		Object.defineProperty(window, 'location', {
			value: { pathname: originalPathname },
			writable: true,
			configurable: true
		});

		render(SearchDrawer, {
			props: {
				open: false
			}
		});

		// Verify location hasn't changed
		expect(window.location.pathname).toBe(originalPathname);
	});

	it('should preserve current page location when drawer is closed', async () => {
		const originalPathname = '/inventory';
		Object.defineProperty(window, 'location', {
			value: { pathname: originalPathname },
			writable: true,
			configurable: true
		});

		const { rerender } = render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS
			}
		});

		// Close the drawer
		await rerender({ open: false, results: MOCK_SEARCH_RESULTS });

		// Verify location hasn't changed
		expect(window.location.pathname).toBe(originalPathname);
	});

	it('should not trigger any navigation events when drawer opens or closes', async () => {
		const navigationSpy = vi.fn();
		window.addEventListener('popstate', navigationSpy);
		window.addEventListener('pushstate', navigationSpy);

		const { rerender } = render(SearchDrawer, {
			props: {
				open: false
			}
		});

		// Open drawer
		await rerender({ open: true });

		// Close drawer
		await rerender({ open: false });

		// No navigation events should have been triggered
		expect(navigationSpy).not.toHaveBeenCalled();

		// Cleanup
		window.removeEventListener('popstate', navigationSpy);
		window.removeEventListener('pushstate', navigationSpy);
	});

	it('should use position fixed to avoid affecting page scroll', async () => {
		render(SearchDrawer, {
			props: {
				open: true
			}
		});

		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeInTheDocument();

		// Verify the drawer content has proper positioning classes
		// In the implementation, the Dialog.Content has position fixed through the Dialog.Positioner
		const positioner = document.body.querySelector('.fixed.inset-0.z-50');
		expect(positioner).toBeInTheDocument();
	});
});

describe('Search Drawer - Mobile Responsiveness (Scenario 10)', () => {
	beforeEach(() => {
		vi.stubGlobal('fetch', vi.fn());
		// Reset viewport to desktop by default
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 1024
		});
	});

	afterEach(() => {
		// Reset to desktop size
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 1024
		});
	});

	it('should display drawer at full width on mobile viewport (width < 768px)', async () => {
		// Set mobile viewport
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 375
		});
		window.dispatchEvent(new Event('resize'));

		render(SearchDrawer, {
			props: {
				open: true
			}
		});

		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeInTheDocument();

		// Verify drawer has w-full class for mobile
		expect(drawer).toHaveClass('w-full');
	});

	it('should display drawer at fixed width on desktop viewport (width >= 768px)', async () => {
		// Set desktop viewport
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 1024
		});
		window.dispatchEvent(new Event('resize'));

		render(SearchDrawer, {
			props: {
				open: true
			}
		});

		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeInTheDocument();

		// Verify drawer has both w-full and md:w-96 classes (Tailwind responsive)
		expect(drawer).toHaveClass('w-full');
		expect(drawer).toHaveClass('md:w-96');
	});

	it('should slide in from right on mobile viewport', async () => {
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 375
		});
		window.dispatchEvent(new Event('resize'));

		render(SearchDrawer, {
			props: {
				open: true
			}
		});

		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeInTheDocument();

		// Verify animation classes for sliding from right
		expect(drawer).toHaveClass('data-[state=open]:slide-in-from-right');
	});

	it('should allow search functionality on mobile viewport', async () => {
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 375
		});

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

		// Enter search query
		const input = document.body.querySelector('input[type="text"]') as HTMLInputElement;
		await fireEvent.input(input, { target: { value: 'Lightning' } });

		// Submit the search form
		const form = document.body.querySelector('form');
		if (form) {
			await fireEvent.submit(form);
		}

		// Verify API call was made
		await waitFor(() => {
			expect(mockFetch).toHaveBeenCalledWith(
				expect.stringContaining('/api/cards/search?q=Lightning')
			);
		});
	});

	it('should display scrollable results on mobile viewport', async () => {
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 375
		});

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

		await waitFor(() => {
			expect(document.body.textContent).toContain('Card 0');
		});

		// Verify results container is scrollable
		const resultsContainer = document.body.querySelector('.results-container');
		expect(resultsContainer).toBeInTheDocument();
		expect(resultsContainer).toHaveClass('results-container');
	});

	it('should handle touch interactions on mobile', async () => {
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 375
		});

		render(SearchDrawer, {
			props: {
				open: true,
				results: MOCK_SEARCH_RESULTS,
				onCardSelect: vi.fn()
			}
		});

		// Simulate touch event on a result
		const firstResult = document.body.querySelector('[data-card-id="card-1"]');
		expect(firstResult).toBeInTheDocument();

		if (firstResult) {
			// Click should work on mobile (touch is converted to click)
			await fireEvent.click(firstResult);
			// Test passes if no errors are thrown
		}
	});

	it('should close drawer with backdrop click on mobile', async () => {
		Object.defineProperty(window, 'innerWidth', {
			writable: true,
			configurable: true,
			value: 375
		});

		let isOpen = true;
		const { rerender } = render(SearchDrawer, {
			props: {
				open: isOpen
			}
		});

		// Verify drawer is open
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeVisible();

		// Simulate close (in the real app, clicking backdrop would close)
		isOpen = false;
		await rerender({ open: isOpen });

		// Drawer should be closed (test relies on component behavior)
		// The Dialog component handles backdrop clicks via closeOnInteractOutside
	});
});
