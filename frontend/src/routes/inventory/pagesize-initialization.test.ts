import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/svelte';
import InventoryPage from './+page.svelte';

/**
 * Tests for pageSize initialization from localStorage
 *
 * Bug: pageSize was not properly defaulting to 20, causing pagination
 * to not appear when it should have (user had 51 items but needed pageSize=50
 * to see pagination).
 */

function generateItems(count: number) {
	return Array.from({ length: count }, (_, i) => ({
		id: i + 1,
		card_id: `card-${i + 1}`,
		quantity: 1,
		card_name: `Card ${String(i + 1).padStart(3, '0')}`,
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

describe.skip('PageSize Initialization', () => {
	it('should default to 20 items per page when no localStorage value exists', async () => {
		// Ensure no saved preference
		localStorage.clear();

		const items51 = generateItems(51);

		render(InventoryPage, {
			props: {
				data: {
					items: items51
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// With 51 items and default pageSize of 20:
			// - Should show pagination (51 > 20)
			// - Should display 20 items on page 1
			const pageSizeSelect = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
			expect(pageSizeSelect.value).toBe('20');

			// Pagination should be visible
			expect(screen.getByText('Next')).toBeInTheDocument();

			// Should display first 20 items only
			const rows = screen.getAllByRole('row');
			expect(rows.length - 1).toBe(20); // -1 for header
		});
	});

	it('should load valid saved pageSize from localStorage', async () => {
		// Save a valid page size preference
		localStorage.setItem('inventory-page-size', '50');

		const items51 = generateItems(51);

		render(InventoryPage, {
			props: {
				data: {
					items: items51
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should load saved value of 50
			const pageSizeSelect = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
			expect(pageSizeSelect.value).toBe('50');

			// With 51 items and pageSize 50, pagination should show (51 > 50)
			expect(screen.getByText('Next')).toBeInTheDocument();

			// Should display first 50 items
			const rows = screen.getAllByRole('row');
			expect(rows.length - 1).toBe(50); // -1 for header
		});
	});

	it('should fall back to 20 when localStorage has invalid value', async () => {
		// Save an invalid page size
		localStorage.setItem('inventory-page-size', '999');

		const items51 = generateItems(51);

		render(InventoryPage, {
			props: {
				data: {
					items: items51
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should fall back to default of 20 (999 is not in [20, 50, 100])
			const pageSizeSelect = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
			expect(pageSizeSelect.value).toBe('20');

			// Pagination should be visible with 51 items
			expect(screen.getByText('Next')).toBeInTheDocument();
		});
	});

	it('should fall back to 20 when localStorage has non-numeric value', async () => {
		// Save garbage
		localStorage.setItem('inventory-page-size', 'invalid');

		const items51 = generateItems(51);

		render(InventoryPage, {
			props: {
				data: {
					items: items51
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should fall back to default of 20 (NaN is not in [20, 50, 100])
			const pageSizeSelect = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
			expect(pageSizeSelect.value).toBe('20');
		});
	});

	it('should show pagination immediately with 51 items and default pageSize 20', async () => {
		// This is the exact bug scenario reported
		localStorage.clear();

		const items51 = generateItems(51);

		render(InventoryPage, {
			props: {
				data: {
					items: items51
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Pagination MUST appear immediately (51 > 20 = true)
			const nextButton = screen.queryByText('Next');
			const pageSizeSelect = screen.queryByRole('combobox', { name: /items per page/i });

			if (!nextButton || !pageSizeSelect) {
				console.error('🐛 BUG REPRODUCED: Pagination not showing with 51 items and pageSize=20');
				console.error('   This was the original bug - pageSize not defaulting to 20');
			}

			expect(nextButton).toBeInTheDocument();
			expect(pageSizeSelect).toBeInTheDocument();
		});
	});

	it('should respect all valid localStorage values [20, 50, 100]', async () => {
		// Use 101 items so pagination shows for all page sizes (20, 50, 100)
		const items = generateItems(101);

		for (const validSize of [20, 50, 100]) {
			localStorage.setItem('inventory-page-size', String(validSize));

			const { unmount } = render(InventoryPage, {
				props: {
					data: {
						items
					}
				},
				context: mockContext
			});

			await waitFor(() => {
				const pageSizeSelect = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
				expect(pageSizeSelect.value).toBe(String(validSize));
			});

			unmount();
		}
	});
});
