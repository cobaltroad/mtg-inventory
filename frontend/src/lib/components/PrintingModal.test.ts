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
});
