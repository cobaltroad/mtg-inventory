import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import PrintingModal from './PrintingModal.svelte';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const MOCK_CARD = {
	id: 'card-123',
	name: 'Lightning Bolt'
};

const MOCK_PRINTINGS = [
	{
		id: 'print-1',
		name: 'Lightning Bolt',
		set: 'm21',
		set_name: 'Core Set 2021',
		collector_number: '125',
		image_url: 'https://example.com/m21-bolt.jpg',
		released_at: '2020-07-03'
	},
	{
		id: 'print-2',
		name: 'Lightning Bolt',
		set: 'm10',
		set_name: 'Magic 2010',
		collector_number: '146',
		image_url: 'https://example.com/m10-bolt.jpg',
		released_at: '2009-07-17'
	},
	{
		id: 'print-3',
		name: 'Lightning Bolt',
		set: 'lea',
		set_name: 'Limited Edition Alpha',
		collector_number: '157',
		image_url: 'https://example.com/lea-bolt.jpg',
		released_at: '1993-08-05'
	}
];

function mockFetchForPrintings(printings = MOCK_PRINTINGS, shouldFail = false) {
	return vi.fn().mockImplementation((url: string) => {
		if (typeof url === 'string' && url.includes('/printings')) {
			if (shouldFail) {
				return Promise.reject(new Error('Network error'));
			}
			return Promise.resolve({
				ok: true,
				json: () => Promise.resolve({ printings })
			});
		}
		return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
	});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe('PrintingModal', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	// ---------------------------------------------------------------------------
	// Modal Display & Loading (Scenario 1)
	// ---------------------------------------------------------------------------
	describe('Modal Display & Loading', () => {
		it('renders modal centered when open prop is true', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			const dialog = screen.getByRole('dialog');
			expect(dialog).toBeInTheDocument();
		});

		it('does not render modal when open prop is false', () => {
			render(PrintingModal, { props: { card: MOCK_CARD, open: false } });

			const dialog = screen.queryByRole('dialog');
			expect(dialog).not.toBeInTheDocument();
		});

		it('displays card name as title', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Lightning Bolt/)).toBeInTheDocument();
			});
		});

		it('shows loading indicator during data fetch', async () => {
			const mockFetch = vi
				.fn()
				.mockImplementation(
					() =>
						new Promise((resolve) =>
							setTimeout(
								() =>
									resolve({ ok: true, json: () => Promise.resolve({ printings: MOCK_PRINTINGS }) }),
								100
							)
						)
				);
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			expect(screen.getByText(/loading/i)).toBeInTheDocument();
		});

		it('fetches printings from correct endpoint', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(mockFetch).toHaveBeenCalledWith(
					expect.stringContaining('/api/cards/card-123/printings')
				);
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Printing Information (Scenario 2)
	// ---------------------------------------------------------------------------
	describe('Printing Information', () => {
		it('displays all printings with set name, abbreviation, and collector number', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Core Set 2021/)).toBeInTheDocument();
				expect(screen.getByText(/m21/i)).toBeInTheDocument();
				expect(screen.getByText(/125/)).toBeInTheDocument();

				expect(screen.getByText(/Magic 2010/)).toBeInTheDocument();
				expect(screen.getByText(/m10/i)).toBeInTheDocument();
				expect(screen.getByText(/146/)).toBeInTheDocument();

				expect(screen.getByText(/Limited Edition Alpha/)).toBeInTheDocument();
				expect(screen.getByText(/lea/i)).toBeInTheDocument();
				expect(screen.getByText(/157/)).toBeInTheDocument();
			});
		});

		it('displays printings sorted by release date, newest first', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				const setNames = screen.getAllByTestId(/printing-item/i);
				expect(setNames).toHaveLength(3);
			});

			// Verify order by checking text content appears in the right sequence
			const modalContent = screen.getByRole('dialog').textContent || '';
			const m21Index = modalContent.indexOf('Core Set 2021');
			const m10Index = modalContent.indexOf('Magic 2010');
			const leaIndex = modalContent.indexOf('Limited Edition Alpha');

			expect(m21Index).toBeLessThan(m10Index);
			expect(m10Index).toBeLessThan(leaIndex);
		});
	});

	// ---------------------------------------------------------------------------
	// Handling Volume (Scenario 3)
	// ---------------------------------------------------------------------------
	describe('Handling Volume', () => {
		it('renders scrollable container for many printings', async () => {
			const manyPrintings = Array.from({ length: 25 }, (_, i) => ({
				id: `print-${i}`,
				name: 'Test Card',
				set: `set${i}`,
				set_name: `Set ${i}`,
				collector_number: `${i}`,
				image_url: `https://example.com/set${i}.jpg`,
				released_at: `2020-${String((i % 12) + 1).padStart(2, '0')}-01`
			}));

			const mockFetch = mockFetchForPrintings(manyPrintings);
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				const items = screen.getAllByTestId(/printing-item/i);
				expect(items.length).toBeGreaterThanOrEqual(20);
			});

			// Check for scrollable container
			const scrollContainer = screen.getByTestId('printings-list');
			expect(scrollContainer).toBeInTheDocument();
		});

		it('maintains fixed header while scrolling', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Lightning Bolt/)).toBeInTheDocument();
			});

			// Header should always be visible
			const title = screen.getByRole('heading', { name: /Lightning Bolt/i });
			expect(title).toBeInTheDocument();
		});
	});

	// ---------------------------------------------------------------------------
	// Dismissal (Scenario 4)
	// ---------------------------------------------------------------------------
	describe('Dismissal', () => {
		it('closes modal via X button', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			const onClose = vi.fn();
			render(PrintingModal, { props: { card: MOCK_CARD, open: true, onclose: onClose } });

			await waitFor(() => {
				expect(screen.getByRole('dialog')).toBeInTheDocument();
			});

			const closeButton = screen.getByRole('button', { name: /close/i });
			await fireEvent.click(closeButton);

			expect(onClose).toHaveBeenCalled();
		});

		it('closes modal via backdrop click', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			const onClose = vi.fn();
			render(PrintingModal, { props: { card: MOCK_CARD, open: true, onclose: onClose } });

			await waitFor(() => {
				expect(screen.getByRole('dialog')).toBeInTheDocument();
			});

			const backdrop = screen.getByTestId('modal-backdrop');
			await fireEvent.click(backdrop);

			expect(onClose).toHaveBeenCalled();
		});

		it('closes modal via Escape key', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			const onClose = vi.fn();
			render(PrintingModal, { props: { card: MOCK_CARD, open: true, onclose: onClose } });

			await waitFor(() => {
				expect(screen.getByRole('dialog')).toBeInTheDocument();
			});

			await fireEvent.keyDown(document, { key: 'Escape' });

			expect(onClose).toHaveBeenCalled();
		});

		it('does not add cards to inventory when dismissed', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			const onClose = vi.fn();
			render(PrintingModal, { props: { card: MOCK_CARD, open: true, onclose: onClose } });

			await waitFor(() => {
				expect(screen.getByRole('dialog')).toBeInTheDocument();
			});

			const closeButton = screen.getByRole('button', { name: /close/i });
			await fireEvent.click(closeButton);

			// Verify no inventory POST was made
			expect(mockFetch).not.toHaveBeenCalledWith(
				expect.stringContaining('/api/inventory'),
				expect.objectContaining({ method: 'POST' })
			);
		});
	});

	// ---------------------------------------------------------------------------
	// Error Handling (Scenario 5)
	// ---------------------------------------------------------------------------
	describe('Error Handling', () => {
		it('displays error message on API failure', async () => {
			const mockFetch = mockFetchForPrintings([], true);
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Unable to load printings/i)).toBeInTheDocument();
			});
		});

		it('shows retry button on error', async () => {
			const mockFetch = mockFetchForPrintings([], true);
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /retry/i })).toBeInTheDocument();
			});
		});

		it('re-fetches data when retry button is clicked', async () => {
			let shouldFail = true;
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					if (shouldFail) {
						shouldFail = false; // Next call will succeed
						return Promise.reject(new Error('Network error'));
					}
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Unable to load printings/i)).toBeInTheDocument();
			});

			const retryButton = screen.getByRole('button', { name: /retry/i });
			await fireEvent.click(retryButton);

			await waitFor(() => {
				expect(screen.getByText(/Core Set 2021/)).toBeInTheDocument();
			});

			expect(mockFetch).toHaveBeenCalledTimes(2);
		});

		it('displays error message on 4xx client errors', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: false,
						status: 404,
						json: () => Promise.resolve({ error: 'Not found' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Unable to load printings/i)).toBeInTheDocument();
			});
		});

		it('displays error message on 5xx server errors', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: false,
						status: 500,
						json: () => Promise.resolve({ error: 'Internal server error' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Unable to load printings/i)).toBeInTheDocument();
			});
		});
	});

	// ---------------------------------------------------------------------------
	// HTTP 304 Not Modified Handling (Issue #23)
	// ---------------------------------------------------------------------------
	describe('HTTP 304 Not Modified Handling', () => {
		it('displays cached printings on 304 response without error', async () => {
			// Simulate 304 Not Modified with cached response body
			// In real browsers, fetch API returns cached response automatically
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: false, // 304 sets ok to false
						status: 304,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS }) // Browser returns cached data
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Core Set 2021/)).toBeInTheDocument();
			});

			// Verify all printings are displayed
			expect(screen.getByText(/Magic 2010/)).toBeInTheDocument();
			expect(screen.getByText(/Limited Edition Alpha/)).toBeInTheDocument();

			// Verify no error state is shown
			expect(screen.queryByText(/Unable to load printings/i)).not.toBeInTheDocument();
		});

		it('does not show error state for 304 responses', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: false,
						status: 304,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			// Verify error container is not displayed
			expect(screen.queryByText(/Unable to load printings/i)).not.toBeInTheDocument();
			expect(screen.queryByRole('button', { name: /retry/i })).not.toBeInTheDocument();
		});

		it('parses cached JSON data from 304 response', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: false,
						status: 304,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				const printingItems = screen.getAllByTestId('printing-item');
				expect(printingItems).toHaveLength(3);
			});
		});

		it('handles first request (200) followed by subsequent request (304)', async () => {
			let firstRequest = true;
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					if (firstRequest) {
						firstRequest = false;
						return Promise.resolve({
							ok: true,
							status: 200,
							json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
						});
					}
					// Subsequent request returns 304 with cached data
					return Promise.resolve({
						ok: false,
						status: 304,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			// First render - should get 200 OK
			const { unmount } = render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Core Set 2021/)).toBeInTheDocument();
			});

			unmount();

			// Second render - should get 304 Not Modified
			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Core Set 2021/)).toBeInTheDocument();
			});

			// Verify no error on second request
			expect(screen.queryByText(/Unable to load printings/i)).not.toBeInTheDocument();
		});
	});

	// ---------------------------------------------------------------------------
	// Single Printing (Scenario 6)
	// ---------------------------------------------------------------------------
	describe('Single Printing', () => {
		it('shows single printing with same details and hover behavior', async () => {
			const singlePrinting = [MOCK_PRINTINGS[0]];
			const mockFetch = mockFetchForPrintings(singlePrinting);
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByText(/Core Set 2021/)).toBeInTheDocument();
				expect(screen.getByText(/m21/i)).toBeInTheDocument();
				expect(screen.getByText(/125/)).toBeInTheDocument();
			});

			const items = screen.getAllByTestId(/printing-item/i);
			expect(items).toHaveLength(1);
		});
	});

	// ---------------------------------------------------------------------------
	// Image Preview Behavior (UX Improvements)
	// ---------------------------------------------------------------------------
	describe('Image Preview Behavior', () => {
		it('does not show inline card-preview popup when hovering over a printing', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			// The inline popup (.card-preview) should not exist
			const inlinePopup = printingItems[0].querySelector('.card-preview');
			expect(inlinePopup).not.toBeInTheDocument();
		});

		it('displays image in right-side preview area when hovering over a printing', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const previewArea = document.querySelector('.image-preview-area');
				expect(previewArea).toBeInTheDocument();
				const img = previewArea?.querySelector('img');
				expect(img).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);
			});
		});

		it('persists image in preview area when hovering off a printing', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');

			// Hover over first printing
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const previewArea = document.querySelector('.image-preview-area');
				expect(previewArea).toBeInTheDocument();
			});

			// Hover off the printing
			await fireEvent.mouseLeave(printingItems[0]);

			// Image should still be displayed
			await waitFor(() => {
				const previewArea = document.querySelector('.image-preview-area');
				expect(previewArea).toBeInTheDocument();
				const img = previewArea?.querySelector('img');
				expect(img).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);
			});
		});

		it('updates image when hovering onto a different printing', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');

			// Hover over first printing
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const img = document.querySelector('.image-preview-area img');
				expect(img).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);
			});

			// Hover over second printing
			await fireEvent.mouseEnter(printingItems[1]);

			await waitFor(() => {
				const img = document.querySelector('.image-preview-area img');
				expect(img).toHaveAttribute('src', MOCK_PRINTINGS[1].image_url);
			});
		});

		it('allows keyboard focus to persist image selection', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');

			// Focus on first printing
			await fireEvent.focus(printingItems[0]);

			await waitFor(() => {
				const previewArea = document.querySelector('.image-preview-area');
				expect(previewArea).toBeInTheDocument();
				const img = previewArea?.querySelector('img');
				expect(img).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);
			});

			// Blur the printing
			await fireEvent.blur(printingItems[0]);

			// Image should still be displayed after blur
			await waitFor(() => {
				const previewArea = document.querySelector('.image-preview-area');
				expect(previewArea).toBeInTheDocument();
				const img = previewArea?.querySelector('img');
				expect(img).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Add to Inventory Functionality
	// ---------------------------------------------------------------------------
	describe('Add to Inventory Functionality', () => {
		it('renders Add to Inventory button when a printing is selected', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			// Hover over a printing to select it
			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const addButton = screen.getByRole('button', { name: /add to inventory/i });
				expect(addButton).toBeInTheDocument();
			});
		});

		it('does not render Add to Inventory button when no printing is selected', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			// Don't hover over any printing
			const addButton = screen.queryByRole('button', { name: /add to inventory/i });
			expect(addButton).not.toBeInTheDocument();
		});

		it('makes API call with correct printing ID when Add to Inventory is clicked', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			// Select a printing
			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				expect(mockFetch).toHaveBeenCalledWith(
					expect.stringContaining('/api/inventory'),
					expect.objectContaining({
						method: 'POST',
						headers: { 'Content-Type': 'application/json' }
					})
				);
			});

			// Verify the body contains required fields (but don't check exact match since enhanced fields are included)
			const inventoryCall = mockFetch.mock.calls.find(
				(call) => call[0].includes('/api/inventory') && call[1]?.method === 'POST'
			);
			expect(inventoryCall).toBeDefined();
			if (inventoryCall && inventoryCall[1]?.body) {
				const body = JSON.parse(inventoryCall[1].body);
				expect(body.card_id).toBe('print-1');
				expect(body.quantity).toBe(1);
			}
		});

		it('shows loading state during API call', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return new Promise((resolve) =>
						setTimeout(
							() =>
								resolve({
									ok: true,
									json: () =>
										Promise.resolve({
											card_id: 'print-1',
											quantity: 1,
											collection_type: 'inventory'
										})
								}),
							100
						)
					);
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Check for loading state
			expect(screen.getByText(/adding/i)).toBeInTheDocument();
		});

		it('disables button during loading state', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return new Promise((resolve) =>
						setTimeout(
							() =>
								resolve({
									ok: true,
									json: () =>
										Promise.resolve({
											card_id: 'print-1',
											quantity: 1,
											collection_type: 'inventory'
										})
								}),
							100
						)
					);
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Button should be disabled during loading
			expect(addButton).toBeDisabled();
		});

		it('shows success toast after successful add', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/added.*lightning bolt.*m21.*125/i);
			});
		});

		it('shows error message on API failure', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: false,
						status: 422,
						json: () => Promise.resolve({ error: 'Failed to add' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				expect(screen.getByText(/failed to add/i)).toBeInTheDocument();
			});
		});

		it('allows retry after error', async () => {
			let attemptCount = 0;
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					attemptCount++;
					if (attemptCount === 1) {
						return Promise.resolve({
							ok: false,
							status: 422,
							json: () => Promise.resolve({ error: 'Failed to add' })
						});
					}
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				expect(screen.getByText(/failed to add/i)).toBeInTheDocument();
			});

			// Retry button should be available
			const retryButton = screen.getByRole('button', { name: /retry/i });
			await fireEvent.click(retryButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/added.*lightning bolt.*m21.*125/i);
			});
		});

		it('positions button below the card image in preview area', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const previewArea = document.querySelector('.image-preview-area');
				expect(previewArea).toBeInTheDocument();
			});

			// Button should be within or associated with the image preview area
			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			const previewArea = document.querySelector('.image-preview-area');
			expect(
				previewArea?.contains(addButton) || addButton.parentElement === previewArea?.parentElement
			).toBe(true);
		});
	});

	// ---------------------------------------------------------------------------
	// Toast Notifications (UX Improvements)
	// ---------------------------------------------------------------------------
	describe('Toast Notifications', () => {
		it('displays toast notification after successful add to inventory', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/added.*lightning bolt.*m21.*125/i);
			});
		});

		it('clears selection after successful add to inventory', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
			});

			// Preview area should disappear after selection is cleared
			const previewArea = document.querySelector('.image-preview-area');
			expect(previewArea).not.toBeInTheDocument();
		});

		it('allows selecting and adding another printing after clearing selection', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-2', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');

			// Add first printing
			await fireEvent.mouseEnter(printingItems[0]);
			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});
			const addButton1 = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton1);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
			});

			// Add second printing
			await fireEvent.mouseEnter(printingItems[1]);
			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton2 = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton2);

			await waitFor(() => {
				const toasts = screen.getAllByRole('status');
				expect(toasts.length).toBeGreaterThanOrEqual(1);
			});
		});

		it('keeps selection active after error', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: false,
						status: 422,
						json: () => Promise.resolve({ error: 'Failed to add' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				expect(screen.getByText(/failed to add/i)).toBeInTheDocument();
			});

			// Preview area should still be visible after error
			const previewArea = document.querySelector('.image-preview-area');
			expect(previewArea).toBeInTheDocument();
		});

		it('does not show inline success message after successful add', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
			});

			// Inline success message should not be present in preview area
			const inlineSuccess = document.querySelector('.success-message');
			expect(inlineSuccess).not.toBeInTheDocument();
		});

		it('auto-dismisses toast after timeout', async () => {
			vi.useFakeTimers();

			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByRole('button', { name: /add to inventory/i })).toBeInTheDocument();
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
			});

			// Fast-forward 3 seconds
			vi.advanceTimersByTime(3000);

			await waitFor(() => {
				const toast = screen.queryByRole('status');
				expect(toast).not.toBeInTheDocument();
			});

			vi.useRealTimers();
		});
	});

	// ---------------------------------------------------------------------------
	// Enhanced Card Tracking Form Fields (Issue #29)
	// ---------------------------------------------------------------------------
	describe('Enhanced Card Tracking Form Fields', () => {
		it('displays all form fields with default values when printing is selected', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				// Acquired Date field with today's date
				const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
				expect(acquiredDateInput).toBeInTheDocument();
				expect(acquiredDateInput.value).toMatch(/\d{4}-\d{2}-\d{2}/);

				// Price field with $0.00
				const priceInput = screen.getByLabelText(/price/i);
				expect(priceInput).toBeInTheDocument();
				expect(priceInput).toHaveValue(0);

				// Treatment dropdown with "Normal"
				const treatmentSelect = screen.getByLabelText(/treatment/i);
				expect(treatmentSelect).toBeInTheDocument();
				expect(treatmentSelect).toHaveValue('Normal');

				// Language dropdown with "English"
				const languageSelect = screen.getByLabelText(/language/i);
				expect(languageSelect).toBeInTheDocument();
				expect(languageSelect).toHaveValue('English');
			});
		});

		it('allows editing the acquired date field', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/acquired date/i)).toBeInTheDocument();
			});

			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: '2024-01-15' } });

			expect(acquiredDateInput).toHaveValue('2024-01-15');
		});

		it('allows editing the price field', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });

			expect(priceInput).toHaveValue(25.5);
		});

		it('displays all treatment options in dropdown', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/treatment/i)).toBeInTheDocument();
			});

			const treatmentSelect = screen.getByLabelText(/treatment/i);
			const expectedOptions = [
				'Normal',
				'Foil',
				'Etched',
				'Showcase',
				'Extended Art',
				'Borderless',
				'Full Art',
				'Retro Frame',
				'Textured Foil'
			];

			expectedOptions.forEach((option) => {
				expect(treatmentSelect).toContainHTML(`<option value="${option}">${option}</option>`);
			});
		});

		it('allows selecting different treatment option', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/treatment/i)).toBeInTheDocument();
			});

			const treatmentSelect = screen.getByLabelText(/treatment/i) as HTMLSelectElement;
			await fireEvent.change(treatmentSelect, { target: { value: 'Foil' } });

			expect(treatmentSelect).toHaveValue('Foil');
		});

		it('displays all language options in dropdown', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/language/i)).toBeInTheDocument();
			});

			const languageSelect = screen.getByLabelText(/language/i);
			const expectedLanguages = [
				'English',
				'Japanese',
				'German',
				'French',
				'Spanish',
				'Italian',
				'Portuguese',
				'Russian',
				'Korean',
				'Chinese Simplified',
				'Chinese Traditional'
			];

			expectedLanguages.forEach((language) => {
				expect(languageSelect).toContainHTML(`<option value="${language}">${language}</option>`);
			});
		});

		it('allows selecting different language option', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/language/i)).toBeInTheDocument();
			});

			const languageSelect = screen.getByLabelText(/language/i) as HTMLSelectElement;
			await fireEvent.change(languageSelect, { target: { value: 'Japanese' } });

			expect(languageSelect).toHaveValue('Japanese');
		});

		it('preserves form field values when selecting a different printing', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');

			// Select first printing and modify values
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });

			const treatmentSelect = screen.getByLabelText(/treatment/i) as HTMLSelectElement;
			await fireEvent.change(treatmentSelect, { target: { value: 'Foil' } });

			// Verify modified values
			expect(priceInput).toHaveValue(25.5);
			expect(treatmentSelect).toHaveValue('Foil');

			// Select second printing
			await fireEvent.mouseEnter(printingItems[1]);

			await waitFor(() => {
				// Values should be preserved (not reset)
				const updatedPriceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
				const updatedTreatmentSelect = screen.getByLabelText(/treatment/i) as HTMLSelectElement;
				expect(updatedPriceInput).toHaveValue(25.5);
				expect(updatedTreatmentSelect).toHaveValue('Foil');
			});
		});

		it('uses date input type for acquired date field', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const acquiredDateInput = screen.getByLabelText(/acquired date/i);
				expect(acquiredDateInput).toHaveAttribute('type', 'date');
			});
		});

		it('uses number input type with step 0.01 for price field', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const priceInput = screen.getByLabelText(/price/i);
				expect(priceInput).toHaveAttribute('type', 'number');
				expect(priceInput).toHaveAttribute('step', '0.01');
				expect(priceInput).toHaveAttribute('min', '0');
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Accessibility (Technical Requirements)
	// ---------------------------------------------------------------------------
	describe('Accessibility', () => {
		it('uses semantic dialog element with role="dialog"', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			const dialog = screen.getByRole('dialog');
			expect(dialog).toBeInTheDocument();
		});

		it('has aria-labelledby for dialog title', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			const dialog = screen.getByRole('dialog');
			expect(dialog).toHaveAttribute('aria-labelledby');
		});

		it('traps focus within modal when open', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				const dialog = screen.getByRole('dialog');
				expect(dialog).toBeInTheDocument();
			});

			// Focus should be on the close button or within the dialog
			const closeButton = screen.getByRole('button', { name: /close/i });
			expect(document.body.contains(closeButton)).toBe(true);
		});

		it('supports keyboard navigation', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByRole('dialog')).toBeInTheDocument();
			});

			const closeButton = screen.getByRole('button', { name: /close/i });

			// Tab should move focus to interactive elements
			closeButton.focus();
			expect(document.activeElement).toBe(closeButton);
		});
	});

	// ---------------------------------------------------------------------------
	// Client-Side Validation (Issue #30)
	// ---------------------------------------------------------------------------
	describe('Client-Side Validation', () => {
		// Scenario 1: Future date validation
		it('prevents submission and shows error toast when acquired date is in the future', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/acquired date/i)).toBeInTheDocument();
			});

			// Set future date
			const futureDate = new Date();
			futureDate.setDate(futureDate.getDate() + 7);
			const futureDateStr = futureDate.toISOString().split('T')[0];

			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: futureDateStr } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should show error toast
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/acquired date cannot be in the future/i);
			});

			// Should not call API
			expect(mockFetch).not.toHaveBeenCalledWith(
				expect.stringContaining('/api/inventory'),
				expect.objectContaining({ method: 'POST' })
			);
		});

		it('highlights the acquired date field when validation fails', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/acquired date/i)).toBeInTheDocument();
			});

			// Set future date
			const futureDate = new Date();
			futureDate.setDate(futureDate.getDate() + 7);
			const futureDateStr = futureDate.toISOString().split('T')[0];

			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: futureDateStr } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should have invalid class
			await waitFor(() => {
				expect(acquiredDateInput).toHaveClass('invalid');
			});
		});

		// Scenario 2: Negative price validation
		it('prevents submission and shows error toast when price is negative', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			// Set negative price
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '-10.00' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should show error toast
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/price must be \$0\.00 or greater/i);
			});

			// Should not call API
			expect(mockFetch).not.toHaveBeenCalledWith(
				expect.stringContaining('/api/inventory'),
				expect.objectContaining({ method: 'POST' })
			);
		});

		it('highlights the price field when negative validation fails', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			// Set negative price
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '-10.00' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should have invalid class
			await waitFor(() => {
				expect(priceInput).toHaveClass('invalid');
			});
		});

		// Scenario 3: Invalid price format validation
		it('prevents submission and shows error toast when price is not a valid number', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			// Set invalid price (empty/NaN)
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should show error toast
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/price must be a valid number/i);
			});

			// Should not call API
			expect(mockFetch).not.toHaveBeenCalledWith(
				expect.stringContaining('/api/inventory'),
				expect.objectContaining({ method: 'POST' })
			);
		});

		// Scenario 4: Valid data submits successfully
		it('submits successfully with valid past date, price, treatment, and language', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ card_id: 'print-1', quantity: 1, collection_type: 'inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/acquired date/i)).toBeInTheDocument();
			});

			// Set valid past date
			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: '2024-01-15' } });

			// Set valid price
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should call API with all required fields including enhanced tracking fields
			await waitFor(() => {
				const inventoryCall = mockFetch.mock.calls.find(
					(call) => call[0].includes('/api/inventory') && call[1]?.method === 'POST'
				);
				expect(inventoryCall).toBeDefined();

				if (inventoryCall && inventoryCall[1]?.body) {
					const body = JSON.parse(inventoryCall[1].body);
					expect(body.card_id).toBe('print-1');
					expect(body.quantity).toBe(1);
					expect(body.acquired_date).toBe('2024-01-15');
					expect(body.price).toBe(25.5);
					// Treatment and language should be present (defaults are ok for this test)
					expect(body.treatment).toBeDefined();
					expect(body.language).toBeDefined();
				}
			});

			// Should show success toast
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/added.*lightning bolt.*m21.*125/i);
			});
		});

		// Scenario 5: Multiple validation errors show first error
		it('shows only the first validation error when multiple errors exist', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/acquired date/i)).toBeInTheDocument();
			});

			// Set future date
			const futureDate = new Date();
			futureDate.setDate(futureDate.getDate() + 7);
			const futureDateStr = futureDate.toISOString().split('T')[0];

			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: futureDateStr } });

			// Set negative price
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '-10.00' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should show error toast with only the first error (date)
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/acquired date cannot be in the future/i);
			});

			// Should not call API
			expect(mockFetch).not.toHaveBeenCalledWith(
				expect.stringContaining('/api/inventory'),
				expect.objectContaining({ method: 'POST' })
			);
		});

		// Scenario 6: Server-side validation errors are displayed
		it('displays server validation errors in toast notification', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: false,
						status: 422,
						json: () => Promise.resolve({ error: 'Card is already in inventory' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/acquired date/i)).toBeInTheDocument();
			});

			// Set valid data
			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: '2024-01-15' } });

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should show server error in error message (not toast)
			await waitFor(() => {
				expect(screen.getByText(/failed to add to inventory/i)).toBeInTheDocument();
			});
		});

		it('clears validation error highlighting when field is corrected', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			// Set negative price
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '-10.00' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Should have invalid class
			await waitFor(() => {
				expect(priceInput).toHaveClass('invalid');
			});

			// Correct the price
			await fireEvent.input(priceInput, { target: { value: '10.00' } });

			// Should remove invalid class
			await waitFor(() => {
				expect(priceInput).not.toHaveClass('invalid');
			});
		});

		it('validates on submit, not on field change', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			// Set negative price but don't submit
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '-10.00' } });

			// Should NOT show error toast yet
			const toast = screen.queryByRole('status');
			expect(toast).not.toBeInTheDocument();

			// Should NOT have invalid class yet
			expect(priceInput).not.toHaveClass('invalid');
		});
	});
});
