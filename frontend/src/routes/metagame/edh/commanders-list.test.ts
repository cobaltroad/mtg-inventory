import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, cleanup, waitFor, fireEvent } from '@testing-library/svelte';

// Mock $app/paths
vi.mock('$app/paths', () => ({
	base: ''
}));

// Mock $app/navigation with a factory function
vi.mock('$app/navigation', () => ({
	goto: vi.fn()
}));

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

// Import AFTER mocks are registered
import CommandersPage from './+page.svelte';
import { goto } from '$app/navigation';

describe('Commanders List Page', () => {
	const mockCommanders = [
		{
			id: 1,
			name: "Atraxa, Praetors' Voice",
			rank: 1,
			edhrec_url: 'https://edhrec.com/commanders/atraxa-praetors-voice',
			last_scraped_at: '2026-02-05T10:00:00Z',
			card_count: 100
		},
		{
			id: 2,
			name: 'Muldrotha, the Gravetide',
			rank: 2,
			edhrec_url: 'https://edhrec.com/commanders/muldrotha-the-gravetide',
			last_scraped_at: '2026-02-05T10:00:00Z',
			card_count: 99
		}
	];

	beforeEach(() => {
		cleanup();
		vi.clearAllMocks();
	});

	describe('successful data loading', () => {
		beforeEach(() => {
			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => mockCommanders
			});
		});

		it('renders all commanders in rank order', async () => {
			render(CommandersPage);

			await waitFor(() => {
				expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			});

			expect(screen.getByText('Muldrotha, the Gravetide')).toBeInTheDocument();
		});

		it('displays commander rank badges', async () => {
			render(CommandersPage);

			await waitFor(() => {
				expect(screen.getByText('#1')).toBeInTheDocument();
			});

			expect(screen.getByText('#2')).toBeInTheDocument();
		});

		it('displays card count for each commander', async () => {
			render(CommandersPage);

			await waitFor(() => {
				expect(screen.getByText('100')).toBeInTheDocument();
			});

			expect(screen.getByText('99')).toBeInTheDocument();
			// Check that "cards" text appears
			const cardsElements = screen.getAllByText('cards');
			expect(cardsElements.length).toBeGreaterThanOrEqual(2);
		});

		it('displays last updated timestamp', async () => {
			render(CommandersPage);

			await waitFor(() => {
				// Should show relative time like "2 days ago"
				const timestamps = screen.getAllByText(/ago/i);
				expect(timestamps.length).toBeGreaterThan(0);
			});
		});

		it('navigates to commander detail page when clicking a commander card', async () => {
			render(CommandersPage);

			await waitFor(() => {
				expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			});

			const commanderButton = screen.getByText("Atraxa, Praetors' Voice").closest('button');
			expect(commanderButton).toBeInTheDocument();

			await fireEvent.click(commanderButton!);

			expect(goto).toHaveBeenCalledWith('/metagame/edh/1');
		});
	});

	describe('empty state', () => {
		beforeEach(() => {
			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => []
			});
		});

		it('displays empty state when no commanders exist', async () => {
			render(CommandersPage);

			await waitFor(() => {
				expect(screen.getByText(/No commanders available yet/i)).toBeInTheDocument();
			});

			expect(screen.getByText(/Check back after the next scrape/i)).toBeInTheDocument();
		});

		it('displays information about scraping schedule in empty state', async () => {
			render(CommandersPage);

			await waitFor(() => {
				expect(screen.getByText(/weekly/i)).toBeInTheDocument();
			});
		});
	});

	describe('error handling', () => {
		beforeEach(() => {
			mockFetch.mockResolvedValue({
				ok: false,
				status: 500
			});
		});

		it('displays error message when API request fails', async () => {
			render(CommandersPage);

			await waitFor(() => {
				expect(screen.getByText(/Failed to load commanders/i)).toBeInTheDocument();
			});
		});

		it('provides retry option when error occurs', async () => {
			render(CommandersPage);

			await waitFor(() => {
				expect(screen.getByText(/retry/i)).toBeInTheDocument();
			});

			const retryButton = screen.getByRole('button', { name: /retry/i });
			expect(retryButton).toBeInTheDocument();

			// Reset mock to return success
			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => mockCommanders
			});

			await fireEvent.click(retryButton);

			await waitFor(() => {
				expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
			});
		});

		it('logs error to console for debugging', async () => {
			const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

			render(CommandersPage);

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

			render(CommandersPage);

			// Should show loading state
			expect(screen.getByText(/loading/i)).toBeInTheDocument();

			// Resolve the promise
			resolvePromise!({
				ok: true,
				json: async () => mockCommanders
			});

			// Wait for loading to complete
			await waitFor(() => {
				expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
			});
		});
	});
});
