import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, cleanup, waitFor } from '@testing-library/svelte';

// Mock $app/paths
vi.mock('$app/paths', () => ({
	base: ''
}));

// Mock $app/stores for page data
const mockPageData = {
	subscribe: vi.fn(),
	set: vi.fn(),
	update: vi.fn()
};

vi.mock('$app/stores', () => ({
	page: {
		subscribe: (fn: any) => {
			fn({ params: { id: '1' } });
			return () => {};
		}
	}
}));

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

// Import AFTER mocks are registered
import CommanderDetailPage from './+page.svelte';

describe('Commander Detail Page', () => {
	const mockCommander = {
		id: 1,
		name: "Atraxa, Praetors' Voice",
		rank: 1,
		edhrec_url: 'https://edhrec.com/commanders/atraxa-praetors-voice',
		last_scraped_at: '2026-02-05T10:00:00Z',
		card_count: 3,
		cards: [
			{ card_id: 'abc-123', card_name: 'Sol Ring', quantity: 1 },
			{ card_id: 'def-456', card_name: 'Command Tower', quantity: 1 },
			{ card_id: 'ghi-789', card_name: 'Reliquary Tower', quantity: 1 }
		]
	};

	beforeEach(() => {
		cleanup();
		vi.clearAllMocks();
	});

	describe('successful data loading', () => {
		beforeEach(() => {
			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => mockCommander
			});
		});

		it('displays commander name as page title', async () => {
			render(CommanderDetailPage);

			await waitFor(() => {
				expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			});
		});

		it('displays commander rank', async () => {
			render(CommanderDetailPage);

			await waitFor(() => {
				expect(screen.getByText('#1')).toBeInTheDocument();
			});
		});

		it('displays EDHREC link', async () => {
			render(CommanderDetailPage);

			await waitFor(() => {
				const link = screen.getByRole('link', { name: /edhrec/i });
				expect(link).toHaveAttribute('href', mockCommander.edhrec_url);
			});
		});

		it('displays complete decklist', async () => {
			render(CommanderDetailPage);

			await waitFor(() => {
				expect(screen.getByText('Sol Ring')).toBeInTheDocument();
			});

			expect(screen.getByText('Command Tower')).toBeInTheDocument();
			expect(screen.getByText('Reliquary Tower')).toBeInTheDocument();
		});

		it('displays card quantities when present', async () => {
			const commanderWithQuantities = {
				...mockCommander,
				cards: [
					{ card_id: 'abc-123', card_name: 'Sol Ring', quantity: 2 },
					{ card_id: 'def-456', card_name: 'Command Tower', quantity: 1 }
				]
			};

			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => commanderWithQuantities
			});

			render(CommanderDetailPage);

			await waitFor(() => {
				// Should show "2x Sol Ring" for quantity > 1
				expect(screen.getByText(/2x/i)).toBeInTheDocument();
			});
		});
	});

	describe('error handling', () => {
		it('displays error message when commander is not found', async () => {
			mockFetch.mockResolvedValue({
				ok: false,
				status: 404
			});

			render(CommanderDetailPage);

			await waitFor(() => {
				expect(screen.getByText(/not found/i)).toBeInTheDocument();
			});
		});

		it('displays error message when API request fails', async () => {
			mockFetch.mockResolvedValue({
				ok: false,
				status: 500
			});

			render(CommanderDetailPage);

			await waitFor(() => {
				expect(screen.getByText(/failed/i)).toBeInTheDocument();
			});
		});

		it('logs error to console for debugging', async () => {
			const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

			mockFetch.mockResolvedValue({
				ok: false,
				status: 500
			});

			render(CommanderDetailPage);

			await waitFor(() => {
				expect(consoleSpy).toHaveBeenCalled();
			});

			consoleSpy.mockRestore();
		});
	});

	describe('loading state', () => {
		it('shows loading indicator while fetching data', async () => {
			// Create a promise that we can control
			let resolvePromise: (value: any) => void;
			const promise = new Promise((resolve) => {
				resolvePromise = resolve;
			});

			mockFetch.mockReturnValue(promise as any);

			render(CommanderDetailPage);

			// Should show loading state
			expect(screen.getByText(/loading/i)).toBeInTheDocument();

			// Resolve the promise
			resolvePromise!({
				ok: true,
				json: async () => mockCommander
			});

			// Wait for loading to complete
			await waitFor(() => {
				expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
			});
		});
	});

	describe('empty decklist', () => {
		it('handles commander with no cards gracefully', async () => {
			const commanderWithoutCards = {
				...mockCommander,
				cards: [],
				card_count: 0
			};

			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => commanderWithoutCards
			});

			render(CommanderDetailPage);

			await waitFor(() => {
				expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			});

			// Should show empty state or message
			expect(screen.getByText(/no cards/i)).toBeInTheDocument();
		});
	});
});
