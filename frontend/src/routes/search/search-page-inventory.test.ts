import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import SearchPage from './+page.svelte';
import type { SearchResults } from '$lib/types/search';

/**
 * TDD Tests for Search Page - Inventory Display (Issue #110)
 * Following red-green-refactor cycle
 *
 * These tests verify:
 * - Inventory results rendering
 * - Tab filtering for inventory
 * - Empty states for inventory
 * - Card images display
 * - Price formatting
 * - Treatment display
 * - PrintingModal integration
 */

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

const MOCK_RESULTS_WITH_INVENTORY: SearchResults = {
	query: 'Lightning Bolt',
	total_results: 3,
	results: {
		decklists: [],
		inventory: [
			{
				id: 1,
				card_id: 'lightning-bolt-lea',
				card_name: 'Lightning Bolt',
				set: 'lea',
				set_name: 'Limited Edition Alpha',
				collector_number: '161',
				quantity: 4,
				image_url: 'https://cards.scryfall.io/normal/lea-161.jpg',
				treatment: 'Foil',
				unit_price_cents: 500,
				total_price_cents: 2000
			},
			{
				id: 2,
				card_id: 'lightning-bolt-m10',
				card_name: 'Lightning Bolt',
				set: 'm10',
				set_name: 'Magic 2010',
				collector_number: '222',
				quantity: 2,
				image_url: 'https://cards.scryfall.io/normal/m10-222.jpg',
				treatment: 'Non-Foil',
				unit_price_cents: 50,
				total_price_cents: 100
			},
			{
				id: 3,
				card_id: 'lightning-bolt-no-price',
				card_name: 'Lightning Bolt',
				set: 'test',
				set_name: 'Test Set',
				collector_number: '1',
				quantity: 1,
				image_url: 'https://cards.scryfall.io/normal/test-1.jpg'
			}
		]
	}
};

const MOCK_RESULTS_NO_INVENTORY: SearchResults = {
	query: 'Rare Commander',
	total_results: 1,
	results: {
		decklists: [
			{
				commander_id: 1,
				commander_name: 'Rare Commander',
				commander_rank: 100,
				card_matches: [],
				match_count: 0
			}
		],
		inventory: []
	}
};

const MOCK_RESULTS_MIXED: SearchResults = {
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
			}
		],
		inventory: [
			{
				id: 4,
				card_id: 'sol-ring-id',
				card_name: 'Sol Ring',
				set: 'lea',
				set_name: 'Limited Edition Alpha',
				collector_number: '268',
				quantity: 1,
				image_url: 'https://cards.scryfall.io/normal/lea-268.jpg',
				unit_price_cents: 1000,
				total_price_cents: 1000
			}
		]
	}
};

describe('Search Page - Inventory Results Rendering', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should render inventory results when search returns inventory items', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText('Limited Edition Alpha')).toBeInTheDocument();
			expect(screen.getByText('Magic 2010')).toBeInTheDocument();
		});
	});

	it('should display card name in inventory results', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			const cardNames = screen.getAllByText('Lightning Bolt');
			// Should find multiple instances (one per inventory item)
			expect(cardNames.length).toBeGreaterThanOrEqual(3);
		});
	});

	it('should display set code and collector number in inventory results', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText(/LEA/i)).toBeInTheDocument();
			expect(screen.getByText(/#161/i)).toBeInTheDocument();
			expect(screen.getByText(/M10/i)).toBeInTheDocument();
			expect(screen.getByText(/#222/i)).toBeInTheDocument();
		});
	});

	it('should display quantity owned in inventory results', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText(/Qty.*4/i)).toBeInTheDocument();
			expect(screen.getByText(/Qty.*2/i)).toBeInTheDocument();
			expect(screen.getByText(/Qty.*1/i)).toBeInTheDocument();
		});
	});

	it('should display treatment type in inventory results', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText('Foil')).toBeInTheDocument();
			expect(screen.getByText('Non-Foil')).toBeInTheDocument();
		});
	});

	it('should display card images in inventory results', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			const images = screen.getAllByRole('img', { name: /Lightning Bolt/i });
			expect(images.length).toBeGreaterThanOrEqual(3);
			expect(images[0]).toHaveAttribute(
				'src',
				'https://cards.scryfall.io/normal/lea-161.jpg'
			);
		});
	});

	it('should include View Details button for each inventory item', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			const viewButtons = screen.getAllByRole('button', { name: /View Details/i });
			expect(viewButtons.length).toBe(3);
		});
	});
});

describe('Search Page - Inventory Price Formatting', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should format unit price correctly with dollar sign and decimals', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText(/\$5\.00/)).toBeInTheDocument();
			expect(screen.getByText(/\$0\.50/)).toBeInTheDocument();
		});
	});

	it('should format total price correctly', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText(/\$20\.00/)).toBeInTheDocument();
			expect(screen.getByText(/\$1\.00/)).toBeInTheDocument();
		});
	});

	it('should display placeholder for missing prices', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			const placeholders = screen.getAllByText('—');
			expect(placeholders.length).toBeGreaterThanOrEqual(2); // unit price and total price for item without price
		});
	});
});

describe('Search Page - Tab Filtering for Inventory', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should show only inventory results when Inventory tab is active', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_MIXED
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		const inventoryTab = screen.getByRole('tab', { name: /Inventory/i });
		await fireEvent.click(inventoryTab);

		await waitFor(() => {
			// Inventory section should be visible
			expect(screen.getByText('Inventory', { selector: '.section-heading' })).toBeInTheDocument();
			// Decklist section should NOT be visible
			expect(
				screen.queryByText('Decklists', { selector: '.section-heading' })
			).not.toBeInTheDocument();
			expect(screen.queryByText("Atraxa, Praetors' Voice")).not.toBeInTheDocument();
		});
	});

	it('should hide inventory results when Decklists tab is active', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_MIXED
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Sol Ring' } });
		await fireEvent.click(button);

		const decklistsTab = screen.getByRole('tab', { name: /Decklists/i });
		await fireEvent.click(decklistsTab);

		await waitFor(() => {
			// Inventory section should NOT be visible
			expect(
				screen.queryByText('Inventory', { selector: '.section-heading' })
			).not.toBeInTheDocument();
			// Decklist results should be visible
			expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
		});
	});

	it('should display count in Inventory tab', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByRole('tab', { name: /Inventory.*3/i })).toBeInTheDocument();
		});
	});
});

describe('Search Page - Inventory Empty States', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should show empty state in Inventory tab when no inventory found', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_NO_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Rare Commander' } });
		await fireEvent.click(button);

		const inventoryTab = screen.getByRole('tab', { name: /Inventory/i });
		await fireEvent.click(inventoryTab);

		await waitFor(() => {
			expect(screen.getByText(/No inventory items found matching/i)).toBeInTheDocument();
			expect(screen.getByText(/Rare Commander/i)).toBeInTheDocument();
		});
	});

	it('should not show empty state in All tab when decklist results exist', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_NO_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Rare Commander' } });
		await fireEvent.click(button);

		await waitFor(() => {
			// Should show decklist results, not inventory empty state
			expect(screen.queryByText(/No inventory items found matching/i)).not.toBeInTheDocument();
			expect(screen.getByText('Rare Commander')).toBeInTheDocument();
		});
	});
});

describe('Search Page - PrintingModal Integration', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	afterEach(() => {
		cleanup();
	});

	it('should open PrintingModal when View Details is clicked', async () => {
		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => MOCK_RESULTS_WITH_INVENTORY
		});

		render(SearchPage);
		const input = screen.getByPlaceholderText(
			'Enter a card name to search across decklists and inventory'
		);
		const button = screen.getByRole('button', { name: /search/i });

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		await fireEvent.click(button);

		await waitFor(async () => {
			const viewButtons = screen.getAllByRole('button', { name: /View Details/i });
			expect(viewButtons.length).toBeGreaterThan(0);

			// Mock the printings endpoint
			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => ({
					printings: [
						{
							id: 'lightning-bolt-lea',
							name: 'Lightning Bolt',
							set: 'lea',
							set_name: 'Limited Edition Alpha',
							collector_number: '161',
							image_url: 'https://cards.scryfall.io/normal/lea-161.jpg',
							released_at: '1993-08-05'
						}
					]
				})
			});

			await fireEvent.click(viewButtons[0]);
		});

		await waitFor(() => {
			expect(screen.getByRole('dialog')).toBeInTheDocument();
			expect(screen.getByText(/Lightning Bolt.*Printings/i)).toBeInTheDocument();
		});
	});
});
