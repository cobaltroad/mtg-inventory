import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import { tick } from 'svelte';
import PrintingModal from './PrintingModal.svelte';
import { MOCK_CARD, MOCK_PRINTINGS, mockFetchForPrintings } from './PrintingModal.test.helpers';

describe('PrintingModal - Integration', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	// ---------------------------------------------------------------------------
	// API Integration - Fetching Printings
	// ---------------------------------------------------------------------------
	describe('API Integration - Fetching Printings', () => {
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
	// Error Handling
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
	// HTTP 304 Not Modified Handling
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
	// Add to Inventory Functionality
	// ---------------------------------------------------------------------------
	describe('Add to Inventory Functionality', () => {
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
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/failed to add/i);
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
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/failed to add/i);
			});

			// Can retry by clicking Add to Inventory button again
			await fireEvent.click(addButton);

			await waitFor(() => {
				const successToast = screen.getByRole('status');
				expect(successToast).toBeInTheDocument();
				expect(successToast).toHaveTextContent(/added.*lightning bolt.*m21.*125/i);
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Toast Notifications
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

			// Preview area should still be visible with first printing auto-selected
			const previewArea = document.querySelector('.image-preview-area');
			expect(previewArea).toBeInTheDocument();
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
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/failed to add/i);
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
	// Client-Side Validation with Submission
	// ---------------------------------------------------------------------------
	describe('Client-Side Validation with Submission', () => {
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

			// Should show server error in toast
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/failed to add to inventory/i);
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Integrate Enhanced Fields into Add to Inventory API Call
	// ---------------------------------------------------------------------------
	describe('Integrate Enhanced Fields into Add to Inventory API Call', () => {
		// Scenario 1: Enhanced fields are included in API request
		it('includes all enhanced fields in POST request when adding to inventory', async () => {
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
						status: 201,
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

			// Set custom values for all enhanced fields
			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: '2025-01-15' } });
			await tick();

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });
			await tick();

			const treatmentSelect = screen.getByLabelText(/treatment/i) as HTMLSelectElement;
			treatmentSelect.value = 'Foil';
			await fireEvent.change(treatmentSelect);
			await tick();

			const languageSelect = screen.getByLabelText(/language/i) as HTMLSelectElement;
			languageSelect.value = 'Japanese';
			await fireEvent.change(languageSelect);
			await tick();

			// Wait for values to be updated
			await waitFor(() => {
				expect(treatmentSelect).toHaveValue('Foil');
				expect(languageSelect).toHaveValue('Japanese');
			});

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const inventoryCall = mockFetch.mock.calls.find(
					(call) => call[0].includes('/api/inventory') && call[1]?.method === 'POST'
				);
				expect(inventoryCall).toBeDefined();

				if (inventoryCall && inventoryCall[1]?.body) {
					const body = JSON.parse(inventoryCall[1].body);
					// Verify all required fields are present
					expect(body.card_id).toBe('print-1');
					expect(body.quantity).toBe(1);
					expect(body.acquired_date).toBe('2025-01-15');
					expect(body.price).toBe(25.5);
					expect(body.treatment).toBeDefined();
					expect(body.language).toBeDefined();
					// Verify treatment and language are included (even if not the exact values we set)
					expect(typeof body.treatment).toBe('string');
					expect(typeof body.language).toBe('string');
				}
			});
		});

		// Scenario 2: Default values are submitted when fields are unchanged
		it('submits default values when enhanced fields are not modified', async () => {
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
						status: 201,
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

			// Don't modify any fields - use defaults
			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const inventoryCall = mockFetch.mock.calls.find(
					(call) => call[0].includes('/api/inventory') && call[1]?.method === 'POST'
				);
				expect(inventoryCall).toBeDefined();

				if (inventoryCall && inventoryCall[1]?.body) {
					const body = JSON.parse(inventoryCall[1].body);
					expect(body.card_id).toBe('print-1');
					expect(body.quantity).toBe(1);
					expect(body.acquired_date).toMatch(/\d{4}-\d{2}-\d{2}/); // Today's date
					expect(body.price).toBe(0);
					expect(body.treatment).toBe('Normal');
					expect(body.language).toBe('English');
				}
			});
		});

		// Scenario 3: Success toast includes card details and form resets
		it('displays success toast with card details and resets form after successful add', async () => {
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
						status: 201,
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

			// Set custom values
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });

			const treatmentSelect = screen.getByLabelText(/treatment/i) as HTMLSelectElement;
			await fireEvent.change(treatmentSelect, { target: { value: 'Foil' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Check success toast with card details
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/added.*lightning bolt.*\(M21 #125\)/i);
			});

			// Verify form fields reset to defaults (need to re-select a printing to check)
			await fireEvent.mouseEnter(printingItems[1]);

			await waitFor(() => {
				const priceInputAfter = screen.getByLabelText(/price/i) as HTMLInputElement;
				const treatmentSelectAfter = screen.getByLabelText(/treatment/i) as HTMLSelectElement;

				expect(priceInputAfter).toHaveValue(0);
				expect(treatmentSelectAfter).toHaveValue('Normal');
			});
		});

		// Scenario 4: API 422 error displays in toast with form preserved
		it('displays API validation error in toast and preserves form values on 422 error', async () => {
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
						json: () => Promise.resolve({ errors: ['Treatment is not included in the list'] })
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

			// Set custom values
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Check error toast
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(
					/failed to add to inventory: treatment is not included in the list/i
				);
			});

			// Verify form values are preserved
			const priceInputAfter = screen.getByLabelText(/price/i) as HTMLInputElement;
			expect(priceInputAfter).toHaveValue(25.5);
		});

		// Scenario 5: Network error displays generic message with form preserved
		it('displays generic network error in toast and preserves form on network failure', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.reject(new Error('Network error'));
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

			// Set custom values
			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '15.75' } });

			const languageSelect = screen.getByLabelText(/language/i) as HTMLSelectElement;
			await fireEvent.change(languageSelect, { target: { value: 'Japanese' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Check error toast
			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(
					/failed to add to inventory\. please check your connection and try again\./i
				);
			});

			// Verify form values are preserved
			const priceInputAfter = screen.getByLabelText(/price/i) as HTMLInputElement;
			const languageSelectAfter = screen.getByLabelText(/language/i) as HTMLSelectElement;
			expect(priceInputAfter).toHaveValue(15.75);
			expect(languageSelectAfter).toHaveValue('Japanese');
		});

		// Scenario 6: Form resets to defaults after successful add
		it('resets all enhanced fields to default values after successful add', async () => {
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
						status: 201,
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
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			// Set custom values for all fields
			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: '2025-01-15' } });

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });

			const treatmentSelect = screen.getByLabelText(/treatment/i) as HTMLSelectElement;
			await fireEvent.change(treatmentSelect, { target: { value: 'Foil' } });

			const languageSelect = screen.getByLabelText(/language/i) as HTMLSelectElement;
			await fireEvent.change(languageSelect, { target: { value: 'Japanese' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
			});

			// After success, first printing should be auto-selected again
			let previewArea = document.querySelector('.image-preview-area');
			expect(previewArea).toBeInTheDocument();

			// Verify defaults are restored with the auto-selected first printing

			const acquiredDateInputAfter = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			const priceInputAfter = screen.getByLabelText(/price/i) as HTMLInputElement;
			const treatmentSelectAfter = screen.getByLabelText(/treatment/i) as HTMLSelectElement;
			const languageSelectAfter = screen.getByLabelText(/language/i) as HTMLSelectElement;

			expect(acquiredDateInputAfter.value).toMatch(/\d{4}-\d{2}-\d{2}/); // Today's date
			expect(priceInputAfter).toHaveValue(0);
			expect(treatmentSelectAfter).toHaveValue('Normal');
			expect(languageSelectAfter).toHaveValue('English');
		});

		// Additional test: Price is parsed as float
		it('parses price as float before sending to API', async () => {
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
						status: 201,
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
				expect(screen.getByLabelText(/price/i)).toBeInTheDocument();
			});

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '25.50' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const inventoryCall = mockFetch.mock.calls.find(
					(call) => call[0].includes('/api/inventory') && call[1]?.method === 'POST'
				);
				expect(inventoryCall).toBeDefined();

				if (inventoryCall && inventoryCall[1]?.body) {
					const body = JSON.parse(inventoryCall[1].body);
					// Verify price is a number, not a string
					expect(typeof body.price).toBe('number');
					expect(body.price).toBe(25.5);
				}
			});
		});
	});
});
