import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';

import SearchPage from './+page.svelte';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const MOCK_CARD = { id: 'card-base-1', name: 'Basepath Bolt', mana_cost: '{R}' };

/**
 * Build a fetch stub that:
 *  - responds to /api/cards/search with a single card
 *  - responds to POST /api/inventory with a success payload
 * We capture every call so we can assert on the full URL later.
 */
function createFetchSpy() {
	return vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
		if (typeof url === 'string' && url.includes('/api/cards/search')) {
			return Promise.resolve({
				ok: true,
				json: () => Promise.resolve({ cards: [MOCK_CARD] })
			});
		}
		if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
			return Promise.resolve({
				ok: true,
				json: () => Promise.resolve({ card_id: MOCK_CARD.id, quantity: 1, collection_type: 'inventory' })
			});
		}
		return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
	});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe('Card Search Page – API path behavior', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	it('makes search requests to /api/cards/search without a client-side prefix', async () => {
		const fetchSpy = createFetchSpy();
		vi.stubGlobal('fetch', fetchSpy);

		render(SearchPage);

		const input = screen.getByRole('textbox');
		await fireEvent.input(input, { target: { value: 'basepath' } });

		const button = screen.getByRole('button', { name: /search/i });
		await fireEvent.click(button);

		await waitFor(() => {
			expect(screen.getByText('Basepath Bolt')).toBeDefined();
		});

		// The search fetch should be called with just /api/cards/search (no prefix)
		// The server-side hooks.server.ts handles adding the API_BASE_PATH
		const searchCall = fetchSpy.mock.calls.find(
			(call) => typeof call[0] === 'string' && call[0].includes('/api/cards/search')
		);
		expect(searchCall).toBeDefined();
		expect(searchCall![0]).toMatch(/^\/api\/cards\/search/);
	});

	it('makes inventory POST requests to /api/inventory without a client-side prefix', async () => {
		const fetchSpy = createFetchSpy();
		vi.stubGlobal('fetch', fetchSpy);

		render(SearchPage);

		// Perform a search first so results appear
		const input = screen.getByRole('textbox');
		await fireEvent.input(input, { target: { value: 'basepath' } });

		const searchBtn = screen.getByRole('button', { name: /search/i });
		await fireEvent.click(searchBtn);

		await waitFor(() => {
			expect(screen.getByText('Basepath Bolt')).toBeDefined();
		});

		// Click "Add to Inventory"
		const addBtn = screen.getByRole('button', { name: /add to inventory/i });
		await fireEvent.click(addBtn);

		await waitFor(() => {
			expect(screen.getByText(/In Inventory: 1/)).toBeDefined();
		});

		// The inventory POST should be called with just /api/inventory (no prefix)
		// The server-side hooks.server.ts handles adding the API_BASE_PATH
		const inventoryCall = fetchSpy.mock.calls.find(
			(call) =>
				typeof call[0] === 'string' &&
				call[0].includes('/api/inventory') &&
				(call[1] as RequestInit)?.method === 'POST'
		);
		expect(inventoryCall).toBeDefined();
		expect(inventoryCall![0]).toMatch(/^\/api\/inventory$/);
	});
});
