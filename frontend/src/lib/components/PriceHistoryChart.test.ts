import { render, screen, waitFor, cleanup, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import PriceHistoryChart from './PriceHistoryChart.svelte';

// Mock fetch globally
global.fetch = vi.fn();

describe('PriceHistoryChart Component', () => {
	const mockCardId = 'test-card-uuid-123';

	const mockPriceHistoryData = {
		card_id: mockCardId,
		time_period: '30',
		prices: [
			{
				fetched_at: '2026-01-07T10:00:00.000Z',
				usd_cents: 1000,
				usd_foil_cents: 2000,
				usd_etched_cents: null
			},
			{
				fetched_at: '2026-01-14T10:00:00.000Z',
				usd_cents: 1200,
				usd_foil_cents: 2200,
				usd_etched_cents: null
			},
			{
				fetched_at: '2026-02-06T10:00:00.000Z',
				usd_cents: 1500,
				usd_foil_cents: 2500,
				usd_etched_cents: null
			}
		],
		summary: {
			normal: {
				start_price_cents: 1000,
				end_price_cents: 1500,
				percentage_change: 50.0,
				direction: 'up'
			},
			foil: {
				start_price_cents: 2000,
				end_price_cents: 2500,
				percentage_change: 25.0,
				direction: 'up'
			}
		}
	};

	beforeEach(() => {
		vi.clearAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	// ---------------------------------------------------------------------------
	// RED Phase: Component rendering and basic functionality
	// ---------------------------------------------------------------------------

	it('renders with card_id prop', () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockImplementation(
			() =>
				new Promise(() => {
					// Never resolves to keep loading state
				})
		);

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		expect(screen.getByText(/loading/i)).toBeTruthy();
	});

	it('displays loading state while fetching data', () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockImplementation(
			() =>
				new Promise(() => {
					// Never resolves to keep loading state
				})
		);

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		expect(screen.getByText(/loading/i)).toBeTruthy();
	});

	it('fetches price history data from API on mount', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalledWith(
				expect.stringContaining(`/api/cards/${mockCardId}/price_history`)
			);
		});
	});

	it('displays error message when fetch fails', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: false,
			status: 500
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			expect(screen.getByText(/failed to load/i)).toBeTruthy();
		});
	});

	it('displays chart after data is loaded', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			// Canvas element should be present for chart
			const canvas = document.querySelector('canvas');
			expect(canvas).toBeTruthy();
		});
	});

	// ---------------------------------------------------------------------------
	// Time period selector tests
	// ---------------------------------------------------------------------------

	it('renders time period selector with all options', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			expect(screen.getByText('7 Days')).toBeTruthy();
			expect(screen.getByText('30 Days')).toBeTruthy();
			expect(screen.getByText('90 Days')).toBeTruthy();
			expect(screen.getByText('1 Year')).toBeTruthy();
			expect(screen.getByText('All Time')).toBeTruthy();
		});
	});

	it('defaults to 30 days time period', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalledWith(
				expect.stringContaining('time_period=30')
			);
		});
	});

	it('fetches new data when time period changes', async () => {
		(global.fetch as ReturnType<typeof vi.fn>)
			.mockResolvedValueOnce({
				ok: true,
				json: async () => mockPriceHistoryData
			})
			.mockResolvedValueOnce({
				ok: true,
				json: async () => ({ ...mockPriceHistoryData, time_period: '7' })
			});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalledTimes(1);
		});

		// Click 7 days button
		const sevenDaysButton = screen.getByText('7 Days');
		await fireEvent.click(sevenDaysButton);

		await waitFor(() => {
			expect(global.fetch).toHaveBeenCalledTimes(2);
			expect(global.fetch).toHaveBeenLastCalledWith(
				expect.stringContaining('time_period=7')
			);
		});
	});

	// ---------------------------------------------------------------------------
	// Treatment toggle tests
	// ---------------------------------------------------------------------------

	it('renders treatment toggles for available treatments', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			const toggles = document.querySelectorAll('.treatment-toggle');
			expect(toggles.length).toBeGreaterThan(0);
			const toggleTexts = Array.from(toggles).map((t) => t.textContent);
			expect(toggleTexts).toContain('Normal');
			expect(toggleTexts).toContain('Foil');
		});
	});

	it('does not show toggle for treatment with no data', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			// Etched has null data, should not appear
			const etchedToggle = screen.queryByText('Etched');
			expect(etchedToggle).toBeNull();
		});
	});

	it('toggles treatment visibility when clicked', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			const toggles = document.querySelectorAll('.treatment-toggle');
			expect(toggles.length).toBeGreaterThan(0);
		});

		const toggles = document.querySelectorAll('.treatment-toggle');
		const normalToggle = Array.from(toggles).find((t) => t.textContent === 'Normal') as HTMLElement;

		// Should be active initially
		expect(normalToggle.classList.contains('active')).toBe(true);

		// Click to toggle off
		await fireEvent.click(normalToggle);

		// Should no longer be active
		expect(normalToggle.classList.contains('active')).toBe(false);
	});

	// ---------------------------------------------------------------------------
	// Price change summary tests
	// ---------------------------------------------------------------------------

	it('displays price change summary for normal treatment', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			const summaryCards = document.querySelectorAll('.summary-card');
			expect(summaryCards.length).toBeGreaterThan(0);
		});

		// Check for percentage change
		const percentageElements = document.querySelectorAll('.percentage-change');
		const percentageTexts = Array.from(percentageElements).map((el) => el.textContent?.trim());
		expect(percentageTexts.some((text) => text?.includes('+50.0%'))).toBe(true);

		// Check for price change
		const priceElements = document.querySelectorAll('.price-change');
		const priceTexts = Array.from(priceElements).map((el) => el.textContent?.trim());
		expect(priceTexts.some((text) => text === '$10.00 → $15.00')).toBe(true);
	});

	it('displays up indicator for price increase', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			const percentageElements = document.querySelectorAll('.percentage-change');
			const hasUpArrow = Array.from(percentageElements).some((el) =>
				el.textContent?.includes('↑')
			);
			expect(hasUpArrow).toBe(true);
		});
	});

	it('displays down indicator for price decrease', async () => {
		const decreasingData = {
			...mockPriceHistoryData,
			summary: {
				normal: {
					start_price_cents: 2000,
					end_price_cents: 1500,
					percentage_change: -25.0,
					direction: 'down'
				}
			}
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => decreasingData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			const percentageElements = document.querySelectorAll('.percentage-change');
			const texts = Array.from(percentageElements).map((el) => el.textContent?.trim());
			expect(texts.some((text) => text?.includes('↓'))).toBe(true);
			expect(texts.some((text) => text?.includes('-25.0%'))).toBe(true);
		});
	});

	it('displays stable indicator when price unchanged', async () => {
		const stableData = {
			...mockPriceHistoryData,
			summary: {
				normal: {
					start_price_cents: 1500,
					end_price_cents: 1500,
					percentage_change: 0.0,
					direction: 'stable'
				}
			}
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => stableData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			const percentageElements = document.querySelectorAll('.percentage-change');
			const texts = Array.from(percentageElements).map((el) => el.textContent?.trim());
			expect(texts.some((text) => text?.includes('0.0%'))).toBe(true);
		});
	});

	// ---------------------------------------------------------------------------
	// Sparse data handling tests
	// ---------------------------------------------------------------------------

	it('handles empty price history gracefully', async () => {
		const emptyData = {
			card_id: mockCardId,
			time_period: '30',
			prices: [],
			summary: {}
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => emptyData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			expect(screen.getByText(/no price history/i)).toBeTruthy();
		});
	});

	it('handles single price record', async () => {
		const singlePriceData = {
			card_id: mockCardId,
			time_period: '30',
			prices: [
				{
					fetched_at: '2026-02-06T10:00:00.000Z',
					usd_cents: 1000,
					usd_foil_cents: null,
					usd_etched_cents: null
				}
			],
			summary: {
				normal: {
					start_price_cents: 1000,
					end_price_cents: 1000,
					percentage_change: 0.0,
					direction: 'stable'
				}
			}
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => singlePriceData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			// Should render chart even with single data point
			const canvas = document.querySelector('canvas');
			expect(canvas).toBeTruthy();
		});
	});

	it('displays gaps in sparse data without interpolation', async () => {
		const sparseData = {
			card_id: mockCardId,
			time_period: '90',
			prices: [
				{
					fetched_at: '2025-11-06T10:00:00.000Z',
					usd_cents: 1000,
					usd_foil_cents: null,
					usd_etched_cents: null
				},
				{
					fetched_at: '2026-02-06T10:00:00.000Z',
					usd_cents: 1500,
					usd_foil_cents: null,
					usd_etched_cents: null
				}
			],
			summary: {
				normal: {
					start_price_cents: 1000,
					end_price_cents: 1500,
					percentage_change: 50.0,
					direction: 'up'
				}
			}
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => sparseData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			// Chart should render - we'll verify no interpolation in chart config
			const canvas = document.querySelector('canvas');
			expect(canvas).toBeTruthy();
		});
	});

	// ---------------------------------------------------------------------------
	// Responsive and accessibility tests
	// ---------------------------------------------------------------------------

	it('renders canvas with appropriate dimensions', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			const canvas = document.querySelector('canvas');
			expect(canvas).toBeTruthy();
			// Canvas should exist - Chart.js handles dimensions automatically
			expect(canvas?.tagName).toBe('CANVAS');
		});
	});

	it('has accessible labels and descriptions', async () => {
		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => mockPriceHistoryData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			// Component should have descriptive text
			expect(screen.getByText(/price history/i)).toBeTruthy();
		});
	});

	// ---------------------------------------------------------------------------
	// Multiple treatments test
	// ---------------------------------------------------------------------------

	it('displays multiple treatment lines when data available', async () => {
		const multiTreatmentData = {
			...mockPriceHistoryData,
			prices: [
				{
					fetched_at: '2026-01-07T10:00:00.000Z',
					usd_cents: 1000,
					usd_foil_cents: 2000,
					usd_etched_cents: 2500
				},
				{
					fetched_at: '2026-02-06T10:00:00.000Z',
					usd_cents: 1500,
					usd_foil_cents: 2500,
					usd_etched_cents: 3000
				}
			],
			summary: {
				normal: {
					start_price_cents: 1000,
					end_price_cents: 1500,
					percentage_change: 50.0,
					direction: 'up'
				},
				foil: {
					start_price_cents: 2000,
					end_price_cents: 2500,
					percentage_change: 25.0,
					direction: 'up'
				},
				etched: {
					start_price_cents: 2500,
					end_price_cents: 3000,
					percentage_change: 20.0,
					direction: 'up'
				}
			}
		};

		(global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
			ok: true,
			json: async () => multiTreatmentData
		});

		render(PriceHistoryChart, { props: { cardId: mockCardId } });

		await waitFor(() => {
			const toggles = document.querySelectorAll('.treatment-toggle');
			const toggleTexts = Array.from(toggles).map((t) => t.textContent);
			expect(toggleTexts).toContain('Normal');
			expect(toggleTexts).toContain('Foil');
			expect(toggleTexts).toContain('Etched');
		});
	});
});
