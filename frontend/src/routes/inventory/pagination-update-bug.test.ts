import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import InventoryPage from './+page.svelte';

/**
 * CRITICAL BUG TEST: Pagination + Item Updates
 *
 * When displayItems (paginated subset) is passed to InventoryTable,
 * and user updates a quantity, onItemsChange replaces ALL items
 * with just the current page, losing other pages!
 *
 * Expected: 45 items total, 20 on page 1
 * Bug: After update, only 20 items remain (other 25 lost)
 */

function generateItems(count: number) {
	return Array.from({ length: count }, (_, i) => ({
		id: i + 1,
		card_id: `card-${i + 1}`,
		quantity: 1,
		card_name: `Card ${String(i + 1).padStart(3, '0')}`,  // Ensures alphabetical = numerical order
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

// Mock fetch for quantity updates
global.fetch = vi.fn();

beforeEach(() => {
	vi.clearAllMocks();
	localStorage.clear();

	// Default mock response for PATCH requests
	(global.fetch as any).mockImplementation((url: string, options: any) => {
		if (options?.method === 'PATCH') {
			// Extract ID from URL
			const id = parseInt(url.split('/').pop() || '1');
			const body = JSON.parse(options.body);

			return Promise.resolve({
				ok: true,
				json: () => Promise.resolve({
					id,
					card_id: `card-${id}`,
					quantity: body.quantity,
					card_name: `Card ${String(id).padStart(3, '0')}`,
					set: 'tst',
					set_name: 'Test Set',
					collector_number: `${id}`,
					released_at: '2024-01-01',
					image_url: `https://example.com/${id}.jpg`,
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
				})
			});
		}
		return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
	});
});

afterEach(() => {
	cleanup();
});

describe('CRITICAL BUG: Pagination + Item Updates', () => {
	it('should NOT lose items from other pages when updating quantity on page 1', async () => {
		const user = userEvent.setup();
		const items45 = generateItems(45);

		render(InventoryPage, {
			props: {
				data: {
					items: items45
				}
			},
			context: mockContext
		});

		await waitFor(() => {
			// Should show "45 cards" in header
			expect(screen.getByText(/45 cards/i)).toBeInTheDocument();
		});

		// Find quantity display buttons and click the first one to enter edit mode
		const quantityDisplays = screen.getAllByTestId('quantity-display');
		await user.click(quantityDisplays[0]);

		// Wait for edit mode to activate, then find the input
		await waitFor(() => {
			expect(screen.getByTestId('quantity-input')).toBeInTheDocument();
		});

		const quantityInput = screen.getByTestId('quantity-input');

		// Update quantity from 1 to 5
		await user.clear(quantityInput);
		await user.type(quantityInput, '5');

		// Click the save button
		const saveButton = screen.getByTestId('save-btn');
		await user.click(saveButton);

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalled();
		});

		// CRITICAL: After update, should STILL have 45 cards total!
		await waitFor(() => {
			const cardCountText = screen.queryByText(/45 cards/i);

			if (!cardCountText) {
				// BUG DETECTED: Item count changed after update
				const newCount = screen.queryByText(/\d+ cards?/i);
				console.error('🐛 BUG CONFIRMED: Item count changed after quantity update!');
				console.error(`   Expected: 45 cards`);
				console.error(`   Actual: ${newCount?.textContent || 'unknown'}`);
				console.error('   Root cause: onItemsChange replaces allItems with displayItems (paginated subset)');
			}

			expect(cardCountText).toBeInTheDocument();
		}, { timeout: 5000 });
	});

	it('should maintain pagination controls after updating item quantity', async () => {
		const user = userEvent.setup();
		const items45 = generateItems(45);

		render(InventoryPage, {
			props: {
				data: {
					items: items45
				}
			},
			context: mockContext
		});

		// Verify pagination exists initially
		await waitFor(() => {
			expect(screen.getByText('Next')).toBeInTheDocument();
		});

		// Click quantity display to enter edit mode
		const quantityDisplays = screen.getAllByTestId('quantity-display');
		await user.click(quantityDisplays[0]);

		// Wait for edit mode and get the input
		await waitFor(() => {
			expect(screen.getByTestId('quantity-input')).toBeInTheDocument();
		});

		const quantityInput = screen.getByTestId('quantity-input');

		// Update quantity
		await user.clear(quantityInput);
		await user.type(quantityInput, '3');

		// Save the changes
		const saveButton = screen.getByTestId('save-btn');
		await user.click(saveButton);

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalled();
		});

		// Pagination should STILL exist after update
		await waitFor(() => {
			const nextButton = screen.queryByText('Next');

			if (!nextButton) {
				console.error('🐛 BUG: Pagination disappeared after quantity update!');
				console.error('   This happens when allItems is replaced with displayItems (20 items)');
				console.error('   20 items = no pagination needed, but we should have 45!');
			}

			expect(nextButton).toBeInTheDocument();
		}, { timeout: 5000 });
	});
});
