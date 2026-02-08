import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import { base } from '$app/paths';
import SearchPage from './+page.svelte';
import type { SearchResults } from '$lib/types/search';

/**
 * TDD Tests for Search Page - Decklist Display (Issue #109)
 * Following red-green-refactor cycle
 *
 * These tests verify:
 * - Decklist results rendering
 * - Tab filtering for decklists
 * - Empty states for decklists
 * - Tab counts display
 */

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

const MOCK_RESULTS_WITH_DECKLISTS: SearchResults = {
	query: 'Sol Ring',
	total_results: 3,
	results: {
		decklists: [
			{
				commander_id: 1,
				commander_name: "Atraxa, Praetors' Voice",
				commander_rank: 5,
				card_matches: [{ card_name: 'Sol Ring', quantity: 1 }],
				match_count: 1
			},
			{
				commander_id: 2,
				commander_name: 'Chulane, Teller of Tales',
				commander_rank: 12,
				card_matches: [
					{ card_name: 'Sol Ring', quantity: 1 },
					{ card_name: 'Mana Crypt', quantity: 1 }
				],
				match_count: 2
			}
		],
		inventory: [
			{
				id: 1,
				card_id: 'sol-ring-id',
				card_name: 'Sol Ring',
				set: 'lea',
				set_name: 'Limited Edition Alpha',
				collector_number: '268',
				quantity: 1,
				image_url: 'https://cards.scryfall.io/normal/test.jpg'
			}
		]
	}
};

const MOCK_RESULTS_DECKLISTS_ONLY: SearchResults = {
	query: 'Lightning Bolt',
	total_results: 2,
	results: {
		decklists: [
			{
				commander_id: 3,
				commander_name: 'The Ur-Dragon',
				commander_rank: 20,
				card_matches: [{ card_name: 'Lightning Bolt', quantity: 1 }],
				match_count: 1
			},
			{
				commander_id: 4,
				commander_name: 'Kaalia of the Vast',
				commander_rank: 8,
				card_matches: [{ card_name: 'Lightning Bolt', quantity: 1 }],
				match_count: 1
			}
		],
		inventory: []
	}
};

const MOCK_RESULTS_NO_DECKLISTS: SearchResults = {
	query: 'Rare Card',
	total_results: 1,
	results: {
		decklists: [],
		inventory: [
			{
				id: 2,
				card_id: 'rare-card-id',
				card_name: 'Rare Card',
				set: 'test',
				set_name: 'Test Set',
				collector_number: '1',
				quantity: 1
			}
		]
	}
};

describe('Search Page - Decklist Results Rendering', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should render decklist results when search returns decklists', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			expect(screen.getByText('Chulane, Teller of Tales')).toBeInTheDocument();
		});
	});

	it('should display commander ranks in decklist results', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText('Rank #5')).toBeInTheDocument();
			expect(screen.getByText('Rank #12')).toBeInTheDocument();
		});
	});

	it('should display match counts in decklist results', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText(/1 match/i)).toBeInTheDocument();
			expect(screen.getByText(/2 matches/i)).toBeInTheDocument();
		});
	});

	it('should render commander names as links to detail pages', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			const links = screen.getAllByRole('link', { name: /Atraxa, Praetors' Voice/i });
			expect(links.length).toBeGreaterThan(0);
			expect(links[0]).toHaveAttribute('href', `${base}/metagame/edh/1`);
		});
	});

	it('should display both decklist and inventory results in All tab', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			// Decklist results
			expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			// Inventory results should also be visible
			expect(screen.getByText('Sol Ring')).toBeInTheDocument();
		});
	});
});

describe('Search Page - Tab Filtering for Decklists', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should show only decklist results when Decklists tab is active', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
		});

		const decklistsTab = screen.getByRole('tab', { name: 'Decklists' });
		await fireEvent.click(decklistsTab);

		await waitFor(() => {
			// Decklist results should be visible
			expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			expect(screen.getByText('Chulane, Teller of Tales')).toBeInTheDocument();
		});
	});

	it('should hide decklist results when Inventory tab is active', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
		});

		const inventoryTab = screen.getByRole('tab', { name: 'Inventory' });
		await fireEvent.click(inventoryTab);

		await waitFor(() => {
			// Decklist results should NOT be visible
			expect(screen.queryByText("Atraxa, Praetors' Voice")).not.toBeInTheDocument();
			expect(screen.queryByText('Chulane, Teller of Tales')).not.toBeInTheDocument();
		});
	});

	it('should show both results when switching back to All tab', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		const decklistsTab = screen.getByRole('tab', { name: 'Decklists' });
		await fireEvent.click(decklistsTab);

		const allTab = screen.getByRole('tab', { name: 'All' });
		await fireEvent.click(allTab);

		await waitFor(() => {
			// Both types of results should be visible
			expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			expect(screen.getByText('Sol Ring')).toBeInTheDocument();
		});
	});
});

describe('Search Page - Tab Counts', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should display count in Decklists tab', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByRole('tab', { name: /Decklists.*2/i })).toBeInTheDocument();
		});
	});

	it('should display count in All tab', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByRole('tab', { name: /All.*3/i })).toBeInTheDocument();
		});
	});

	it('should display zero count when no decklists found', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_NO_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Rare Card' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByRole('tab', { name: /Decklists.*0/i })).toBeInTheDocument();
		});
	});
});

describe('Search Page - Decklist Empty States', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should show empty state in Decklists tab when no decklists found', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_NO_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Rare Card' } });
		await fireEvent.click(button);

		const decklistsTab = screen.getByRole('tab', { name: /Decklists/i });
		await fireEvent.click(decklistsTab);

		await waitFor(() => {
			expect(screen.getByText(/No commanders found matching/i)).toBeInTheDocument();
			expect(screen.getByText(/Rare Card/i)).toBeInTheDocument();
		});
	});

	it('should not show empty state in All tab when inventory results exist', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_NO_DECKLISTS
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Rare Card' } });
		await fireEvent.click(button);

		await waitFor(() => {
			// Should show inventory results, not empty state
			expect(screen.queryByText(/No commanders found matching/i)).not.toBeInTheDocument();
		});
	});
});
