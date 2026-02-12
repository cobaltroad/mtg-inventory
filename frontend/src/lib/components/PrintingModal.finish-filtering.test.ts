import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import PrintingModal from './PrintingModal.svelte';
import { MOCK_CARD, mockFetchForPrintings } from './PrintingModal.test.helpers';

/**
 * Issue #138: Filter Finish Options Based on Available Finishes
 *
 * These tests verify that the finish selector only shows options that are
 * actually available for a specific card printing based on Scryfall's finishes array.
 *
 * Test coverage:
 * - Filter finish options based on printing.finishes array
 * - Auto-select when only one finish is available
 * - Handle missing/empty finishes data gracefully (fallback to all options)
 * - Reset finish selection when changing printings
 * - Maintain keyboard accessibility
 * - Default priority: nonfoil > foil > etched
 */
describe('PrintingModal - Finish Filtering (Issue #138)', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	// ---------------------------------------------------------------------------
	// Test Data: Printings with different finish availability
	// ---------------------------------------------------------------------------
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

	const PRINTING_ALL_FINISHES = {
		id: 'all-finishes',
		name: 'Test Card',
		set: 'mh2',
		set_name: 'Modern Horizons 2',
		collector_number: '200',
		image_url: 'https://example.com/all.jpg',
		released_at: '2021-06-18',
		finishes: ['nonfoil', 'foil', 'etched']
	};

	const PRINTING_NO_FINISHES = {
		id: 'no-finishes',
		name: 'Old Card',
		set: 'lea',
		set_name: 'Alpha',
		collector_number: '1',
		image_url: 'https://example.com/old.jpg',
		released_at: '1993-08-05'
		// No finishes array (older data)
	};

	const PRINTING_EMPTY_FINISHES = {
		id: 'empty-finishes',
		name: 'Test Card',
		set: 'tst',
		set_name: 'Test Set',
		collector_number: '99',
		image_url: 'https://example.com/empty.jpg',
		released_at: '2020-01-01',
		finishes: []
	};

	// ---------------------------------------------------------------------------
	// Unit Tests: Filter finish options based on available finishes
	// ---------------------------------------------------------------------------
	describe('Filter finish options', () => {
		it('should only show "Nonfoil" option when printing has finishes: ["nonfoil"]', async () => {
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

			// Should only have Nonfoil option visible
			expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			expect(screen.queryByText('Foil')).not.toBeInTheDocument();
			expect(screen.queryByText('Etched')).not.toBeInTheDocument();

			// Should have only 1 radio button
			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(1);
			expect((radios[0] as HTMLInputElement).value).toBe('nonfoil');
		});

		it('should only show "Foil" option when printing has finishes: ["foil"]', async () => {
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
				expect(screen.getByText('Foil')).toBeInTheDocument();
			});

			// Should only have Foil option visible
			expect(screen.queryByText('Nonfoil')).not.toBeInTheDocument();
			expect(screen.getByText('Foil')).toBeInTheDocument();
			expect(screen.queryByText('Etched')).not.toBeInTheDocument();

			// Should have only 1 radio button
			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(1);
			expect((radios[0] as HTMLInputElement).value).toBe('foil');
		});

		it('should show "Nonfoil" and "Foil" when printing has finishes: ["nonfoil", "foil"]', async () => {
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
				expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			});

			// Should have Nonfoil and Foil options
			expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			expect(screen.getByText('Foil')).toBeInTheDocument();
			expect(screen.queryByText('Etched')).not.toBeInTheDocument();

			// Should have 2 radio buttons
			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(2);
		});

		it('should show all three options when printing has finishes: ["nonfoil", "foil", "etched"]', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_ALL_FINISHES] })
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

			// Should have all three options
			expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			expect(screen.getByText('Foil')).toBeInTheDocument();
			expect(screen.getByText('Etched')).toBeInTheDocument();

			// Should have 3 radio buttons
			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(3);
		});
	});

	// ---------------------------------------------------------------------------
	// Unit Tests: Auto-select when only one finish is available
	// ---------------------------------------------------------------------------
	describe('Auto-select single finish option', () => {
		it('should auto-select "nonfoil" when it is the only available finish', async () => {
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
				expect(radios.length).toBe(1);
			});

			const nonfoilRadio = screen.getByRole('radio', { name: /nonfoil/i });
			expect(nonfoilRadio).toBeChecked();
		});

		it('should auto-select "foil" when it is the only available finish', async () => {
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
				expect(radios.length).toBe(1);
			});

			const foilRadio = screen.getByRole('radio', { name: /foil/i });
			expect(foilRadio).toBeChecked();
		});
	});

	// ---------------------------------------------------------------------------
	// Unit Tests: Handle missing/empty finishes data gracefully
	// ---------------------------------------------------------------------------
	describe('Handle missing finishes data', () => {
		it('should show all three finish options when finishes array is missing', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_NO_FINISHES] })
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

			// Should show all three options as fallback
			expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			expect(screen.getByText('Foil')).toBeInTheDocument();
			expect(screen.getByText('Etched')).toBeInTheDocument();

			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(3);
		});

		it('should show all three finish options when finishes array is empty', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_EMPTY_FINISHES] })
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

			// Should show all three options as fallback
			expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			expect(screen.getByText('Foil')).toBeInTheDocument();
			expect(screen.getByText('Etched')).toBeInTheDocument();

			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(3);
		});
	});

	// ---------------------------------------------------------------------------
	// Unit Tests: Reset finish selection when changing printings
	// ---------------------------------------------------------------------------
	describe('Reset finish when changing printings', () => {
		it('should reset finish when switching from nonfoil-only to foil-only printing', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ printings: [PRINTING_NONFOIL_ONLY, PRINTING_FOIL_ONLY] })
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

			// Select first printing (nonfoil only)
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const nonfoilRadio = screen.getByRole('radio', { name: /nonfoil/i });
				expect(nonfoilRadio).toBeChecked();
			});

			// Switch to second printing (foil only)
			await fireEvent.mouseEnter(printingItems[1]);

			await waitFor(() => {
				const foilRadio = screen.getByRole('radio', { name: /foil/i });
				expect(foilRadio).toBeChecked();
			});

			// Should not show nonfoil anymore
			expect(screen.queryByText('Nonfoil')).not.toBeInTheDocument();
			expect(screen.getByText('Foil')).toBeInTheDocument();
		});

		it('should default to nonfoil when switching to printing with multiple finishes', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () =>
							Promise.resolve({ printings: [PRINTING_FOIL_ONLY, PRINTING_BOTH_FINISHES] })
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

			// Select first printing (foil only)
			await fireEvent.mouseEnter(printingItems[0]);

			await waitFor(() => {
				const foilRadio = screen.getByRole('radio', { name: /foil/i });
				expect(foilRadio).toBeChecked();
			});

			// Switch to second printing (nonfoil and foil)
			await fireEvent.mouseEnter(printingItems[1]);

			await waitFor(() => {
				expect(screen.getByText('Nonfoil')).toBeInTheDocument();
			});

			// Should default to nonfoil (priority: nonfoil > foil > etched)
			const nonfoilRadio = screen.getByRole('radio', { name: /nonfoil/i });
			expect(nonfoilRadio).toBeChecked();
		});
	});

	// ---------------------------------------------------------------------------
	// Unit Tests: Default selection priority (nonfoil > foil > etched)
	// ---------------------------------------------------------------------------
	describe('Default selection priority', () => {
		it('should default to "nonfoil" when both nonfoil and foil are available', async () => {
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

		it('should default to "nonfoil" when all three finishes are available', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_ALL_FINISHES] })
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

	// ---------------------------------------------------------------------------
	// Integration Tests: Form submission with filtered finishes
	// ---------------------------------------------------------------------------
	describe('Form submission with filtered finishes', () => {
		it('should submit correct finish when only one option is available', async () => {
			const mockFetch = vi.fn().mockImplementation((url: string, opts?: RequestInit) => {
				if (typeof url === 'string' && url.includes('/printings')) {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ printings: [PRINTING_FOIL_ONLY] })
					});
				}
				if (typeof url === 'string' && url.includes('/api/inventory') && opts?.method === 'POST') {
					return Promise.resolve({
						ok: true,
						json: () => Promise.resolve({ card_id: 'foil-only', quantity: 1, finish: 'foil' })
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

			// Fill in price
			const priceInput = screen.getByLabelText(/price/i);
			await fireEvent.input(priceInput, { target: { value: '10.00' } });

			// Submit
			const addButton = screen.getByRole('button', { name: /add to inventory/i });
			await fireEvent.click(addButton);

			// Verify correct finish was submitted
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
	});

	// ---------------------------------------------------------------------------
	// Accessibility Tests: Keyboard navigation with filtered options
	// ---------------------------------------------------------------------------
	describe('Keyboard accessibility with filtered options', () => {
		it('should allow keyboard navigation through available finish options only', async () => {
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
				const radios = screen.getAllByRole('radio');
				expect(radios.length).toBe(2);
			});

			// Should only have nonfoil and foil (no etched)
			const radios = screen.getAllByRole('radio');
			expect(radios.length).toBe(2);
			expect((radios[0] as HTMLInputElement).value).toBe('nonfoil');
			expect((radios[1] as HTMLInputElement).value).toBe('foil');

			// Both should be keyboard accessible
			expect(radios[0]).toHaveAttribute('type', 'radio');
			expect(radios[1]).toHaveAttribute('type', 'radio');
		});
	});
});
