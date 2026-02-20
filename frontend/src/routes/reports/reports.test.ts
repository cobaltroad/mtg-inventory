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

		expect(screen.getByText('Loading inventory statistics...')).toBeTruthy();
	});

	it('displays total inventory value when data is loaded', async () => {
		const mockData = {
			total_value_cents: 150000,
			cards_over_ten_dollars: 95,
			total_sets: 25,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('$1500.00')).toBeTruthy();
		});
	});

	it('formats currency correctly', async () => {
		const mockData = {
			total_value_cents: 1234567,
			cards_over_ten_dollars: 950,
			total_sets: 50,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('$12345.67')).toBeTruthy();
		});
	});

	it('displays cards over $10 count', async () => {
		const mockData = {
			total_value_cents: 100000,
			cards_over_ten_dollars: 240,
			total_sets: 30,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('240')).toBeTruthy();
			expect(screen.getByText('Cards Over $10')).toBeTruthy();
		});
	});

	it('displays total sets count', async () => {
		const mockData = {
			total_value_cents: 100000,
			cards_over_ten_dollars: 240,
			total_sets: 30,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('30')).toBeTruthy();
			expect(screen.getByText('Different Sets')).toBeTruthy();
		});
	});

	it('displays total sets count', async () => {
		const mockData = {
			total_value_cents: 100000,
			cards_over_ten_dollars: 240,
			total_sets: 30,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText('30')).toBeTruthy();
			expect(screen.getByText('Different Sets')).toBeTruthy();
		});
	});

	it('displays zero value for empty inventory', async () => {
		const mockData = {
			total_value_cents: 0,
			cards_over_ten_dollars: 0,
			total_sets: 0,
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
			expect(screen.getByText(/Failed to load inventory statistics/)).toBeTruthy();
		});
	});

	it('displays error message when API returns non-ok response', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: false,
			status: 500
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(screen.getByText(/Failed to load inventory statistics/)).toBeTruthy();
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
			cards_over_ten_dollars: 95,
			total_sets: 25,
			last_updated: '2026-02-06T10:00:00Z'
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockData
		});

		render(ReportsPage);

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalledWith('/api/reports/inventory_stats?uu');
		});
	});

	it('handles cent values correctly', async () => {
		const mockData = {
			total_value_cents: 12345,
			cards_over_ten_dollars: 10,
			total_sets: 5,
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
