import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup, fireEvent } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import InventoryPage from './+page.svelte';

// ---------------------------------------------------------------------------
// Mock Data - Generate large dataset for pagination testing
// ---------------------------------------------------------------------------
function generateMockItems(count: number) {
	return Array.from({ length: count }, (_, i) => ({
		id: i + 1,
		card_id: `uuid-${i + 1}`,
		quantity: Math.floor(Math.random() * 4) + 1,
		card_name: `Test Card ${i + 1}`,
		set: 'tst',
		set_name: 'Test Set',
		collector_number: `${i + 1}`,
		released_at: '2025-01-01',
		image_url: `https://example.com/card-${i + 1}.jpg`,
		acquired_date: null,
		acquired_price_cents: null,
		treatment: null,
		language: null,
		created_at: '2025-01-01T10:00:00Z',
		updated_at: '2025-01-01T10:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	}));
}

const MOCK_LARGE_INVENTORY = generateMockItems(150); // 150 items for pagination testing

// Mock context for search drawer
const mockContext = new Map([['openSearchDrawer', vi.fn()]]);

beforeEach(() => {
	vi.clearAllMocks();
	// Clear localStorage before each test
	localStorage.clear();
});

afterEach(() => {
	cleanup();
});

// ---------------------------------------------------------------------------
// RED PHASE: Tests for BDD Acceptance Criteria
// These tests SHOULD FAIL initially - we haven't implemented pagination yet
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Scenario 1: Default pagination behavior
// ---------------------------------------------------------------------------
describe('Pagination - Default Behavior', () => {
	it('displays only first 20 items by default when inventory has more than 20 items', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should see first 20 cards
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 20')).toBeInTheDocument();

			// Should NOT see card 21 or beyond on first page
			expect(screen.queryByText('Test Card 21')).not.toBeInTheDocument();
			expect(screen.queryByText('Test Card 150')).not.toBeInTheDocument();
		});
	});

	it('displays pagination controls when inventory has more than 20 items', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Pagination component should be visible
			expect(screen.getByText('Next')).toBeInTheDocument();
			expect(screen.getByText('Previous')).toBeInTheDocument();
		});
	});

	it('does not display pagination controls when inventory has 20 or fewer items', async () => {
		const smallInventory = generateMockItems(20);

		render(InventoryPage, {
			props: {
				data: {
					items: smallInventory
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// All 20 items should be visible
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 20')).toBeInTheDocument();
		});

		// No pagination controls should exist
		expect(screen.queryByText('Next')).not.toBeInTheDocument();
		expect(screen.queryByText('Previous')).not.toBeInTheDocument();
	});

	it('shows correct page indicator "Page 1 of X"', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY // 150 items = 8 pages at 20 per page
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should show "Page 1 of 8" or similar format
			const pageText = screen.getByText(/Page 1/);
			expect(pageText).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 2: Page size selector
// ---------------------------------------------------------------------------
describe('Pagination - Page Size Selector', () => {
	it('displays page size selector with options 20, 50, 100', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Page size selector should be present
			const select = screen.getByRole('combobox', { name: /items per page/i });
			expect(select).toBeInTheDocument();

			// Should have options for 20, 50, 100
			expect(select).toContainHTML('20');
			expect(select).toContainHTML('50');
			expect(select).toContainHTML('100');
		});
	});

	it('defaults to 20 items per page', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const select = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
			expect(select.value).toBe('20');
		});
	});

	it('displays 50 items per page when page size is changed to 50', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
		});

		// Change page size to 50
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '50');

		await waitFor(() => {
			// Should now see first 50 items
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 50')).toBeInTheDocument();

			// Should NOT see item 51
			expect(screen.queryByText('Test Card 51')).not.toBeInTheDocument();
		});
	});

	it('displays 100 items per page when page size is changed to 100', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
		});

		// Change page size to 100
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '100');

		await waitFor(() => {
			// Should now see first 100 items
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 100')).toBeInTheDocument();

			// Should NOT see item 101
			expect(screen.queryByText('Test Card 101')).not.toBeInTheDocument();
		});
	});

	it('updates page count when page size changes', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY // 150 items
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// At 20 per page: 150/20 = 8 pages
			expect(screen.getByText(/Page 1 of 8/i)).toBeInTheDocument();
		});

		// Change to 50 per page
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '50');

		await waitFor(() => {
			// At 50 per page: 150/50 = 3 pages
			expect(screen.getByText(/Page 1 of 3/i)).toBeInTheDocument();
		});
	});

	it('resets to first page when page size is changed', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		// Navigate to page 3
		const nextButton = screen.getByText('Next');
		await user.click(nextButton);
		await user.click(nextButton);

		await waitFor(() => {
			expect(screen.getByText(/Page 3/)).toBeInTheDocument();
		});

		// Change page size
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '50');

		await waitFor(() => {
			// Should reset to page 1
			expect(screen.getByText(/Page 1/)).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 3: Navigation between pages
// ---------------------------------------------------------------------------
describe('Pagination - Page Navigation', () => {
	it('navigates to next page when Next button is clicked', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
		});

		// Click Next
		const nextButton = screen.getByText('Next');
		await user.click(nextButton);

		await waitFor(() => {
			// Should show items 21-40
			expect(screen.getByText('Test Card 21')).toBeInTheDocument();
			expect(screen.getByText('Test Card 40')).toBeInTheDocument();

			// Should NOT show item 1 or 41
			expect(screen.queryByText('Test Card 1')).not.toBeInTheDocument();
			expect(screen.queryByText('Test Card 41')).not.toBeInTheDocument();

			// Page indicator should update
			expect(screen.getByText(/Page 2/)).toBeInTheDocument();
		});
	});

	it('navigates to previous page when Previous button is clicked', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		// First go to page 2
		const nextButton = screen.getByText('Next');
		await user.click(nextButton);

		await waitFor(() => {
			expect(screen.getByText('Test Card 21')).toBeInTheDocument();
		});

		// Then go back to page 1
		const prevButton = screen.getByText('Previous');
		await user.click(prevButton);

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 20')).toBeInTheDocument();
			expect(screen.queryByText('Test Card 21')).not.toBeInTheDocument();
			expect(screen.getByText(/Page 1/)).toBeInTheDocument();
		});
	});

	it('disables Previous button on first page', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const prevButton = screen.getByText('Previous').closest('button');
			expect(prevButton).toBeDisabled();
		});
	});

	it('disables Next button on last page', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY // 150 items = 8 pages
				}
			},
			context: mockContext
		});

		// Navigate to last page (page 8)
		const nextButton = screen.getByText('Next');
		for (let i = 0; i < 7; i++) {
			await user.click(nextButton);
		}

		await waitFor(() => {
			expect(screen.getByText(/Page 8/)).toBeInTheDocument();
			const nextBtn = screen.getByText('Next').closest('button');
			expect(nextBtn).toBeDisabled();
		});
	});

	it('allows direct page selection via page number buttons', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Page buttons should be visible
			expect(screen.getByText('1')).toBeInTheDocument();
		});

		// Click page 3 button
		const page3Button = screen.getByRole('button', { name: '3' });
		await user.click(page3Button);

		await waitFor(() => {
			// Should show items 41-60
			expect(screen.getByText('Test Card 41')).toBeInTheDocument();
			expect(screen.getByText('Test Card 60')).toBeInTheDocument();
			expect(screen.queryByText('Test Card 1')).not.toBeInTheDocument();
			expect(screen.getByText(/Page 3/)).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 4: Single page display (no pagination needed)
// ---------------------------------------------------------------------------
describe('Pagination - Single Page Display', () => {
	it('does not show pagination when inventory has exactly 20 items', async () => {
		const exactlyTwenty = generateMockItems(20);

		render(InventoryPage, {
			props: {
				data: {
					items: exactlyTwenty
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 20')).toBeInTheDocument();
		});

		// No pagination controls
		expect(screen.queryByText('Next')).not.toBeInTheDocument();
		expect(screen.queryByText('Previous')).not.toBeInTheDocument();
	});

	it('does not show pagination when inventory has fewer than 20 items', async () => {
		const fewItems = generateMockItems(15);

		render(InventoryPage, {
			props: {
				data: {
					items: fewItems
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 15')).toBeInTheDocument();
		});

		// No pagination controls
		expect(screen.queryByText('Next')).not.toBeInTheDocument();
		expect(screen.queryByText('Previous')).not.toBeInTheDocument();
	});

	it('shows all items when total is less than selected page size', async () => {
		const user = userEvent.setup();
		const thirtyItems = generateMockItems(30);

		render(InventoryPage, {
			props: {
				data: {
					items: thirtyItems
				}
			},
			context: mockContext
		});

		// Change page size to 50
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '50');

		await waitFor(() => {
			// Should show all 30 items (since 30 < 50)
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 30')).toBeInTheDocument();

			// No pagination controls needed
			expect(screen.queryByText('Next')).not.toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 5: Empty state handling
// ---------------------------------------------------------------------------
describe('Pagination - Empty State', () => {
	it('does not display pagination controls when inventory is empty', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: []
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Your inventory is empty')).toBeInTheDocument();
		});

		// No pagination controls
		expect(screen.queryByText('Next')).not.toBeInTheDocument();
		expect(screen.queryByText('Previous')).not.toBeInTheDocument();
		expect(screen.queryByRole('combobox', { name: /items per page/i })).not.toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Scenario 6: Session persistence for page size preference
// ---------------------------------------------------------------------------
describe('Pagination - Session Persistence', () => {
	it('saves page size preference to localStorage when changed', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		// Change page size to 50
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '50');

		await waitFor(() => {
			// Should save to localStorage
			expect(localStorage.getItem('inventory-page-size')).toBe('50');
		});
	});

	it('loads saved page size preference from localStorage on mount', async () => {
		// Set preference before rendering
		localStorage.setItem('inventory-page-size', '100');

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const select = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
			expect(select.value).toBe('100');

			// Should display 100 items
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 100')).toBeInTheDocument();
			expect(screen.queryByText('Test Card 101')).not.toBeInTheDocument();
		});
	});

	it('uses default page size of 20 when no preference is saved', async () => {
		// Ensure localStorage is clean
		localStorage.clear();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const select = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
			expect(select.value).toBe('20');
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 7: Interaction with filtering and sorting
// ---------------------------------------------------------------------------
describe('Pagination - Integration with Filtering and Sorting', () => {
	it('resets to first page when filter is applied', async () => {
		const user = userEvent.setup();

		// Create items with different sets for filtering
		const mixedSetItems = Array.from({ length: 100 }, (_, i) => ({
			...generateMockItems(1)[0],
			id: i + 1,
			card_name: `Card ${i + 1}`,
			set: i < 50 ? 'set1' : 'set2',
			set_name: i < 50 ? 'Set One' : 'Set Two'
		}));

		render(InventoryPage, {
			props: {
				data: {
					items: mixedSetItems
				}
			},
			context: mockContext
		});

		// Navigate to page 2
		const nextButton = screen.getByText('Next');
		await user.click(nextButton);

		await waitFor(() => {
			expect(screen.getByText(/Page 2/)).toBeInTheDocument();
		});

		// Apply filter
		const filterSelect = screen.getByRole('combobox', { name: /filter by set/i });
		await user.selectOptions(filterSelect, 'Set One');

		await waitFor(() => {
			// Should reset to page 1 after filtering
			expect(screen.getByText(/Page 1/)).toBeInTheDocument();
		});
	});

	it('maintains current page when sort order changes', async () => {
		const user = userEvent.setup();

		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		// Navigate to page 2
		const nextButton = screen.getByText('Next');
		await user.click(nextButton);

		await waitFor(() => {
			expect(screen.getByText(/Page 2/)).toBeInTheDocument();
		});

		// Change sort order
		const sortSelect = screen.getByRole('combobox', { name: /sort by/i });
		await user.selectOptions(sortSelect, 'name-desc');

		await waitFor(() => {
			// Should stay on page 2 (sorting doesn't reset pagination)
			expect(screen.getByText(/Page 2/)).toBeInTheDocument();
		});
	});

	it('recalculates pages when filtered results change total count', async () => {
		const user = userEvent.setup();

		// Create items where only 30 match a specific set
		const mixedSetItems = Array.from({ length: 100 }, (_, i) => ({
			...generateMockItems(1)[0],
			id: i + 1,
			card_name: `Card ${i + 1}`,
			set: i < 30 ? 'rare' : 'common',
			set_name: i < 30 ? 'Rare Set' : 'Common Set'
		}));

		render(InventoryPage, {
			props: {
				data: {
					items: mixedSetItems
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should have 5 pages (100 items / 20 per page)
			expect(screen.getByText(/of 5/i)).toBeInTheDocument();
		});

		// Apply filter that reduces to 30 items
		const filterSelect = screen.getByRole('combobox', { name: /filter by set/i });
		await user.selectOptions(filterSelect, 'Rare Set');

		await waitFor(() => {
			// Should now have 2 pages (30 items / 20 per page)
			expect(screen.getByText(/of 2/i)).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 8: Accessibility
// ---------------------------------------------------------------------------
describe('Pagination - Accessibility', () => {
	it('pagination controls have proper ARIA labels', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Page size selector should have label
			expect(screen.getByRole('combobox', { name: /items per page/i })).toBeInTheDocument();

			// Navigation buttons should have proper labels
			expect(screen.getByRole('button', { name: /previous/i })).toBeInTheDocument();
			expect(screen.getByRole('button', { name: /next/i })).toBeInTheDocument();
		});
	});

	it('current page button has aria-current attribute', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const currentPageButton = screen.getByRole('button', { name: '1' });
			expect(currentPageButton).toHaveAttribute('aria-current', 'page');
		});
	});

	it('pagination component has proper navigation landmark', async () => {
		render(InventoryPage, {
			props: {
				data: {
					items: MOCK_LARGE_INVENTORY
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const nav = screen.getByRole('navigation', { name: /pagination/i });
			expect(nav).toBeInTheDocument();
		});
	});
});
