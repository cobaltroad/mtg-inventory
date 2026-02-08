import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import { base } from '$app/paths';
import SearchPage from './+page.svelte';
import type { SearchResults } from '$lib/types/search';

/**
 * TDD Tests for Search Page (Issue #108)
 * Following red-green-refactor cycle
 *
 * These tests verify:
 * - Page structure and layout
 * - Form submission (Enter key and button click)
 * - Client-side validation (min 2 characters)
 * - Tab navigation (All/Decklists/Inventory)
 * - Loading states
 * - Empty states (before search, no results)
 * - Error handling
 * - API integration
 */

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('Search Page - Structure and Layout', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should render search input field with placeholder text', () => {
		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		expect(input).toBeTruthy();
	});

	it('should render search submit button', () => {
		render(SearchPage);
		const button = screen.getByRole('button', { name: /search/i });
		expect(button).toBeTruthy();
	});

	it('should render three tabs: All, Decklists, Inventory', () => {
		render(SearchPage);
		expect(screen.getByRole('tab', { name: 'All' })).toBeTruthy();
		expect(screen.getByRole('tab', { name: 'Decklists' })).toBeTruthy();
		expect(screen.getByRole('tab', { name: 'Inventory' })).toBeTruthy();
	});

	it('should have All tab selected by default', () => {
		render(SearchPage);
		const allTab = screen.getByRole('tab', { name: 'All' });
		expect(allTab.getAttribute('aria-selected')).toBe('true');
	});

	it('should focus the search input when page loads', async () => {
		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		await waitFor(() => {
			expect(document.activeElement).toBe(input);
		});
	});

	it('should display empty state before search is performed', () => {
		render(SearchPage);
		expect(
			screen.getByText('Enter a card name to search across decklists and inventory')
		).toBeTruthy();
	});
});

describe('Search Form - Submission', () => {
	beforeEach(() => {
		mockFetch.mockClear();
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => ({
				query: 'Lightning Bolt',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});
	});

	afterEach(() => {
		cleanup();
	});

	it('should trigger search when Enter key is pressed', async () => {
		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.keyPress(input, { key: 'Enter', code: 'Enter' });

		await waitFor(() => {
			expect(mockFetch).toHaveBeenCalledWith(
				`${base}/api/search?q=Lightning%20Bolt`,
				expect.any(Object)
			);
		});
	});

	it('should trigger search when search button is clicked', async () => {
		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(mockFetch).toHaveBeenCalledWith(
				`${base}/api/search?q=Sol%20Ring`,
				expect.any(Object)
			);
		});
	});

	it('should trim whitespace from search query before submission', async () => {
		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: '  Mana Crypt  ' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(mockFetch).toHaveBeenCalledWith(
				`${base}/api/search?q=Mana%20Crypt`,
				expect.any(Object)
			);
		});
	});
});

describe('Search Validation', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should show validation error for empty search query', async () => {
		render(SearchPage);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.click(button);

		expect(screen.getByText('Search query must be at least 2 characters')).toBeTruthy();
		expect(mockFetch).not.toHaveBeenCalled();
	});

	it('should show validation error for single character query', async () => {
		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'a' } });
		await fireEvent.click(button);

		expect(screen.getByText('Search query must be at least 2 characters')).toBeTruthy();
		expect(mockFetch).not.toHaveBeenCalled();
	});

	it('should allow search with 2 or more characters', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => ({
				query: 'ab',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'ab' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(mockFetch).toHaveBeenCalled();
		});
	});

	it('should clear validation error when user starts typing', async () => {
		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		// First trigger validation error
		await fireEvent.click(button);
		expect(screen.getByText('Search query must be at least 2 characters')).toBeTruthy();

		// Then start typing
		await fireEvent.input(input, { target: { value: 'a' } });

		// Error should be cleared
		expect(screen.queryByText('Search query must be at least 2 characters')).toBeFalsy();
	});
});

describe('Tab Navigation', () => {
	afterEach(() => {
		cleanup();
	});
	it('should change active tab when Decklists tab is clicked', async () => {
		render(SearchPage);
		const decklistsTab = screen.getByRole('tab', { name: 'Decklists' });

		await fireEvent.click(decklistsTab);

		expect(decklistsTab.getAttribute('aria-selected')).toBe('true');
		const allTab = screen.getByRole('tab', { name: 'All' });
		expect(allTab.getAttribute('aria-selected')).toBe('false');
	});

	it('should change active tab when Inventory tab is clicked', async () => {
		render(SearchPage);
		const inventoryTab = screen.getByRole('tab', { name: 'Inventory' });

		await fireEvent.click(inventoryTab);

		expect(inventoryTab.getAttribute('aria-selected')).toBe('true');
		const allTab = screen.getByRole('tab', { name: 'All' });
		expect(allTab.getAttribute('aria-selected')).toBe('false');
	});

	it('should persist tab selection after search', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => ({
				query: 'test',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});

		render(SearchPage);
		const decklistsTab = screen.getByRole('tab', { name: 'Decklists' });
		await fireEvent.click(decklistsTab);

		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'test' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(decklistsTab.getAttribute('aria-selected')).toBe('true');
		});
	});
});

describe('Loading States', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should show loading spinner during API request', async () => {
		let resolvePromise: (value: any) => void;
		const promise = new Promise((resolve) => {
			resolvePromise = resolve;
		});

		mockFetch.mockReturnValue(promise);

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'test' } });
		await fireEvent.click(button);

		// Loading spinner should appear
		await waitFor(() => {
			expect(screen.getByRole('status')).toBeTruthy();
		});

		// Resolve the promise
		resolvePromise!({
			ok: true,
			json: async () => ({
				query: 'test',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});

		// Loading spinner should disappear
		await waitFor(() => {
			expect(screen.queryByRole('status')).toBeFalsy();
		});
	});

	it('should disable search button during loading', async () => {
		let resolvePromise: (value: any) => void;
		const promise = new Promise((resolve) => {
			resolvePromise = resolve;
		});

		mockFetch.mockReturnValue(promise);

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'test' } });
		await fireEvent.click(button);

		// Button should be disabled
		await waitFor(() => {
			expect(button).toHaveProperty('disabled', true);
		});

		// Resolve the promise
		resolvePromise!({
			ok: true,
			json: async () => ({
				query: 'test',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});

		// Button should be enabled again
		await waitFor(() => {
			expect(button).toHaveProperty('disabled', false);
		});
	});

	it('should keep search input enabled during loading', async () => {
		let resolvePromise: (value: any) => void;
		const promise = new Promise((resolve) => {
			resolvePromise = resolve;
		});

		mockFetch.mockReturnValue(promise);

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		) as HTMLInputElement;
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'test' } });
		await fireEvent.click(button);

		// Input should remain enabled
		expect(input.disabled).toBe(false);

		// Resolve the promise
		resolvePromise!({
			ok: true,
			json: async () => ({
				query: 'test',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});
	});
});

describe('Empty States', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should show empty state message when no results are found', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => ({
				query: 'NonexistentCard',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'NonexistentCard' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText(/No results found for/)).toBeTruthy();
			expect(screen.getByText(/NonexistentCard/)).toBeTruthy();
		});
	});

	it('should show suggestion to try different search terms', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => ({
				query: 'xyz',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'xyz' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText(/Try different search terms/)).toBeTruthy();
		});
	});
});

describe('Error Handling', () => {
	beforeEach(() => {
		mockFetch.mockClear();
		// Suppress console.error for these tests
		vi.spyOn(console, 'error').mockImplementation(() => {});
	});

	afterEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	it('should show error message when API request fails', async () => {
		mockFetch.mockRejectedValue(new Error('Network error'));

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'test' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText('Search failed. Please try again.')).toBeTruthy();
		});
	});

	it('should show error message when API returns error response', async () => {
		mockFetch.mockResolvedValue({
			ok: false,
			status: 500
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'test' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText('Search failed. Please try again.')).toBeTruthy();
		});
	});

	it('should hide loading spinner when error occurs', async () => {
		mockFetch.mockRejectedValue(new Error('Network error'));

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'test' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.queryByRole('status')).toBeFalsy();
		});
	});

	it('should allow retry after error', async () => {
		// First request fails
		mockFetch.mockRejectedValueOnce(new Error('Network error'));
		// Second request succeeds
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => ({
				query: 'test',
				decklist_results: [],
				inventory_results: [],
				total_decklist_count: 0,
				total_inventory_count: 0
			} as SearchResults)
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		// First attempt
		await fireEvent.input(input, { target: { value: 'test' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText('Search failed. Please try again.')).toBeTruthy();
		});

		// Retry
		await fireEvent.click(button);

		await waitFor(() => {
			expect(mockFetch).toHaveBeenCalledTimes(2);
			expect(screen.queryByText('Search failed. Please try again.')).toBeFalsy();
		});
	});
});
