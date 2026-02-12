import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/svelte';
import InventoryPage from './+page.svelte';

/**
 * RED PHASE: Test to reproduce the reported bug
 *
 * Bug Report:
 * - User has 38 unique cards in inventory
 * - Pagination should show (38 > 20 default page size)
 * - Pagination is not displaying
 *
 * This test should FAIL initially if the bug exists
 */

function generateRealWorldItems(count: number) {
	return Array.from({ length: count }, (_, i) => ({
		id: i + 1,
		card_id: `card-uuid-${i + 1}`,
		quantity: 1,
		card_name: `Real Card ${String.fromCharCode(65 + (i % 26))}${Math.floor(i / 26) + 1}`,
		set: i % 5 === 0 ? 'dmr' : 'mkm',
		set_name: i % 5 === 0 ? 'Dominaria Remastered' : 'Murders at Karlov Manor',
		collector_number: `${i + 1}`,
		released_at: '2024-01-12',
		image_url: `https://cards.scryfall.io/normal/front/card-${i + 1}.jpg`,
		image_cached: false,
		acquired_date: null,
		acquired_price_cents: null,
		finish: 'nonfoil',
		language: 'English',
		unit_price_cents: 150,
		total_price_cents: 150,
		price_updated_at: '2024-01-12T10:00:00Z',
		created_at: '2024-01-11T10:00:00Z',
		updated_at: '2024-01-11T10:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	}));
}

const EXACTLY_38_ITEMS = generateRealWorldItems(38);

// Mock context for search drawer
const mockContext = new Map([['openSearchDrawer', vi.fn()]]);

beforeEach(() => {
	vi.clearAllMocks();
	localStorage.clear();
});

afterEach(() => {
	cleanup();
});

describe('Pagination Bug - 38 Items Scenario', () => {
	it('BUG REPRODUCTION: should display pagination with exactly 38 items', async () => {
		console.log('Test: Rendering page with 38 items');

		render(InventoryPage, {
			props: {
				data: {
					items: EXACTLY_38_ITEMS
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Verify items are loaded
			const items = screen.getAllByRole('row');
			console.log(`Rendered ${items.length - 1} item rows (excluding header)`); // -1 for header row

			// Should display first 20 items only
			expect(items.length - 1).toBe(20); // -1 for header
		});

		// CRITICAL: Pagination controls MUST be visible
		await waitFor(() => {
			const nextButton = screen.queryByText('Next');
			const previousButton = screen.queryByText('Previous');
			const pageSizeSelect = screen.queryByRole('combobox', { name: /items per page/i });

			console.log('Next button found:', !!nextButton);
			console.log('Previous button found:', !!previousButton);
			console.log('Page size select found:', !!pageSizeSelect);

			// These should all exist when we have 38 items (38 > 20)
			expect(nextButton).toBeInTheDocument();
			expect(previousButton).toBeInTheDocument();
			expect(pageSizeSelect).toBeInTheDocument();
		}, { timeout: 3000 });
	});

	it('should display exactly 20 items on first page with 38 total', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: EXACTLY_38_ITEMS
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Count visible card rows (excluding header)
			const rows = screen.getAllByRole('row');
			const itemRows = rows.slice(1); // Remove header row

			console.log(`Displaying ${itemRows.length} items out of 38 total`);
			expect(itemRows.length).toBe(20);
		});
	});

	it('should show "38 cards" in the item count display', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: EXACTLY_38_ITEMS
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// The page should display "38 cards" in the count
			expect(screen.getByText(/38 cards/i)).toBeInTheDocument();
		});
	});

	it('should have showPagination evaluate to true with 38 items', async () => {
		// This test validates the core logic: filteredItems.length > pageSize
		// With 38 items and pageSize=20, showPagination should be true

		const { container } = render(InventoryPage, {
			props: {
				data: {
					items: EXACTLY_38_ITEMS
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// If pagination is working, the pagination-container should exist
			const paginationContainer = container.querySelector('.pagination-container');

			if (!paginationContainer) {
				console.error('BUG CONFIRMED: pagination-container not found in DOM');
				console.error('This means showPagination is evaluating to false');
				console.error('Expected: 38 > 20 = true');
				console.error('Actual: pagination not rendered');
			}

			expect(paginationContainer).not.toBeNull();
		});
	});
});
