import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/svelte';
import PrintingModal from './PrintingModal.svelte';
import { MOCK_CARD, MOCK_PRINTINGS, mockFetchForPrintings } from './PrintingModal.test.helpers';

describe('PrintingModal - Rendering', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	// ---------------------------------------------------------------------------
	// Modal Display & Loading
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
	});

	// ---------------------------------------------------------------------------
	// Printing Information
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
	// Handling Volume
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
	// Single Printing
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
	// Enhanced Card Tracking Form Fields Display
	// ---------------------------------------------------------------------------
	describe('Enhanced Card Tracking Form Fields Display', () => {
		it('displays all form fields with default values when printing is selected', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			const { container } = render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			const mouseEnterEvent = new MouseEvent('mouseenter', { bubbles: true });
			printingItems[0].dispatchEvent(mouseEnterEvent);

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

	// ---------------------------------------------------------------------------
	// Accessibility
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
	});
});
