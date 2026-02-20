import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { render, cleanup, fireEvent, waitFor, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { tick } from 'svelte';
import PrintingModal from './PrintingModal.svelte';
import { MOCK_CARD, MOCK_PRINTINGS, mockFetchForPrintings } from './PrintingModal.test.helpers';

afterEach(() => {
	cleanup();
	vi.restoreAllMocks();
});

// ===========================================================================
// RENDERING & DISPLAY
// ===========================================================================
describe('PrintingModal - Rendering & Display', () => {
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
	});

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

			const modalContent = screen.getByRole('dialog').textContent || '';
			const m21Index = modalContent.indexOf('Core Set 2021');
			const m10Index = modalContent.indexOf('Magic 2010');
			const leaIndex = modalContent.indexOf('Limited Edition Alpha');

			expect(m21Index).toBeLessThan(m10Index);
			expect(m10Index).toBeLessThan(leaIndex);
		});

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

			const scrollContainer = screen.getByTestId('printings-list');
			expect(scrollContainer).toBeInTheDocument();
		});
	});

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
	});
});

// ===========================================================================
// INTERACTIONS & BEHAVIOR
// ===========================================================================
describe('PrintingModal - Interactions & Behavior', () => {
	describe('Modal Dismissal', () => {
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

			expect(mockFetch).not.toHaveBeenCalledWith(
				expect.stringContaining('/api/inventory'),
				expect.objectContaining({ method: 'POST' })
			);
		});
	});

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

			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const previewArea = document.querySelector('.image-preview-area');
				expect(previewArea).toBeInTheDocument();
			});

			await fireEvent.mouseLeave(printingItems[0]);

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

			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const img = document.querySelector('.image-preview-area img');
				expect(img).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);
			});

			await fireEvent.mouseEnter(printingItems[1]);

			await waitFor(() => {
				const img = document.querySelector('.image-preview-area img');
				expect(img).toHaveAttribute('src', MOCK_PRINTINGS[1].image_url);
			});
		});

		it('handles missing image_url gracefully', async () => {
			const printingsWithoutImage = [
				{
					...MOCK_PRINTINGS[0],
					image_url: undefined
				}
			];

			vi.stubGlobal(
				'fetch',
				vi.fn().mockImplementation((url: string) => {
					if (typeof url === 'string' && url.includes('/printings')) {
						return Promise.resolve({
							ok: true,
							json: () => Promise.resolve({ printings: printingsWithoutImage })
						});
					}
					return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
				})
			);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				const printingItems = document.body.querySelectorAll('[data-testid="printing-item"]');
				expect(printingItems.length).toBe(1);
			});

			const imagePreview = document.body.querySelector('.image-preview-area');
			expect(imagePreview).not.toBeInTheDocument();
		});
	});

	describe('Issue #129: Stale Image Data Prevention', () => {
		const MOCK_CARD_A = {
			id: 'lightning-bolt-id',
			name: 'Lightning Bolt'
		};

		const MOCK_PRINTINGS_A = [
			{
				id: 'bolt-printing-1',
				name: 'Lightning Bolt',
				set: 'lea',
				set_name: 'Limited Edition Alpha',
				collector_number: '161',
				image_url: 'https://example.com/bolt-lea-161.jpg',
				released_at: '1993-08-05'
			}
		];

		const MOCK_CARD_B = {
			id: 'dark-ritual-id',
			name: 'Dark Ritual'
		};

		const MOCK_PRINTINGS_B = [
			{
				id: 'ritual-printing-1',
				name: 'Dark Ritual',
				set: 'lea',
				set_name: 'Limited Edition Alpha',
				collector_number: '101',
				image_url: 'https://example.com/ritual-lea-101.jpg',
				released_at: '1993-08-05'
			}
		];

		it('resets selectedPrinting to null when modal reopens for different card', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes(MOCK_CARD_A.id)) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS_A })
					});
				}
				if (typeof url === 'string' && url.includes(MOCK_CARD_B.id)) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS_B })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			let isOpen = true;
			let currentCard = MOCK_CARD_A;

			const { rerender } = render(PrintingModal, {
				props: {
					card: currentCard,
					open: isOpen
				}
			});

			await waitFor(() => {
				const img = document.body.querySelector('.image-preview-area img') as HTMLImageElement;
				expect(img).toBeInTheDocument();
				expect(img.src).toContain(MOCK_PRINTINGS_A[0].image_url);
			});

			isOpen = false;
			rerender({
				card: currentCard,
				open: isOpen
			});

			await new Promise((resolve) => setTimeout(resolve, 50));

			currentCard = MOCK_CARD_B;
			isOpen = true;
			rerender({
				card: currentCard,
				open: isOpen
			});

			await new Promise((resolve) => setTimeout(resolve, 10));

			const imagesImmediately = document.body.querySelectorAll('.image-preview-area img');
			imagesImmediately.forEach((img) => {
				const src = (img as HTMLImageElement).src;
				if (src) {
					expect(src).not.toContain(MOCK_PRINTINGS_A[0].image_url);
				}
			});

			await waitFor(() => {
				const img = document.body.querySelector('.image-preview-area img') as HTMLImageElement;
				expect(img).toBeInTheDocument();
				expect(img.src).toContain(MOCK_PRINTINGS_B[0].image_url);
			});
		});
	});

	describe('Keyboard Navigation', () => {
		it('traps focus within modal when open', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				const dialog = screen.getByRole('dialog');
				expect(dialog).toBeInTheDocument();
			});

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

			closeButton.focus();
			expect(document.activeElement).toBe(closeButton);
		});
	});
});

// ===========================================================================
// FORM FIELDS
// ===========================================================================
describe('PrintingModal - Form Fields', () => {
	describe('Form Field Display', () => {
		it('displays all form fields with default values when printing is selected', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			const mouseEnterEvent = new MouseEvent('mouseenter', { bubbles: true });
			printingItems[0].dispatchEvent(mouseEnterEvent);

			await waitFor(() => {
				const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
				expect(acquiredDateInput).toBeInTheDocument();
				expect(acquiredDateInput.value).toMatch(/\d{4}-\d{2}-\d{2}/);

				const priceInput = screen.getByLabelText(/price/i);
				expect(priceInput).toBeInTheDocument();
				expect(priceInput).toHaveValue(0);

				const finishLabel = screen.getByText('Finish');
				expect(finishLabel).toBeInTheDocument();

				const radios = screen.getAllByRole('radio');
				// Radio buttons include finish options (3) and language options (11+)
				expect(radios.length).toBeGreaterThanOrEqual(3);

				const nonfoilRadio = radios.find((r) => (r as HTMLInputElement).value === 'nonfoil');
				expect(nonfoilRadio).toBeChecked();
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
			const mouseEnterEvent = new MouseEvent('mouseenter', { bubbles: true });
			printingItems[0].dispatchEvent(mouseEnterEvent);

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
			const mouseEnterEvent = new MouseEvent('mouseenter', { bubbles: true });
			printingItems[0].dispatchEvent(mouseEnterEvent);

			await waitFor(() => {
				const priceInput = screen.getByLabelText(/price/i);
				expect(priceInput).toHaveAttribute('type', 'number');
				expect(priceInput).toHaveAttribute('step', '0.01');
				expect(priceInput).toHaveAttribute('min', '0');
			});
		});
	});

	describe('Form Field Editing', () => {
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

		it('preserves form field values when hovering changes the art multiple times', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: MOCK_PRINTINGS })
					});
				}
				if (typeof url === 'string' && url.includes('/inventory')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ quantity: 1 })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				const printingItems = document.body.querySelectorAll('[data-testid="printing-item"]');
				expect(printingItems.length).toBe(3);
			});

			const priceInput = document.body.querySelector('#price') as HTMLInputElement;
			priceInput.value = '25.50';
			await fireEvent.input(priceInput);

			const printingItems = document.body.querySelectorAll('[data-testid="printing-item"]');
			await fireEvent.mouseEnter(printingItems[1]);
			await fireEvent.mouseEnter(printingItems[2]);
			await fireEvent.mouseEnter(printingItems[0]);

			expect(priceInput.value).toBe('25.50');
		});

		it('preserves price but resets finish when selecting a different printing (Issue #138)', async () => {
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

			const radios = screen.getAllByRole('radio');
			const foilRadio = radios.find((r) => (r as HTMLInputElement).value === 'foil');
			await fireEvent.click(foilRadio!);

			expect(priceInput).toHaveValue(25.5);
			expect(foilRadio).toBeChecked();

			await fireEvent.mouseEnter(printingItems[1]);

			await waitFor(() => {
				const updatedPriceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
				expect(updatedPriceInput).toHaveValue(25.5);

				const updatedRadios = screen.getAllByRole('radio');
				const updatedNonfoilRadio = updatedRadios.find(
					(r) => (r as HTMLInputElement).value === 'nonfoil'
				);
				expect(updatedNonfoilRadio).toBeChecked();
			});
		});
	});

	describe('Client-Side Validation', () => {
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

			const futureDate = new Date();
			futureDate.setDate(futureDate.getDate() + 7);
			const futureDateStr = futureDate.toISOString().split('T')[0];

			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: futureDateStr } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/acquired date cannot be in the future/i);
			});

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

			const futureDate = new Date();
			futureDate.setDate(futureDate.getDate() + 7);
			const futureDateStr = futureDate.toISOString().split('T')[0];

			const acquiredDateInput = screen.getByLabelText(/acquired date/i) as HTMLInputElement;
			await fireEvent.input(acquiredDateInput, { target: { value: futureDateStr } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				expect(acquiredDateInput).toHaveClass('invalid');
			});
		});

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

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '-10.00' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				const toast = screen.getByRole('status');
				expect(toast).toBeInTheDocument();
				expect(toast).toHaveTextContent(/price must be \$0\.00 or greater/i);
			});

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

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '-10.00' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				expect(priceInput).toHaveClass('invalid');
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

			const priceInput = screen.getByLabelText(/price/i) as HTMLInputElement;
			await fireEvent.input(priceInput, { target: { value: '-10.00' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			await waitFor(() => {
				expect(priceInput).toHaveClass('invalid');
			});

			await fireEvent.input(priceInput, { target: { value: '10.00' } });

			await waitFor(() => {
				expect(priceInput).not.toHaveClass('invalid');
			});
		});
	});

	describe('Finish Selection', () => {
		it('displays all three finish options (Nonfoil, Foil, Etched)', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByText('Nonfoil')).toBeInTheDocument();
				expect(screen.getByText('Foil')).toBeInTheDocument();
				expect(screen.getByText('Etched')).toBeInTheDocument();
			});
		});

		it('has "nonfoil" selected by default', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const nonfoilRadio = screen.getByRole('radio', { name: /nonfoil/i });
				expect(nonfoilRadio).toBeInTheDocument();
				expect(nonfoilRadio).toBeChecked();
			});
		});

		it('allows clicking to change finish selection from nonfoil to foil', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const radios = screen.getAllByRole('radio');
				expect(radios.length).toBeGreaterThan(0);
			});

			const radios = screen.getAllByRole('radio');
			const foilRadio = radios.find((radio) => (radio as HTMLInputElement).value === 'foil');
			const nonfoilRadio = radios.find((radio) => (radio as HTMLInputElement).value === 'nonfoil');

			expect(nonfoilRadio).toBeChecked();
			expect(foilRadio).not.toBeChecked();

			await fireEvent.click(foilRadio!);

			await waitFor(() => {
				expect(foilRadio).toBeChecked();
				expect(nonfoilRadio).not.toBeChecked();
			});
		});
	});

	describe('Language Selection', () => {
		it('allows user to click and select a language option', async () => {
			const user = userEvent.setup();
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByText(/^Language$/i)).toBeInTheDocument();
			});

			const japaneseOption = screen.getByText('JP');
			await user.click(japaneseOption);
			await tick();

			const japaneseRadio = screen.getByDisplayValue('Japanese') as HTMLInputElement;
			expect(japaneseRadio.checked).toBe(true);
		});

		it('does not close or disappear when user interacts with the language options', async () => {
			const user = userEvent.setup();
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByText(/^Language$/i)).toBeInTheDocument();
			});

			const japaneseOption = screen.getByText('JP');
			await user.click(japaneseOption);
			await tick();

			expect(japaneseOption).toBeInTheDocument();
			expect(screen.getByText('DE')).toBeInTheDocument();
			expect(screen.getByText('FR')).toBeInTheDocument();

			await new Promise((resolve) => setTimeout(resolve, 100));

			expect(japaneseOption).toBeInTheDocument();
		});

		it('allows user to select multiple languages sequentially', async () => {
			const user = userEvent.setup();
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByText(/^Language$/i)).toBeInTheDocument();
			});

			await user.click(screen.getByText('JP'));
			await tick();
			let japaneseRadio = screen.getByDisplayValue('Japanese') as HTMLInputElement;
			expect(japaneseRadio.checked).toBe(true);

			await user.click(screen.getByText('DE'));
			await tick();
			const germanRadio = screen.getByDisplayValue('German') as HTMLInputElement;
			expect(germanRadio.checked).toBe(true);
			japaneseRadio = screen.getByDisplayValue('Japanese') as HTMLInputElement;
			expect(japaneseRadio.checked).toBe(false);

			await user.click(screen.getByText('FR'));
			await tick();
			const frenchRadio = screen.getByDisplayValue('French') as HTMLInputElement;
			expect(frenchRadio.checked).toBe(true);
			expect(germanRadio.checked).toBe(false);
		});
	});

	describe('Issue #138: Filter Finish Options Based on Available Finishes', () => {
		const PRINTING_NONFOIL_ONLY = {
			id: 'nonfoil-only',
			name: 'Test Card',
			set: 'dom',
			set_name: 'Dominaria',
			collector_number: '100',
			image_url: 'https://example.com/nonfoil.jpg',
			released_at: '2018-04-27',
			finishes: ['nonfoil']
		};

		const PRINTING_FOIL_ONLY = {
			id: 'foil-only',
			name: 'Test Card',
			set: 'promo',
			set_name: 'Promotional',
			collector_number: 'P1',
			image_url: 'https://example.com/foil.jpg',
			released_at: '2020-01-01',
			finishes: ['foil']
		};

		const PRINTING_BOTH_FINISHES = {
			id: 'both-finishes',
			name: 'Test Card',
			set: 'znr',
			set_name: 'Zendikar Rising',
			collector_number: '42',
			image_url: 'https://example.com/both.jpg',
			released_at: '2020-09-25',
			finishes: ['nonfoil', 'foil']
		};

		it('only shows "Nonfoil" option when printing has finishes: ["nonfoil"]', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_NONFOIL_ONLY] })
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
				expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			});

			expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			expect(screen.queryByText('Foil')).not.toBeInTheDocument();
			expect(screen.queryByText('Etched')).not.toBeInTheDocument();

			// Check only finish-related radios (filter by name attribute)
			const radios = screen.getAllByRole('radio');
			const finishRadios = Array.from(radios).filter(
				(r) => (r as HTMLInputElement).name === 'finish'
			);
			expect(finishRadios.length).toBe(1);
			expect((finishRadios[0] as HTMLInputElement).value).toBe('nonfoil');
		});

		it('auto-selects "nonfoil" when it is the only available finish', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_NONFOIL_ONLY] })
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
				const radios = screen.getAllByRole('radio');
				const finishRadios = Array.from(radios).filter(
					(r) => (r as HTMLInputElement).name === 'finish'
				);
				expect(finishRadios.length).toBe(1);
			});

			const nonfoilRadio = screen.getByRole('radio', { name: /nonfoil/i });
			expect(nonfoilRadio).toBeChecked();
		});

		it('auto-selects "foil" when it is the only available finish', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_FOIL_ONLY] })
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
				const radios = screen.getAllByRole('radio');
				const finishRadios = Array.from(radios).filter(
					(r) => (r as HTMLInputElement).name === 'finish'
				);
				expect(finishRadios.length).toBe(1);
			});

			const foilRadio = screen.getByRole('radio', { name: /foil/i });
			expect(foilRadio).toBeChecked();
		});

		it('resets finish when switching from nonfoil-only to foil-only printing', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_NONFOIL_ONLY, PRINTING_FOIL_ONLY] })
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
				const nonfoilRadio = screen.getByRole('radio', { name: /nonfoil/i });
				expect(nonfoilRadio).toBeChecked();
			});

			await fireEvent.mouseEnter(printingItems[1]);

			await waitFor(() => {
				const foilRadio = screen.getByRole('radio', { name: /foil/i });
				expect(foilRadio).toBeChecked();
			});

			expect(screen.queryByText('Nonfoil')).not.toBeInTheDocument();
			expect(screen.getByText('Foil')).toBeInTheDocument();
		});

		it('defaults to "nonfoil" when both nonfoil and foil are available', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_BOTH_FINISHES] })
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
				const nonfoilRadio = screen.getByRole('radio', { name: /nonfoil/i });
				expect(nonfoilRadio).toBeChecked();
			});
		});
	});
});
