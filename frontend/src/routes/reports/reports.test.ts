import { render, screen, waitFor, cleanup } from '@testing-library/svelte';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import ReportsPage from './+page.svelte';

// Mock fetch globally
global.fetch = vi.fn();

describe('Reports Page', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	it('displays loading state initially', () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockImplementation(
			() =>
				new Promise(() => {
					// Never resolves to keep loading state
				})
		);

		render(ReportsPage);

		expect(screen.getByText('Calculating inventory value...')).toBeTruthy();
	});

	it('displays total inventory value when data is loaded', async () => {
		const mockData = {
			total_value_cents: 150000,
			total_cards: 100,
			valued_cards: 95,
			excluded_cards: 5,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('$1,500.00')).toBeTruthy();
		});
	});

	it('formats currency correctly with thousand separators', async () => {
		const mockData = {
			total_value_cents: 1234567,
			total_cards: 1000,
			valued_cards: 950,
			excluded_cards: 50,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('$12,345.67')).toBeTruthy();
		});
	});

	it('displays breakdown of total cards', async () => {
		const mockData = {
			total_value_cents: 100000,
			total_cards: 250,
			valued_cards: 240,
			excluded_cards: 10,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('250')).toBeTruthy();
		});
	});

	it('displays breakdown of valued cards', async () => {
		const mockData = {
			total_value_cents: 100000,
			total_cards: 250,
			valued_cards: 240,
			excluded_cards: 10,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('240')).toBeTruthy();
		});
	});

	it('displays breakdown of cards without prices', async () => {
		const mockData = {
			total_value_cents: 100000,
			total_cards: 250,
			valued_cards: 240,
			excluded_cards: 10,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		const { container } = render(ReportsPage);

		await waitFor(() => {
			// Find the "Without Prices" section in the specific container
			const withouPricesTitle = container.querySelector('.breakdown-title');
			expect(withouPricesTitle).toBeTruthy();
			expect(container.textContent).toContain('10');
		});
	});

	it('displays last updated timestamp', async () => {
		const mockData = {
			total_value_cents: 100000,
			total_cards: 100,
			valued_cards: 95,
			excluded_cards: 5,
			last_updated: '2026-02-06T14:30:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		const { container } = render(ReportsPage);

		await waitFor(() => {
			expect(container.textContent).toContain('Last updated:');
		});
	});

	it('displays "Never" when no last updated timestamp', async () => {
		const mockData = {
			total_value_cents: 0,
			total_cards: 10,
			valued_cards: 0,
			excluded_cards: 10,
			last_updated: null
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText(/Never/)).toBeTruthy();
		});
	});

	it('displays zero value for empty inventory', async () => {
		const mockData = {
			total_value_cents: 0,
			total_cards: 0,
			valued_cards: 0,
			excluded_cards: 0,
			last_updated: null
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('$0.00')).toBeTruthy();
		});
	});

	it('displays error message when API call fails', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error('Network error'));

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('Failed to load inventory value. Please try again.')).toBeTruthy();
		});
	});

	it('displays error message when API returns non-ok response', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: false,
			status: 500
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('Failed to load inventory value. Please try again.')).toBeTruthy();
		});
	});

	it('displays retry button when error occurs', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockRejectedValueOnce(new Error('Network error'));

		const { container } = render(ReportsPage);

		await waitFor(() => {
			expect(container.textContent).toContain('Retry');
		});
	});

	it('uses correct API endpoint with base path', async () => {
		const mockData = {
			total_value_cents: 100000,
			total_cards: 100,
			valued_cards: 95,
			excluded_cards: 5,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalledWith('/api/inventory/value');
		});
	});

	it('formats large numbers with thousand separators', async () => {
		const mockData = {
			total_value_cents: 100000,
			total_cards: 5000,
			valued_cards: 4800,
			excluded_cards: 200,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('5,000')).toBeTruthy();
			expect(screen.getByText('4,800')).toBeTruthy();
		});
	});

	it('handles cent values correctly', async () => {
		const mockData = {
			total_value_cents: 12345,
			total_cards: 10,
			valued_cards: 10,
			excluded_cards: 0,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('$123.45')).toBeTruthy();
		});
	});
});
