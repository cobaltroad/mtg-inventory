import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { tick } from 'svelte';
import PrintingModal from './PrintingModal.svelte';
import { MOCK_CARD, MOCK_PRINTINGS, mockFetchForPrintings } from './PrintingModal.test.helpers';

describe('PrintingModal - Language Dropdown Functionality', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	describe('Language Dropdown Interactivity', () => {
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

			// Find and click a language option (using abbreviation)
			const japaneseOption = screen.getByText('JA');
			await user.click(japaneseOption);
			await tick();

			// Verify the radio button is checked (value is still full name)
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

			const japaneseOption = screen.getByText('JA');
			await user.click(japaneseOption);
			await tick();

			// The language options should still be visible
			expect(japaneseOption).toBeInTheDocument();
			expect(screen.getByText('DE')).toBeInTheDocument();
			expect(screen.getByText('FR')).toBeInTheDocument();

			// Wait a bit to ensure they don't disappear
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

			// Select Japanese
			await user.click(screen.getByText('JA'));
			await tick();
			let japaneseRadio = screen.getByDisplayValue('Japanese') as HTMLInputElement;
			expect(japaneseRadio.checked).toBe(true);

			// Select German
			await user.click(screen.getByText('DE'));
			await tick();
			const germanRadio = screen.getByDisplayValue('German') as HTMLInputElement;
			expect(germanRadio.checked).toBe(true);
			japaneseRadio = screen.getByDisplayValue('Japanese') as HTMLInputElement;
			expect(japaneseRadio.checked).toBe(false);

			// Select French
			await user.click(screen.getByText('FR'));
			await tick();
			const frenchRadio = screen.getByDisplayValue('French') as HTMLInputElement;
			expect(frenchRadio.checked).toBe(true);
			expect(germanRadio.checked).toBe(false);
		});

		it('does not trigger printing item hover handlers when interacting with language options', async () => {
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
				expect(screen.getByText(/^Language$/i)).toBeInTheDocument();
			});

			// Verify first printing is selected
			const previewArea = document.querySelector('.image-preview-area');
			const img = previewArea?.querySelector('img');
			expect(img).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);

			// Click on a language option
			await fireEvent.click(screen.getByText('JA'));
			await tick();

			// The selected printing should not change
			const imgAfterClick = previewArea?.querySelector('img');
			expect(imgAfterClick).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);
		});

		it('allows multiple interactions with the language options without interference', async () => {
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

			// First selection
			await user.click(screen.getByText('JA'));
			await tick();
			expect((screen.getByDisplayValue('Japanese') as HTMLInputElement).checked).toBe(true);

			// Second selection
			await user.click(screen.getByText('DE'));
			await tick();
			expect((screen.getByDisplayValue('German') as HTMLInputElement).checked).toBe(true);
			expect((screen.getByDisplayValue('Japanese') as HTMLInputElement).checked).toBe(false);

			// Third selection
			await user.click(screen.getByText('FR'));
			await tick();
			expect((screen.getByDisplayValue('French') as HTMLInputElement).checked).toBe(true);
			expect((screen.getByDisplayValue('German') as HTMLInputElement).checked).toBe(false);
		});

		it('language options are fully functional after expanding optional fields', async () => {
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
				expect(screen.getByRole('button', { name: /additional details/i })).toBeInTheDocument();
			});

			// Collapse optional fields
			const toggleButton = screen.getByRole('button', { name: /additional details/i });
			await fireEvent.click(toggleButton);
			await tick();

			// Re-expand optional fields
			await fireEvent.click(toggleButton);
			await tick();

			// Now try to select a language
			await user.click(screen.getByText('KO'));
			await tick();

			expect((screen.getByDisplayValue('Korean') as HTMLInputElement).checked).toBe(true);
		});

		it('does not lose language selection when option is clicked multiple times', async () => {
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

			// Select Spanish
			const spanishOption = screen.getByText('ES');
			await user.click(spanishOption);
			await tick();
			expect((screen.getByDisplayValue('Spanish') as HTMLInputElement).checked).toBe(true);

			// Click on the same option again
			await user.click(spanishOption);
			await tick();

			// Value should persist
			expect((screen.getByDisplayValue('Spanish') as HTMLInputElement).checked).toBe(true);

			// Click on another element and verify Spanish is still selected
			await fireEvent.click(screen.getByText(/^Language$/i));
			await tick();

			expect((screen.getByDisplayValue('Spanish') as HTMLInputElement).checked).toBe(true);
		});
	});
});
