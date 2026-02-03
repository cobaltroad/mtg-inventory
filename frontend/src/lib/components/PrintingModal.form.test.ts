import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import PrintingModal from './PrintingModal.svelte';
import { MOCK_CARD, MOCK_PRINTINGS, mockFetchForPrintings } from './PrintingModal.test.helpers';

describe('PrintingModal - Form', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	// ---------------------------------------------------------------------------
	// Enhanced Card Tracking Form Fields
	// ---------------------------------------------------------------------------
	describe('Enhanced Card Tracking Form Fields', () => {
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
	});

	// ---------------------------------------------------------------------------
	// Client-Side Validation
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

		// Scenario 4: Multiple validation errors show first error
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
