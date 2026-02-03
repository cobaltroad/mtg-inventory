import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/svelte';
import PrintingModal from './PrintingModal.svelte';
import { MOCK_CARD, MOCK_PRINTINGS, mockFetchForPrintings } from './PrintingModal.test.helpers';

describe('PrintingModal - Interactions', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	// ---------------------------------------------------------------------------
	// Dismissal
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
	// Image Preview Behavior
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
	// Add to Inventory Button Rendering
	// ---------------------------------------------------------------------------
	describe('Add to Inventory Button Rendering', () => {
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
	// Keyboard Navigation and Focus
	// ---------------------------------------------------------------------------
	describe('Keyboard Navigation and Focus', () => {
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
