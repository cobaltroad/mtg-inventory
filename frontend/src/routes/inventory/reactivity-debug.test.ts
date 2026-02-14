import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/svelte';
import InventoryPage from './+page.svelte';

/**
 * RED PHASE: Test to verify reactive chain updates correctly
 *
 * This test validates that when data.items changes from empty to 38 items,
 * all derived states update correctly and pagination appears.
 */

function generateItems(count: number) {
	return Array.from({ length: count }, (_, i) => ({
		id: i + 1,
		card_id: `card-${i + 1}`,
		quantity: 1,
		card_name: `Card ${i + 1}`,
		set: 'tst',
		set_name: 'Test Set',
		collector_number: `${i + 1}`,
		released_at: '2024-01-01',
		image_url: `https://example.com/${i + 1}.jpg`,
		image_cached: false,
		acquired_date: null,
		acquired_price_cents: null,
		finish: 'nonfoil',
		language: 'English',
		unit_price_cents: 100,
		total_price_cents: 100,
		price_updated_at: '2024-01-01T10:00:00Z',
		created_at: '2024-01-01T09:00:00Z',
		updated_at: '2024-01-01T09:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	}));
}

const mockContext = new Map([['openSearchDrawer', vi.fn()]]);

beforeEach(() => {
	vi.clearAllMocks();
	localStorage.clear();
});

afterEach(() => {
	cleanup();
});

describe('Reactivity Chain - Data Loading', () => {
	it('should display pagination when data loads with 38 items', async () => {
		const items = generateItems(38);

		const { component } = render(InventoryPage, {
			props: {
				data: {
					items: items
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Verify items are rendered
			expect(screen.getByText('Card 1')).toBeInTheDocument();
		});

		await waitFor(() => {
			// Pagination should appear
			const nextButton = screen.queryByText('Next');
			const pageSizeSelect = screen.queryByRole('combobox', { name: /items per page/i });

			if (!nextButton || !pageSizeSelect) {
				// Debug: check what's in the DOM
				const rows = screen.getAllByRole('row');
				console.error('Pagination not found! Debug info:');
				console.error(`- Total rows rendered: ${rows.length - 1}`); // -1 for header
				console.error(`- Expected: 20 rows (first page)`);
				console.error(`- Actual: All ${items.length} items showing = pagination not working`);
			}

			expect(nextButton).toBeInTheDocument();
			expect(pageSizeSelect).toBeInTheDocument();
		}, { timeout: 3000 });
	});

	it('should only render 20 items when 38 are loaded', async () => {
		const items = generateItems(38);

		render(InventoryPage, {
			props: {
				data: {
					items: items
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Count table rows (excluding header)
			const rows = screen.getAllByRole('row');
			const dataRows = rows.slice(1); // Remove header

			console.log(`Expected: 20 rows, Actual: ${dataRows.length} rows`);

			// Should only show first page (20 items)
			expect(dataRows.length).toBe(20);
		});
	});

	it('should have displayItems with length 20 when total is 38', async () => {
		// This tests the slice logic directly
		const items = generateItems(38);

		const { container } = render(InventoryPage, {
			props: {
				data: {
					items: items
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Find all table body rows
			const tbody = container.querySelector('tbody');
			expect(tbody).not.toBeNull();

			const rows = tbody?.querySelectorAll('tr');
			console.log(`displayItems should have 20 items. Table has ${rows?.length || 0} rows`);

			expect(rows?.length).toBe(20);
		});
	});
});

describe('Reactivity Chain - Empty to Full', () => {
	it('should handle transition from empty data to 38 items', async () => {
		// Start with empty data (simulates initial page load)
		const { rerender } = render(InventoryPage, {
			props: {
				data: {
					items: []
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText(/Your inventory is empty/i)).toBeInTheDocument();
		});

		// Simulate data loading (API response arrives)
		await rerender({
			data: {
				items: generateItems(38)
			}
		});

		await waitFor(() => {
			// Should now show inventory table
			expect(screen.queryByText(/Your inventory is empty/i)).not.toBeInTheDocument();
			expect(screen.getByText('Card 1')).toBeInTheDocument();
		});

		await waitFor(() => {
			// Pagination should appear after data loads
			const nextButton = screen.queryByText('Next');
			expect(nextButton).toBeInTheDocument();

			// Should only show 20 items
			const rows = screen.getAllByRole('row');
			expect(rows.length - 1).toBe(20); // -1 for header
		}, { timeout: 3000 });
	});
});
