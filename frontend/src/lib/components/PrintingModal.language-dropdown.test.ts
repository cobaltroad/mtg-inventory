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
		it('allows user to click and open the language dropdown', async () => {
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
				expect(screen.getByText(/language/i)).toBeInTheDocument();
			});

			// Find the Combobox input
			const comboboxInput = screen.getByPlaceholderText(/select language/i) as HTMLInputElement;

			// Click on the combobox to interact with it
			await user.click(comboboxInput);
			await tick();

			// The combobox input should still be in the document
			expect(comboboxInput).toBeInTheDocument();
		});

		it('does not close or disappear when user interacts with the language dropdown', async () => {
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
				expect(screen.getByText(/language/i)).toBeInTheDocument();
			});

			const comboboxInput = screen.getByPlaceholderText(/select language/i) as HTMLInputElement;

			// Click on the combobox to interact with it
			await user.click(comboboxInput);
			await tick();

			// The combobox should still be visible and accessible
			expect(comboboxInput).toBeInTheDocument();

			// Wait a bit to ensure it doesn't disappear
			await new Promise((resolve) => setTimeout(resolve, 100));

			expect(comboboxInput).toBeInTheDocument();

			// Clear and type to filter and select a value
			await user.clear(comboboxInput);
			await user.type(comboboxInput, 'Japanese');
			await tick();

			expect(comboboxInput).toHaveValue('Japanese');
		});

		it('allows user to select a language option using userEvent', async () => {
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
				expect(screen.getByText(/language/i)).toBeInTheDocument();
			});

			const comboboxInput = screen.getByPlaceholderText(/select language/i) as HTMLInputElement;

			// Click to open the combobox
			await user.click(comboboxInput);
			await tick();

			// Type to filter and select Japanese
			await user.clear(comboboxInput);
			await user.type(comboboxInput, 'Japanese');
			await tick();

			// Verify the value changed
			expect(comboboxInput).toHaveValue('Japanese');
		});

		it('does not trigger printing item hover handlers when interacting with language dropdown', async () => {
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
				expect(screen.getByText(/language/i)).toBeInTheDocument();
			});

			// Verify first printing is selected
			const previewArea = document.querySelector('.image-preview-area');
			const img = previewArea?.querySelector('img');
			expect(img).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);

			const comboboxInput = screen.getByPlaceholderText(/select language/i) as HTMLInputElement;

			// Click on the combobox
			await fireEvent.click(comboboxInput);
			await tick();

			// The selected printing should not change
			const imgAfterClick = previewArea?.querySelector('img');
			expect(imgAfterClick).toHaveAttribute('src', MOCK_PRINTINGS[0].image_url);
		});

		it('allows multiple interactions with the language dropdown without interference', async () => {
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
				expect(screen.getByText(/language/i)).toBeInTheDocument();
			});

			const comboboxInput = screen.getByPlaceholderText(/select language/i) as HTMLInputElement;

			// First selection
			await user.clear(comboboxInput);
			await user.type(comboboxInput, 'Japanese');
			await tick();
			expect(comboboxInput).toHaveValue('Japanese');

			// Second selection
			await user.clear(comboboxInput);
			await user.type(comboboxInput, 'German');
			await tick();
			expect(comboboxInput).toHaveValue('German');

			// Third selection
			await user.clear(comboboxInput);
			await user.type(comboboxInput, 'French');
			await tick();
			expect(comboboxInput).toHaveValue('French');
		});

		it('language dropdown is fully functional after expanding optional fields', async () => {
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

			// Now try to use the language dropdown
			const comboboxInput = screen.getByPlaceholderText(/select language/i) as HTMLInputElement;
			await user.clear(comboboxInput);
			await user.type(comboboxInput, 'Korean');
			await tick();

			expect(comboboxInput).toHaveValue('Korean');
		});

		it('does not lose language selection when dropdown is clicked multiple times', async () => {
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
				expect(screen.getByText(/language/i)).toBeInTheDocument();
			});

			const comboboxInput = screen.getByPlaceholderText(/select language/i) as HTMLInputElement;

			// Select a language
			await user.clear(comboboxInput);
			await user.type(comboboxInput, 'Spanish');
			await tick();
			expect(comboboxInput).toHaveValue('Spanish');

			// Click on the combobox again (simulating user trying to open it again)
			await user.click(comboboxInput);
			await tick();

			// Value should persist
			expect(comboboxInput).toHaveValue('Spanish');

			// Click somewhere else and back
			await fireEvent.blur(comboboxInput);
			await tick();

			expect(comboboxInput).toHaveValue('Spanish');
		});
	});
});
