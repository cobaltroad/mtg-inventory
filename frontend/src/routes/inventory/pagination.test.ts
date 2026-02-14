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
		finish: null,
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

// Mock fetch globally for tests that need it
global.fetch = vi.fn();

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
			// Items are sorted alphabetically, so we should see:
			// Test Card 1, Test Card 10, Test Card 100-116 (total 20 items)
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 10')).toBeInTheDocument();
			expect(screen.getByText('Test Card 100')).toBeInTheDocument();
			expect(screen.getByText('Test Card 116')).toBeInTheDocument();

			// Should NOT see card 117 or other cards not in first page
			expect(screen.queryByText('Test Card 117')).not.toBeInTheDocument();
			expect(screen.queryByText('Test Card 2')).not.toBeInTheDocument();
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
			// Page numbers are rendered as links
			const page1Link = screen.getByLabelText(/page 1/i);
			expect(page1Link).toBeInTheDocument();

			// Should show page 8 link (last page)
			const page8Link = screen.getByLabelText(/page 8/i);
			expect(page8Link).toBeInTheDocument();
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
			// Should now see first 50 items (alphabetically sorted)
			// First 50: 1, 10, 100-143 (total 50 items)
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 10')).toBeInTheDocument();
			expect(screen.getByText('Test Card 143')).toBeInTheDocument();

			// Should NOT see item 144 (comes after first 50 alphabetically)
			expect(screen.queryByText('Test Card 144')).not.toBeInTheDocument();
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
			// Should now see first 100 items (alphabetically sorted)
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 10')).toBeInTheDocument();
			expect(screen.getByText('Test Card 100')).toBeInTheDocument();

			// After 100 items alphabetically: next would be from "Test Card 2" series
			// So "Test Card 2" should still be on page 1
			expect(screen.getByText('Test Card 2')).toBeInTheDocument();
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
			// Page 8 button should exist
			expect(screen.getByLabelText(/page 8/i)).toBeInTheDocument();
		});

		// Change to 50 per page
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '50');

		await waitFor(() => {
			// At 50 per page: 150/50 = 3 pages
			// Page 3 link should exist, page 8 should not
			expect(screen.getByLabelText(/page 3/i)).toBeInTheDocument();
			expect(screen.queryByLabelText(/page 8/i)).not.toBeInTheDocument();
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
			// Page 3 button should have aria-current="page"
			const page3Button = screen.getByLabelText(/page 3/i);
			expect(page3Button).toHaveAttribute('aria-current', 'page');
		});

		// Change page size
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '50');

		await waitFor(() => {
			// Should reset to page 1 (page 1 button has aria-current="page")
			const page1Button = screen.getByLabelText(/page 1/i);
			expect(page1Button).toHaveAttribute('aria-current', 'page');
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
			// Page 2 should be active (has aria-current="page")
			const page2Button = screen.getByLabelText(/page 2/i);
			expect(page2Button).toHaveAttribute('aria-current', 'page');

			// Should show different items (page 2 alphabetically)
			// Items 21-40 alphabetically: Test Card 117 onwards
			expect(screen.getByText('Test Card 117')).toBeInTheDocument();

			// Should NOT show item 1 (from page 1)
			expect(screen.queryByText('Test Card 1')).not.toBeInTheDocument();
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
			const page2Button = screen.getByLabelText(/page 2/i);
			expect(page2Button).toHaveAttribute('aria-current', 'page');
		});

		// Then go back to page 1
		const prevButton = screen.getByText('Previous');
		await user.click(prevButton);

		await waitFor(() => {
			const page1Button = screen.getByLabelText(/page 1/i);
			expect(page1Button).toHaveAttribute('aria-current', 'page');

			// Should show page 1 items
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
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
			await new Promise((resolve) => setTimeout(resolve, 50)); // Small delay between clicks
		}

		await waitFor(() => {
			const page8Button = screen.getByLabelText(/page 8/i);
			expect(page8Button).toHaveAttribute('aria-current', 'page');

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
			const page1Button = screen.getByLabelText(/page 1/i);
			expect(page1Button).toBeInTheDocument();
		});

		// Click page 3 button
		const page3Button = screen.getByLabelText(/page 3/i);
		await user.click(page3Button);

		await waitFor(() => {
			// Page 3 should be active
			expect(page3Button).toHaveAttribute('aria-current', 'page');

			// Should NOT show page 1 items
			expect(screen.queryByText('Test Card 1')).not.toBeInTheDocument();
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

			// Should display first 100 items alphabetically
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 100')).toBeInTheDocument();
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
			const page2Button = screen.getByLabelText(/page 2/i);
			expect(page2Button).toHaveAttribute('aria-current', 'page');
		});

		// Apply filter - open the filter dropdown
		const filterButton = screen.getByRole('button', { name: /filter by set/i });
		await user.click(filterButton);

		// Select "Set One" from the dropdown - use getAllByText since it appears in multiple places
		await waitFor(() => {
			const setOneOptions = screen.getAllByText('Set One');
			expect(setOneOptions.length).toBeGreaterThan(0);
		});

		// Click the first occurrence which should be in the dropdown
		const setOneOptions = screen.getAllByText('Set One');
		// Find the one in the dropdown (it should be clickable)
		const dropdownOption = setOneOptions.find((el) => el.closest('[class*="dropdown"]'));
		if (dropdownOption) {
			await user.click(dropdownOption);
		} else {
			// Fallback: click first option
			await user.click(setOneOptions[0]);
		}

		await waitFor(() => {
			// Should reset to page 1 after filtering
			const page1Button = screen.getByLabelText(/page 1/i);
			expect(page1Button).toHaveAttribute('aria-current', 'page');
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
			const page2Button = screen.getByLabelText(/page 2/i);
			expect(page2Button).toHaveAttribute('aria-current', 'page');
		});

		// Change sort order - find the select by its id
		const sortSelect = screen.getByLabelText(/sort:/i);
		await user.selectOptions(sortSelect, 'name-desc');

		await waitFor(() => {
			// Should stay on page 2 (sorting doesn't reset pagination)
			const page2Button = screen.getByLabelText(/page 2/i);
			expect(page2Button).toHaveAttribute('aria-current', 'page');
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
			expect(screen.getByLabelText(/page 5/i)).toBeInTheDocument();
		});

		// Apply filter that reduces to 30 items - open the filter dropdown
		const filterButton = screen.getByRole('button', { name: /filter by set/i });
		await user.click(filterButton);

		// Select "Rare Set" from the dropdown
		await waitFor(() => {
			const rareSetOption = screen.getByText('Rare Set');
			expect(rareSetOption).toBeInTheDocument();
		});

		const rareSetOption = screen.getByText('Rare Set');
		await user.click(rareSetOption);

		await waitFor(() => {
			// Should now have 2 pages (30 items / 20 per page)
			expect(screen.getByLabelText(/page 2/i)).toBeInTheDocument();
			// Page 5 should no longer exist
			expect(screen.queryByLabelText(/page 5/i)).not.toBeInTheDocument();
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
			// Find all buttons with number labels and check page 1
			const page1Button = screen.getByLabelText(/page 1/i);
			expect(page1Button).toBeInTheDocument();
			// Note: Skeleton UI may use data-selected or aria-current
			// We should check the actual attribute being set
			const hasCurrentIndicator =
				page1Button.hasAttribute('aria-current') ||
				page1Button.hasAttribute('data-selected') ||
				page1Button.getAttribute('aria-pressed') === 'true';
			expect(hasCurrentIndicator).toBe(true);
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

// ---------------------------------------------------------------------------
// REGRESSION TESTS - Bug Fixes
// These tests document historical bugs that have been fixed and ensure they
// don't reoccur. Each section includes the bug description and fix.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Regression: 38 Items Edge Case (Issue: Pagination not showing)
// Bug: With exactly 38 items, pagination controls were not appearing
// Root Cause: Logic error in showPagination calculation
// Fix: Corrected comparison to properly show pagination when items > pageSize
// ---------------------------------------------------------------------------
describe('Regression - 38 Items Pagination Bug', () => {
	it('should display pagination controls with exactly 38 items', async () => {
		const items38 = generateMockItems(38);

		render(InventoryPage, {
			props: {
				data: {
					items: items38
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// With 38 items and default pageSize of 20, pagination MUST appear
			expect(screen.getByText('Next')).toBeInTheDocument();
			expect(screen.getByText('Previous')).toBeInTheDocument();
			expect(screen.getByRole('combobox', { name: /items per page/i })).toBeInTheDocument();
		});
	});

	it('should display exactly 20 items on first page with 38 total', async () => {
		const items38 = generateMockItems(38);

		render(InventoryPage, {
			props: {
				data: {
					items: items38
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const rows = screen.getAllByRole('row');
			const itemRows = rows.slice(1); // Remove header row
			expect(itemRows.length).toBe(20);
		});
	});

	it('should show remaining 18 items on page 2', async () => {
		const user = userEvent.setup();
		const items38 = generateMockItems(38);

		render(InventoryPage, {
			props: {
				data: {
					items: items38
				}
			},
			context: mockContext
		});

		// Navigate to page 2
		const nextButton = screen.getByText('Next');
		await user.click(nextButton);

		await waitFor(() => {
			const rows = screen.getAllByRole('row');
			const itemRows = rows.slice(1); // Remove header row
			expect(itemRows.length).toBe(18); // Remaining items on page 2
		});
	});
});

// ---------------------------------------------------------------------------
// Regression: Item Updates Losing Pagination (Critical Bug)
// Bug: Updating item quantity would lose all items except current page
// Root Cause: onItemsChange was replacing allItems with displayItems (paginated subset)
// Fix: Update only the specific item in allItems, not replace entire array
// Example: Had 45 items across 3 pages, after update only 20 remained
// ---------------------------------------------------------------------------
describe('Regression - Item Updates Preserve Pagination', () => {
	// Mock fetch for quantity updates
	beforeEach(() => {
		(global.fetch as any).mockImplementation((url: string, options: any) => {
			if (options?.method === 'PATCH') {
				const id = parseInt(url.split('/').pop() || '1');
				const body = JSON.parse(options.body);

				return Promise.resolve({
					ok: true,
					json: () =>
						Promise.resolve({
							id,
							card_id: `uuid-${id}`,
							quantity: body.quantity,
							card_name: `Test Card ${id}`,
							set: 'tst',
							set_name: 'Test Set',
							collector_number: `${id}`,
							released_at: '2025-01-01',
							image_url: `https://example.com/card-${id}.jpg`,
							acquired_date: null,
							acquired_price_cents: null,
							finish: null,
							language: null,
							created_at: '2025-01-01T10:00:00Z',
							updated_at: '2025-01-01T10:00:00Z',
							user_id: 1,
							collection_type: 'inventory'
						})
				});
			}
			return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
		});
	});

	it('should NOT lose items from other pages when updating quantity', async () => {
		const user = userEvent.setup();
		const items45 = generateMockItems(45);

		render(InventoryPage, {
			props: {
				data: {
					items: items45
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText(/45 cards/i)).toBeInTheDocument();
		});

		// Find and update the first item's quantity
		const quantityDisplays = screen.getAllByTestId('quantity-display');
		await user.click(quantityDisplays[0]);

		await waitFor(() => {
			expect(screen.getByTestId('quantity-input')).toBeInTheDocument();
		});

		const quantityInput = screen.getByTestId('quantity-input');
		await user.clear(quantityInput);
		await user.type(quantityInput, '5');

		const saveButton = screen.getByTestId('save-btn');
		await user.click(saveButton);

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalled();
		});

		// CRITICAL: After update, should STILL have 45 cards total
		await waitFor(
			() => {
				expect(screen.getByText(/45 cards/i)).toBeInTheDocument();
			},
			{ timeout: 5000 }
		);
	});

	it('should navigate to second page with multi-page inventory after update', async () => {
		const user = userEvent.setup();
		const items45 = generateMockItems(45);

		render(InventoryPage, {
			props: {
				data: {
					items: items45
				}
			},
			context: mockContext
		});

		// Verify we have multiple pages initially
		await waitFor(() => {
			expect(screen.getByText('Next')).toBeInTheDocument();
			const page3Link = screen.getByLabelText(/page 3/i);
			expect(page3Link).toBeInTheDocument();
		});

		// Update first item's quantity
		const quantityDisplays = screen.getAllByTestId('quantity-display');
		await user.click(quantityDisplays[0]);

		await waitFor(() => {
			expect(screen.getByTestId('quantity-input')).toBeInTheDocument();
		});

		const quantityInput = screen.getByTestId('quantity-input');
		await user.clear(quantityInput);
		await user.type(quantityInput, '3');

		const saveButton = screen.getByTestId('save-btn');
		await user.click(saveButton);

		// Wait for update to complete
		await waitFor(
			() => {
				expect(global.fetch).toHaveBeenCalled();
			},
			{ timeout: 3000 }
		);

		// After update, should still be able to navigate to page 2
		// This verifies that all 45 items still exist
		const nextButton = screen.getByText('Next');
		await user.click(nextButton);

		await waitFor(() => {
			const page2Link = screen.getByLabelText(/page 2/i);
			expect(page2Link).toHaveAttribute('aria-current', 'page');
		});
	});
});

// ---------------------------------------------------------------------------
// Regression: PageSize Not Defaulting to 20
// Bug: PageSize wasn't properly initializing to 20 from localStorage
// Root Cause: Initial value extraction from localStorage had validation issues
// Fix: Proper default value handling with fallback to 20
// Example: User with 51 items saw no pagination until manually changing pageSize
// ---------------------------------------------------------------------------
describe('Regression - PageSize Initialization', () => {
	it('should default to 20 items per page when no localStorage value exists', async () => {
		localStorage.clear();
		const items51 = generateMockItems(51);

		render(InventoryPage, {
			props: {
				data: {
					items: items51
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const pageSizeSelect = screen.getByRole('combobox', {
				name: /items per page/i
			}) as HTMLSelectElement;
			expect(pageSizeSelect.value).toBe('20');

			// Pagination should be visible with 51 items
			expect(screen.getByText('Next')).toBeInTheDocument();

			// Should display first 20 items only
			const rows = screen.getAllByRole('row');
			expect(rows.length - 1).toBe(20); // -1 for header
		});
	});

	it('should fall back to 20 when localStorage has invalid value', async () => {
		localStorage.setItem('inventory-page-size', '999');
		const items51 = generateMockItems(51);

		render(InventoryPage, {
			props: {
				data: {
					items: items51
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const pageSizeSelect = screen.getByRole('combobox', {
				name: /items per page/i
			}) as HTMLSelectElement;
			expect(pageSizeSelect.value).toBe('20');
			expect(screen.getByText('Next')).toBeInTheDocument();
		});
	});

	it('should fall back to 20 when localStorage has non-numeric value', async () => {
		localStorage.setItem('inventory-page-size', 'invalid');
		const items51 = generateMockItems(51);

		render(InventoryPage, {
			props: {
				data: {
					items: items51
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			const pageSizeSelect = screen.getByRole('combobox', {
				name: /items per page/i
			}) as HTMLSelectElement;
			expect(pageSizeSelect.value).toBe('20');
		});
	});

	it('should show pagination immediately with 51 items and default pageSize 20', async () => {
		localStorage.clear();
		const items51 = generateMockItems(51);

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
			expect(screen.getByText('Next')).toBeInTheDocument();
			expect(screen.getByRole('combobox', { name: /items per page/i })).toBeInTheDocument();
		});
	});
});
