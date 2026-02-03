import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/svelte';
import InventoryPage from './+page.svelte';

// ---------------------------------------------------------------------------
// Mock Data
// ---------------------------------------------------------------------------
const MOCK_INVENTORY_ITEMS = [
	{
		id: 1,
		card_id: 'uuid-123',
		quantity: 3,
		card_name: 'Black Lotus',
		set: 'lea',
		set_name: 'Limited Edition Alpha',
		collector_number: '234',
		image_url: 'https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg',
		acquired_date: '2025-01-15',
		acquired_price_cents: 5000,
		treatment: 'Foil',
		language: 'English',
		created_at: '2025-01-15T10:00:00Z',
		updated_at: '2025-01-15T10:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	},
	{
		id: 2,
		card_id: 'uuid-456',
		quantity: 1,
		card_name: 'Ancestral Recall',
		set: 'lea',
		set_name: 'Limited Edition Alpha',
		collector_number: '48',
		image_url: 'https://cards.scryfall.io/normal/front/a/r/ancestral-recall.jpg',
		acquired_date: null,
		acquired_price_cents: null,
		treatment: null,
		language: null,
		created_at: '2025-01-16T10:00:00Z',
		updated_at: '2025-01-16T10:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	}
];

// ---------------------------------------------------------------------------
// Test Setup
// ---------------------------------------------------------------------------
function mockSuccessfulFetch(items = MOCK_INVENTORY_ITEMS) {
	return vi.fn().mockImplementation((url: string) => {
		if (typeof url === 'string' && url.includes('/api/inventory')) {
			return Promise.resolve({
				ok: true,
				json: () => Promise.resolve(items)
			});
		}
		return Promise.reject(new Error('Unhandled fetch'));
	});
}

function mockFailedFetch(errorMessage = 'Server error') {
	return vi.fn().mockImplementation((url: string) => {
		if (typeof url === 'string' && url.includes('/api/inventory')) {
			return Promise.resolve({
				ok: false,
				statusText: errorMessage,
				json: () => Promise.resolve([])
			});
		}
		return Promise.reject(new Error('Unhandled fetch'));
	});
}

beforeEach(() => {
	vi.clearAllMocks();
});

afterEach(() => {
	cleanup();
});

// ---------------------------------------------------------------------------
// Tests: Loading State
// ---------------------------------------------------------------------------
describe('Inventory Page - Loading State', () => {
	it('displays loading spinner when fetching inventory', async () => {
		const slowFetch = vi.fn().mockImplementation(() => {
			return new Promise(() => {}); // Never resolves
		});
		global.fetch = slowFetch;

		render(InventoryPage);

		expect(screen.getByText('Loading your inventory...')).toBeInTheDocument();
		expect(document.querySelector('.spinner')).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Empty State
// ---------------------------------------------------------------------------
describe('Inventory Page - Empty State', () => {
	it('displays empty state when inventory has no items', async () => {
		global.fetch = mockSuccessfulFetch([]);

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.getByText('Your inventory is empty')).toBeInTheDocument();
		});

		expect(
			screen.getByText('Start building your collection by searching for cards and adding them to your inventory.')
		).toBeInTheDocument();
		expect(screen.getByText('Search for Cards')).toBeInTheDocument();
	});

	it('empty state has a link to search page', async () => {
		global.fetch = mockSuccessfulFetch([]);

		render(InventoryPage);

		await waitFor(() => {
			const link = screen.getByText('Search for Cards');
			expect(link.closest('a')).toHaveAttribute('href', '/search');
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Successful Data Display
// ---------------------------------------------------------------------------
describe('Inventory Page - Data Display', () => {
	it('displays inventory items when data is loaded', async () => {
		global.fetch = mockSuccessfulFetch();

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
			expect(screen.getByText('Ancestral Recall')).toBeInTheDocument();
		});
	});

	it('displays correct item count in header', async () => {
		global.fetch = mockSuccessfulFetch();

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.getByText('2 cards')).toBeInTheDocument();
		});
	});

	it('displays singular "card" when inventory has one item', async () => {
		global.fetch = mockSuccessfulFetch([MOCK_INVENTORY_ITEMS[0]]);

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.getByText('1 card')).toBeInTheDocument();
		});
	});

	it('displays card details including set and collector number', async () => {
		global.fetch = mockSuccessfulFetch();

		render(InventoryPage);

		await waitFor(() => {
			// Both items are from the same set
			const setElements = screen.getAllByText('Limited Edition Alpha (LEA)');
			expect(setElements.length).toBe(2);
			expect(screen.getByText('#234')).toBeInTheDocument();
			expect(screen.getByText('#48')).toBeInTheDocument();
		});
	});

	it('displays quantity for each item', async () => {
		global.fetch = mockSuccessfulFetch();

		render(InventoryPage);

		await waitFor(() => {
			const quantityElements = screen.getAllByText(/Quantity:/);
			expect(quantityElements.length).toBeGreaterThan(0);
		});
	});

	it('displays enhanced tracking fields when present', async () => {
		global.fetch = mockSuccessfulFetch();

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.getByText('Foil')).toBeInTheDocument();
			expect(screen.getByText('Acquired: 2025-01-15')).toBeInTheDocument();
			expect(screen.getByText('Price: $50.00')).toBeInTheDocument();
		});
	});

	it('does not display enhanced fields when not present', async () => {
		global.fetch = mockSuccessfulFetch([MOCK_INVENTORY_ITEMS[1]]);

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.queryByText('Foil')).not.toBeInTheDocument();
			expect(screen.queryByText(/Acquired:/)).not.toBeInTheDocument();
			expect(screen.queryByText(/Price:/)).not.toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Error Handling
// ---------------------------------------------------------------------------
describe('Inventory Page - Error Handling', () => {
	it('displays error message when fetch fails', async () => {
		global.fetch = mockFailedFetch('Internal Server Error');

		render(InventoryPage);

		await waitFor(() => {
			expect(
				screen.getByText(/Failed to fetch inventory: Internal Server Error/)
			).toBeInTheDocument();
		});
	});

	it('displays retry button on error', async () => {
		global.fetch = mockFailedFetch();

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.getByText('Try Again')).toBeInTheDocument();
		});
	});

	it('retries fetch when retry button is clicked', async () => {
		const fetchMock = mockFailedFetch();
		global.fetch = fetchMock;

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.getByText('Try Again')).toBeInTheDocument();
		});

		// Initially fetched once
		expect(fetchMock).toHaveBeenCalledTimes(1);

		// Click retry
		const retryButton = screen.getByText('Try Again');
		await retryButton.click();

		// Should fetch again
		expect(fetchMock).toHaveBeenCalledTimes(2);
	});
});

// ---------------------------------------------------------------------------
// Tests: Image Lazy Loading
// ---------------------------------------------------------------------------
describe('Inventory Page - Image Lazy Loading', () => {
	it('card images have loading="lazy" attribute', async () => {
		global.fetch = mockSuccessfulFetch();

		render(InventoryPage);

		await waitFor(() => {
			const images = document.querySelectorAll('img');
			images.forEach((img) => {
				if (img.alt === 'Black Lotus' || img.alt === 'Ancestral Recall') {
					expect(img).toHaveAttribute('loading', 'lazy');
				}
			});
		});
	});

	it('displays placeholder before image loads', async () => {
		global.fetch = mockSuccessfulFetch();

		render(InventoryPage);

		await waitFor(() => {
			expect(screen.getAllByText('Loading...').length).toBeGreaterThan(0);
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: API Integration
// ---------------------------------------------------------------------------
describe('Inventory Page - API Integration', () => {
	it('fetches from correct API endpoint', async () => {
		const fetchMock = mockSuccessfulFetch();
		global.fetch = fetchMock;

		render(InventoryPage);

		await waitFor(() => {
			expect(fetchMock).toHaveBeenCalledWith('/api/inventory');
		});
	});

	it('fetches inventory on mount', async () => {
		const fetchMock = mockSuccessfulFetch();
		global.fetch = fetchMock;

		render(InventoryPage);

		await waitFor(() => {
			expect(fetchMock).toHaveBeenCalled();
		});
	});
});
