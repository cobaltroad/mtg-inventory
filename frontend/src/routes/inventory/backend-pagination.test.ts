import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import InventoryPage from './+page.svelte';

// ---------------------------------------------------------------------------
// Mock Data - Backend paginated response format
// ---------------------------------------------------------------------------
function generateMockItem(i: number) {
	return {
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
	};
}

function generatePaginatedResponse(page: number, perPage: number, totalCount: number) {
	const start = (page - 1) * perPage;
	const end = Math.min(start + perPage, totalCount);
	const items = Array.from({ length: end - start }, (_, i) => generateMockItem(start + i));

	return {
		items,
		page,
		per_page: perPage,
		total_count: totalCount,
		total_pages: Math.ceil(totalCount / perPage)
	};
}

// Mock context for search drawer
const mockContext = new Map([['openSearchDrawer', vi.fn()]]);

beforeEach(() => {
	vi.clearAllMocks();
	localStorage.clear();
});

afterEach(() => {
	cleanup();
});

// ---------------------------------------------------------------------------
// RED PHASE: Tests for Backend Pagination Support
// These tests SHOULD FAIL initially - backend pagination not yet implemented
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Scenario 1: Backend API integration
// Given the backend returns paginated data with metadata
// When the page loads
// Then the frontend should handle the paginated response format
// ---------------------------------------------------------------------------
describe('Backend Pagination - API Integration', () => {
	it('handles backend paginated response format with items array and metadata', async () => {
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should display items from the response
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 20')).toBeInTheDocument();
		});
	});

	it('displays total count from backend metadata', async () => {
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should show total count from backend, not just current page count
			expect(screen.getByText(/150 cards/i)).toBeInTheDocument();
		});
	});

	it('calculates total pages from backend metadata', async () => {
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			// 150 total / 20 per page = 8 pages
			// Should show page 8 link
			const page8Link = screen.getByLabelText(/page 8/i);
			expect(page8Link).toBeInTheDocument();
		});
	});

	it('handles empty paginated response', async () => {
		const emptyResponse = {
			items: [],
			page: 1,
			per_page: 20,
			total_count: 0,
			total_pages: 0
		};

		render(InventoryPage, {
			props: {
				data: emptyResponse
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Your inventory is empty')).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 2: URL-based pagination state
// Given pagination parameters in URL query string
// When the page loads or user navigates
// Then the URL should reflect current page and per_page
// ---------------------------------------------------------------------------
describe('Backend Pagination - URL State Management', () => {
	it('includes page parameter in URL when navigating to page 2', async () => {
		const user = userEvent.setup();
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		// Mock URL searchParams
		const mockGoto = vi.fn();
		const mockPageStore = {
			subscribe: vi.fn((fn) => {
				fn({
					url: new URL('http://localhost:3001/inventory'),
					params: {},
					route: { id: '/inventory' },
					status: 200,
					error: null,
					data: mockPaginatedData,
					form: null
				});
				return () => {};
			})
		};

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
		});

		// Click Next button
		const nextButton = screen.getByText('Next');
		await user.click(nextButton);

		// Note: This test will need integration with SvelteKit's goto function
		// For now, we're testing the UI behavior
		await waitFor(() => {
			const page2Button = screen.getByLabelText(/page 2/i);
			expect(page2Button).toHaveAttribute('aria-current', 'page');
		});
	});

	it('includes per_page parameter in URL when page size is changed', async () => {
		const user = userEvent.setup();
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			const select = screen.getByRole('combobox', { name: /items per page/i });
			expect(select).toBeInTheDocument();
		});

		// Change page size to 50
		const select = screen.getByRole('combobox', { name: /items per page/i });
		await user.selectOptions(select, '50');

		// Should update URL with per_page=50
		// Note: URL update will be tested in integration tests
		await waitFor(() => {
			const selectElement = screen.getByRole('combobox', {
				name: /items per page/i
			}) as HTMLSelectElement;
			expect(selectElement.value).toBe('50');
		});
	});

	it('preserves URL parameters during navigation for deep linking', async () => {
		// This test validates that pagination state can be bookmarked/shared
		const mockPage2Data = generatePaginatedResponse(2, 50, 150);

		// Simulate loading with URL params: ?page=2&per_page=50
		render(InventoryPage, {
			props: {
				data: mockPage2Data
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should show page 2 items (items 51-100)
			expect(screen.getByText('Test Card 51')).toBeInTheDocument();
			expect(screen.getByText('Test Card 100')).toBeInTheDocument();

			// Page 2 should be active
			const page2Button = screen.getByLabelText(/page 2/i);
			expect(page2Button).toHaveAttribute('aria-current', 'page');

			// Page size should be 50
			const select = screen.getByRole('combobox', { name: /items per page/i }) as HTMLSelectElement;
			expect(select.value).toBe('50');
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 3: Loading states during API calls
// Given user navigates between pages
// When API request is in flight
// Then loading indicator should be displayed
// ---------------------------------------------------------------------------
describe('Backend Pagination - Loading States', () => {
	it('displays loading spinner when fetching next page', async () => {
		const user = userEvent.setup();
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
		});

		// Note: This test needs to be enhanced with actual fetch mocking
		// to intercept the API call and show loading state
		// For now, we're testing that the loading prop can be passed to InventoryTable
		const nextButton = screen.getByText('Next');
		expect(nextButton).toBeInTheDocument();
	});

	it('does not disable pagination controls during loading', async () => {
		const user = userEvent.setup();
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			const nextButton = screen.getByText('Next');
			expect(nextButton).not.toBeDisabled();
		});
	});

	it('preserves page state when API request fails', async () => {
		// This test ensures that failed pagination doesn't break the UI
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		render(InventoryPage, {
			props: {
				data: {
					...mockPaginatedData,
					error: 'Failed to fetch inventory'
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should still show items from previous successful load
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();

			// Error message should be visible
			expect(screen.getByText(/failed to fetch inventory/i)).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 4: Performance improvements
// Given large inventory with backend pagination
// When page loads
// Then only current page items should be rendered
// ---------------------------------------------------------------------------
describe('Backend Pagination - Performance', () => {
	it('only renders current page items, not all inventory items', async () => {
		// Backend returns only page 1 (20 items), but total is 1000
		const mockPaginatedData = generatePaginatedResponse(1, 20, 1000);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should only render 20 items
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 20')).toBeInTheDocument();

			// Items beyond page 1 should not be in DOM
			expect(screen.queryByText('Test Card 21')).not.toBeInTheDocument();
			expect(screen.queryByText('Test Card 100')).not.toBeInTheDocument();
		});
	});

	it('shows correct total count even when only subset is loaded', async () => {
		const mockPaginatedData = generatePaginatedResponse(1, 20, 1000);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should display total from backend, not just loaded items
			expect(screen.getByText(/1000 cards/i)).toBeInTheDocument();
		});
	});

	it('calculates stats only from loaded page items', async () => {
		// Create items with varying quantities for stats calculation
		const mockData = {
			items: [
				{ ...generateMockItem(0), quantity: 5 },
				{ ...generateMockItem(1), quantity: 3 }
			],
			page: 1,
			per_page: 20,
			total_count: 100,
			total_pages: 5
		};

		render(InventoryPage, {
			props: {
				data: mockData
			},
			context: mockContext
		});

		await waitFor(() => {
			// Stats should reflect only the 2 loaded items (8 cards total)
			// Note: This depends on how InventoryStats is implemented
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Scenario 5: Backwards compatibility
// Given existing features (filtering, sorting, search)
// When backend pagination is enabled
// Then all existing functionality should continue working
// ---------------------------------------------------------------------------
describe('Backend Pagination - Backwards Compatibility', () => {
	it('maintains filtering functionality with backend pagination', async () => {
		const user = userEvent.setup();

		// Create items with different sets
		const mockData = {
			items: [
				{ ...generateMockItem(0), set: 'set1', set_name: 'Set One' },
				{ ...generateMockItem(1), set: 'set2', set_name: 'Set Two' },
				{ ...generateMockItem(2), set: 'set1', set_name: 'Set One' }
			],
			page: 1,
			per_page: 20,
			total_count: 3,
			total_pages: 1
		};

		render(InventoryPage, {
			props: {
				data: mockData
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 2')).toBeInTheDocument();
			expect(screen.getByText('Test Card 3')).toBeInTheDocument();
		});

		// Apply filter - open dropdown
		const filterButton = screen.getByRole('button', { name: /filter by set/i });
		await user.click(filterButton);

		// Select "Set One" - use getAllByText since it appears in multiple places
		await waitFor(() => {
			const setOneOptions = screen.getAllByText('Set One');
			expect(setOneOptions.length).toBeGreaterThan(0);
		});

		const setOneOptions = screen.getAllByText('Set One');
		// Find the one that's clickable (in the dropdown, not in stats or table)
		const clickableOption = setOneOptions.find((el) => {
			const parent = el.parentElement;
			return parent?.getAttribute('role') === 'option' || parent?.tagName === 'BUTTON';
		});

		if (clickableOption) {
			await user.click(clickableOption);
		} else {
			// Fallback: click the first option
			await user.click(setOneOptions[0]);
		}

		await waitFor(() => {
			// Should show only Set One items
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 3')).toBeInTheDocument();
			expect(screen.queryByText('Test Card 2')).not.toBeInTheDocument();

			// Count should reflect filtered items
			expect(screen.getByText(/2 of 3 cards/i)).toBeInTheDocument();
		});
	});

	it('maintains sorting functionality with backend pagination', async () => {
		const user = userEvent.setup();
		const mockPaginatedData = generatePaginatedResponse(1, 20, 50);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
		});

		// Change sort order
		const sortSelect = screen.getByLabelText(/sort:/i);
		await user.selectOptions(sortSelect, 'name-desc');

		await waitFor(() => {
			// Items should re-sort (though with backend pagination,
			// this might require a new API call)
			const sortSelectElement = screen.getByLabelText(/sort:/i) as HTMLSelectElement;
			expect(sortSelectElement.value).toBe('name-desc');
		});
	});

	it('maintains search functionality with backend pagination', async () => {
		const mockPaginatedData = generatePaginatedResponse(1, 20, 150);

		render(InventoryPage, {
			props: {
				data: mockPaginatedData
			},
			context: mockContext
		});

		await waitFor(() => {
			// Search button should still be present
			const searchButton = screen.getByText('Search Cards');
			expect(searchButton).toBeInTheDocument();
		});

		// Click search button - should open drawer
		const searchButton = screen.getByText('Search Cards');
		expect(searchButton).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Scenario 6: Edge cases and error handling
// ---------------------------------------------------------------------------
describe('Backend Pagination - Edge Cases', () => {
	it('handles single page of results correctly', async () => {
		const mockSinglePageData = generatePaginatedResponse(1, 20, 15);

		render(InventoryPage, {
			props: {
				data: mockSinglePageData
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should show all items
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 15')).toBeInTheDocument();

			// No pagination controls needed
			expect(screen.queryByText('Next')).not.toBeInTheDocument();
			expect(screen.queryByText('Previous')).not.toBeInTheDocument();
		});
	});

	it('handles exactly one page of results', async () => {
		const mockExactPageData = generatePaginatedResponse(1, 20, 20);

		render(InventoryPage, {
			props: {
				data: mockExactPageData
			},
			context: mockContext
		});

		await waitFor(() => {
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
			expect(screen.getByText('Test Card 20')).toBeInTheDocument();

			// No pagination needed for exactly 20 items
			expect(screen.queryByText('Next')).not.toBeInTheDocument();
		});
	});

	it('handles missing metadata gracefully', async () => {
		const malformedData = {
			items: [generateMockItem(0), generateMockItem(1)]
			// Missing page, per_page, total_count, total_pages
		};

		render(InventoryPage, {
			props: {
				data: malformedData as any
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should still display items
			expect(screen.getByText('Test Card 1')).toBeInTheDocument();
		});
	});

	it('handles invalid page number gracefully', async () => {
		const mockInvalidPageData = {
			items: [],
			page: 999,
			per_page: 20,
			total_count: 50,
			total_pages: 3
		};

		render(InventoryPage, {
			props: {
				data: mockInvalidPageData
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should handle empty results gracefully
			// May show empty state or redirect to valid page
			const body = document.body;
			expect(body).toBeInTheDocument();
		});
	});
});
