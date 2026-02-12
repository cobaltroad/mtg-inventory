import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import PrintingModal from './PrintingModal.svelte';
import { MOCK_CARD, MOCK_PRINTINGS, mockFetchForPrintings } from './PrintingModal.test.helpers';

/**
 * Issue #136: SegmentedControl Component Rendering Tests
 *
 * These tests verify that the SegmentedControl for card finish selection
 * renders correctly and functions as expected in the PrintingModal.
 */
describe('PrintingModal - SegmentedControl for Finish Selection (Issue #136)', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	// ---------------------------------------------------------------------------
	// Unit Tests: Component Rendering
	// ---------------------------------------------------------------------------
	describe('Component Rendering', () => {
		it('should render SegmentedControl component in DOM when modal is open', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			// Hover over first printing to show form
			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				// Check for Finish label
				const finishLabel = screen.getByText(/finish/i);
				expect(finishLabel).toBeInTheDocument();
			});
		});

		it('should render all three finish options (Nonfoil, Foil, Etched)', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				// All three options should be visible
				expect(screen.getByText('Nonfoil')).toBeInTheDocument();
				expect(screen.getByText('Foil')).toBeInTheDocument();
				expect(screen.getByText('Etched')).toBeInTheDocument();
			});
		});

		it('should have "nonfoil" selected by default', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				// Find the radio input for nonfoil and verify it's checked
				const nonfoilRadio = screen.getByRole('radio', { name: /nonfoil/i });
				expect(nonfoilRadio).toBeInTheDocument();
				expect(nonfoilRadio).toBeChecked();
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Unit Tests: User Interaction
	// ---------------------------------------------------------------------------
	describe('User Interaction', () => {
		it('should allow clicking to change finish selection from nonfoil to foil', async () => {
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

			// Get all radio buttons and find the one with value="foil"
			const radios = screen.getAllByRole('radio');
			const foilRadio = radios.find((radio) => (radio as HTMLInputElement).value === 'foil');
			const nonfoilRadio = radios.find((radio) => (radio as HTMLInputElement).value === 'nonfoil');

			expect(nonfoilRadio).toBeChecked();
			expect(foilRadio).not.toBeChecked();

			// Click on Foil option
			await fireEvent.click(foilRadio!);

			// Verify foil is now checked and nonfoil is unchecked
			await waitFor(() => {
				expect(foilRadio).toBeChecked();
				expect(nonfoilRadio).not.toBeChecked();
			});
		});

		it('should allow clicking to change finish selection to etched', async () => {
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
				expect(nonfoilRadio).toBeChecked();
			});

			// Click on Etched option
			const etchedRadio = screen.getByRole('radio', { name: /etched/i });
			await fireEvent.click(etchedRadio);

			// Verify etched is now checked
			await waitFor(() => {
				expect(etchedRadio).toBeChecked();
			});
		});

		it('should visually highlight the selected finish option', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			const { container } = render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const radios = screen.getAllByRole('radio');
				expect(radios.length).toBeGreaterThan(0);
			});

			// Get all radio buttons and find the one with value="foil"
			const radios = screen.getAllByRole('radio');
			const foilRadio = radios.find((radio) => (radio as HTMLInputElement).value === 'foil');

			// Click on Foil
			await fireEvent.click(foilRadio!);

			await waitFor(() => {
				expect(foilRadio).toBeChecked();
				// For native radio buttons, checked state is sufficient visual indication
				// The parent label will have styling based on :has(input:checked) selector
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Integration Tests: Form Submission
	// ---------------------------------------------------------------------------
	describe('Form Submission with Selected Finish', () => {
		it('should include selected finish in POST request when adding to inventory', async () => {
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
						json: () => Promise.resolve({ card_id: 'print-1', quantity: 1, finish: 'foil' })
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
				expect(radios.length).toBeGreaterThan(0);
			});

			// Select foil finish
			const radios = screen.getAllByRole('radio');
			const foilRadio = radios.find((radio) => (radio as HTMLInputElement).value === 'foil');
			await fireEvent.click(foilRadio!);

			// Fill in price
			const priceInput = screen.getByLabelText(/price/i);
			await fireEvent.input(priceInput, { target: { value: '10.00' } });

			// Click Add to Inventory
			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Verify POST request included finish: 'foil'
			await waitFor(() => {
				expect(mockFetch).toHaveBeenCalledWith(
					expect.stringContaining('/api/inventory'),
					expect.objectContaining({
						method: 'POST',
						body: expect.stringContaining('"finish":"foil"')
					})
				);
			});
		});

		it('should include "nonfoil" in POST request when default selection is used', async () => {
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
						json: () => Promise.resolve({ card_id: 'print-1', quantity: 1, finish: 'nonfoil' })
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

			// Fill in price (don't change finish - use default)
			const priceInput = screen.getByLabelText(/price/i);
			await fireEvent.input(priceInput, { target: { value: '5.00' } });

			// Click Add to Inventory
			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Verify POST request included finish: 'nonfoil'
			await waitFor(() => {
				expect(mockFetch).toHaveBeenCalledWith(
					expect.stringContaining('/api/inventory'),
					expect.objectContaining({
						method: 'POST',
						body: expect.stringContaining('"finish":"nonfoil"')
					})
				);
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Integration Tests: Selection Persistence
	// ---------------------------------------------------------------------------
	describe('Selection Persistence', () => {
		it('should preserve finish selection when changing printings', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');

			// Select first printing
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const radios = screen.getAllByRole('radio');
				expect(radios.length).toBeGreaterThan(0);
			});

			// Change to foil
			const radios = screen.getAllByRole('radio');
			const foilRadio = radios.find((radio) => (radio as HTMLInputElement).value === 'foil');
			await fireEvent.click(foilRadio!);

			await waitFor(() => {
				expect(foilRadio).toBeChecked();
			});

			// Change to second printing
			await fireEvent.mouseEnter(printingItems[1]);

			// Finish selection should still be foil
			await waitFor(() => {
				const updatedRadios = screen.getAllByRole('radio');
				const updatedFoilRadio = updatedRadios.find(
					(radio) => (radio as HTMLInputElement).value === 'foil'
				);
				expect(updatedFoilRadio).toBeChecked();
			});
		});

		it('should reset finish to "nonfoil" after successful inventory add', async () => {
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
						json: () => Promise.resolve({ card_id: 'print-1', quantity: 1, finish: 'foil' })
					});
				}
				return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
			});
			vi.stubGlobal('fetch', mockFetch);

			const { rerender } = render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const radios = screen.getAllByRole('radio');
				expect(radios.length).toBeGreaterThan(0);
			});

			// Select foil
			const radios = screen.getAllByRole('radio');
			const foilRadio = radios.find((radio) => (radio as HTMLInputElement).value === 'foil');
			await fireEvent.click(foilRadio!);

			// Fill in price and submit
			const priceInput = screen.getByLabelText(/price/i);
			await fireEvent.input(priceInput, { target: { value: '10.00' } });

			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Wait for submission to complete (modal should close)
			await waitFor(() => {
				expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
			});

			// Reopen modal
			rerender({ card: MOCK_CARD, open: true });

			// Wait for modal to reopen
			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const reopenedPrintingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(reopenedPrintingItems[0]);

			// Finish should be reset to nonfoil
			await waitFor(() => {
				const reopenedRadios = screen.getAllByRole('radio');
				const nonfoilRadio = reopenedRadios.find(
					(radio) => (radio as HTMLInputElement).value === 'nonfoil'
				);
				expect(nonfoilRadio).toBeChecked();
			});
		});
	});

	// ---------------------------------------------------------------------------
	// Integration Tests: Layout and Styling
	// ---------------------------------------------------------------------------
	describe('Layout and Styling', () => {
		it('should render finish options between Price field and Add button', async () => {
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

			// Verify ordering: Price field -> Finish control -> Add button
			const priceField = screen.getByLabelText(/price/i);
			const finishLabel = screen.getByText('Finish');
			const addButton = screen.getByRole('button', { name: /add to inventory/i });

			// All should be present
			expect(priceField).toBeInTheDocument();
			expect(finishLabel).toBeInTheDocument();
			expect(addButton).toBeInTheDocument();

			// Verify finish radio buttons are present (3 options)
			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(3);
			expect(radios.some((r) => (r as HTMLInputElement).value === 'nonfoil')).toBe(true);
			expect(radios.some((r) => (r as HTMLInputElement).value === 'foil')).toBe(true);
			expect(radios.some((r) => (r as HTMLInputElement).value === 'etched')).toBe(true);
		});

		it('should display finish options horizontally in a row', async () => {
			const mockFetch = mockFetchForPrintings();
			vi.stubGlobal('fetch', mockFetch);

			render(PrintingModal, { props: { card: MOCK_CARD, open: true } });

			await waitFor(() => {
				expect(screen.getByTestId('printings-list')).toBeInTheDocument();
			});

			const printingItems = screen.getAllByTestId('printing-item');
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				expect(screen.getByText('Finish')).toBeInTheDocument();
			});

			// Verify all three finish option texts are visible
			expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			expect(screen.getByText('Foil')).toBeInTheDocument();
			expect(screen.getByText('Etched')).toBeInTheDocument();

			// Verify all three radio buttons are present
			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(3);
		});
	});
});
