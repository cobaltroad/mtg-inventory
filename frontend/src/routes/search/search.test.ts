import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import SearchPage from './+page.svelte';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const MOCK_CARDS = [
	{ id: 'card-1', name: 'Lightning Bolt', mana_cost: '{R}' },
	{ id: 'card-2', name: 'Counterspell', mana_cost: '{U}{U}' }
];

function mockFetchForSearch(cards: typeof MOCK_CARDS = MOCK_CARDS) {
	return vi.fn().mockImplementation((url: string) => {
		if (typeof url === 'string' && url.includes('/api/cards/search')) {
			return Promise.resolve({
				ok: true,
				json: () => Promise.resolve({ cards })
			});
		}
		// Default fallback for any unexpected fetch
		return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
	});
}

async function searchForCards(mockFetch: ReturnType<typeof vi.fn>) {
	vi.stubGlobal('fetch', mockFetch);
	render(SearchPage);

	const input = screen.getByRole('textbox');
	await fireEvent.input(input, { target: { value: 'bolt' } });

	const button = screen.getByRole('button', { name: /search/i });
	await fireEvent.click(button);

	await waitFor(() => {
		expect(screen.getByText('Lightning Bolt')).toBeDefined();
	});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe('Card Search Page', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	it('renders Add to Inventory button on each search result', async () => {
		const mockFetch = mockFetchForSearch();
		await searchForCards(mockFetch);

		const addButtons = screen.getAllByRole('button', { name: /add to inventory/i });
		expect(addButtons).toHaveLength(2);
	});

	it('shows confirmation with quantity after successful add', async () => {
		let callCount = 0;
		const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
			if (typeof url === 'string' && url.includes('/api/cards/search')) {
				return Promise.resolve({
					ok: true,
					json: () => Promise.resolve({ cards: MOCK_CARDS })
				});
			}
			if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
				callCount++;
				return Promise.resolve({
					ok: true,
					json: () => Promise.resolve({ card_id: 'card-1', quantity: 1, collection_type: 'inventory' })
				});
			}
			return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
		});

		await searchForCards(mockFetch);

		// Click the first Add to Inventory button (for Lightning Bolt)
		const addButtons = screen.getAllByRole('button', { name: /add to inventory/i });
		await fireEvent.click(addButtons[0]);

		await waitFor(() => {
			expect(screen.getByText(/In Inventory: 1/)).toBeDefined();
		});
	});

	it('does not navigate away from the page after adding to inventory', async () => {
		const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
			if (typeof url === 'string' && url.includes('/api/cards/search')) {
				return Promise.resolve({
					ok: true,
					json: () => Promise.resolve({ cards: MOCK_CARDS })
				});
			}
			if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
				return Promise.resolve({
					ok: true,
					json: () => Promise.resolve({ card_id: 'card-1', quantity: 1, collection_type: 'inventory' })
				});
			}
			return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
		});

		await searchForCards(mockFetch);

		const addButtons = screen.getAllByRole('button', { name: /add to inventory/i });
		await fireEvent.click(addButtons[0]);

		await waitFor(() => {
			expect(screen.getByText(/In Inventory: 1/)).toBeDefined();
		});

		// The page heading and other search results must still be visible
		expect(screen.getByText('Card Search')).toBeDefined();
		expect(screen.getByText('Counterspell')).toBeDefined();
	});

	it('shows error message and retry button on API failure', async () => {
		const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
			if (typeof url === 'string' && url.includes('/api/cards/search')) {
				return Promise.resolve({
					ok: true,
					json: () => Promise.resolve({ cards: MOCK_CARDS })
				});
			}
			if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
				return Promise.resolve({
					ok: false,
					status: 422,
					json: () => Promise.resolve({ error: 'Card not found' })
				});
			}
			return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
		});

		await searchForCards(mockFetch);

		const addButtons = screen.getAllByRole('button', { name: /add to inventory/i });
		await fireEvent.click(addButtons[0]);

		await waitFor(() => {
			expect(screen.getByText(/Something went wrong\. Try again\./)).toBeDefined();
		});

		// The Add to Inventory button must still be available for retry
		const retryButtons = screen.getAllByRole('button', { name: /add to inventory/i });
		expect(retryButtons.length).toBeGreaterThanOrEqual(1);
	});
});
