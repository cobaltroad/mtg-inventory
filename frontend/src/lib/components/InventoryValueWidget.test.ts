import { describe, it, expect, afterEach, vi, beforeEach } from 'vitest';
import { render, screen, cleanup, waitFor } from '@testing-library/svelte';
import { tick } from 'svelte';
import InventoryValueWidget from './InventoryValueWidget.svelte';

// Mock LayerCake to avoid rendering issues in test environment
vi.mock('layercake', () => ({
	LayerCake: vi.fn(() => ({
		$$: {}
	})),
	Svg: vi.fn(() => ({
		$$: {}
	}))
}));

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

beforeEach(() => {
	vi.clearAllMocks();
});

afterEach(() => {
	cleanup();
});

// ---------------------------------------------------------------------------
// Test Fixtures
// ---------------------------------------------------------------------------

const validTimelineResponse = {
	time_period: '30',
	timeline: [
		{ date: '2026-01-01T00:00:00Z', value_cents: 10000 },
		{ date: '2026-01-15T00:00:00Z', value_cents: 12000 },
		{ date: '2026-02-01T00:00:00Z', value_cents: 15000 }
	],
	summary: {
		start_value_cents: 10000,
		end_value_cents: 15000,
		change_cents: 5000,
		change_percentage: 50.0
	}
};

const emptyTimelineResponse = {
	time_period: '30',
	timeline: [],
	summary: {
		start_value_cents: 0,
		end_value_cents: 0,
		change_cents: 0,
		change_percentage: 0.0
	}
};

const zeroValueResponse = {
	time_period: '30',
	timeline: [
		{ date: '2026-01-01T00:00:00Z', value_cents: 0 },
		{ date: '2026-02-01T00:00:00Z', value_cents: 0 }
	],
	summary: {
		start_value_cents: 0,
		end_value_cents: 0,
		change_cents: 0,
		change_percentage: 0.0
	}
};

// ---------------------------------------------------------------------------
// Tests: Loading States
// ---------------------------------------------------------------------------
describe('InventoryValueWidget - Loading States', () => {
	it('displays loading state initially', async () => {
		mockFetch.mockImplementation(() => new Promise(() => {})); // Never resolves

		const { container } = render(InventoryValueWidget);

		await waitFor(() => {
			expect(container.querySelector('.placeholder')).toBeInTheDocument();
		});
	});

	it('displays loading skeleton when data is being fetched', async () => {
		mockFetch.mockImplementation(() => new Promise(() => {})); // Never resolves

		const { container } = render(InventoryValueWidget);

		await waitFor(() => {
			expect(container.querySelector('.placeholder')).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Empty Data Handling
// ---------------------------------------------------------------------------
describe('InventoryValueWidget - Empty Data', () => {
	it('displays empty state message when timeline is empty', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => emptyTimelineResponse
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/no value timeline data available/i)).toBeInTheDocument();
		});
	});

	it('displays widget when inventory value is zero', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => zeroValueResponse
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/inventory value over time/i)).toBeInTheDocument();
		});
	});

	it('displays $0.00 when end_value_cents is zero', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => zeroValueResponse
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText('$0.00')).toBeInTheDocument();
		});
	});

	it('handles missing timeline property gracefully', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => ({
				time_period: '30',
				summary: {
					start_value_cents: 0,
					end_value_cents: 0,
					change_cents: 0,
					change_percentage: 0.0
				}
			})
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/no value timeline data available/i)).toBeInTheDocument();
		});
	});

	it('handles missing summary property gracefully', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => ({
				time_period: '30',
				timeline: []
			})
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			// Should show empty state or error, not crash
			const widget = screen.queryByText(/inventory value over time/i);
			expect(widget).toBeTruthy();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Malformed Data Handling
// ---------------------------------------------------------------------------
describe('InventoryValueWidget - Malformed Data', () => {
	it('handles null response gracefully', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => null
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/invalid response format/i)).toBeInTheDocument();
		});
	});

	it('handles malformed timeline data points', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => ({
				time_period: '30',
				timeline: [
					{ date: null, value_cents: 100 }, // Missing date
					{ date: '2026-01-01T00:00:00Z' }, // Missing value_cents
					{} // Empty object
				],
				summary: {
					start_value_cents: 0,
					end_value_cents: 100,
					change_cents: 100,
					change_percentage: 0.0
				}
			})
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			// Should not crash, should handle gracefully
			const widget = screen.queryByText(/inventory value over time/i);
			expect(widget).toBeTruthy();
		});
	});

	it('handles missing change_percentage in summary', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => ({
				time_period: '30',
				timeline: [{ date: '2026-01-01T00:00:00Z', value_cents: 10000 }],
				summary: {
					start_value_cents: 10000,
					end_value_cents: 10000,
					change_cents: 0
					// Missing change_percentage
				}
			})
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			// Should not crash when trying to access change_percentage
			const widget = screen.queryByText(/inventory value over time/i);
			expect(widget).toBeTruthy();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Error Handling
// ---------------------------------------------------------------------------
describe('InventoryValueWidget - Error Handling', () => {
	it('displays error message when fetch fails', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: false,
			status: 500
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/failed to load inventory value timeline/i)).toBeInTheDocument();
		});
	});

	it('displays retry button on error', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: false,
			status: 500
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/retry/i)).toBeInTheDocument();
		});
	});

	it('retries fetch when retry button is clicked', async () => {
		mockFetch
			.mockResolvedValueOnce({
				ok: false,
				status: 500
			})
			.mockResolvedValueOnce({
				ok: true,
				json: async () => validTimelineResponse
			});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/retry/i)).toBeInTheDocument();
		});

		const retryButton = screen.getByText(/retry/i);
		await retryButton.click();

		await waitFor(() => {
			expect(screen.getByText(/inventory value over time/i)).toBeInTheDocument();
		});
	});

	it('handles network errors gracefully', async () => {
		mockFetch.mockRejectedValueOnce(new Error('Network error'));

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText('Network error')).toBeInTheDocument();
		});
	});

	it('error state does not prevent component from rendering', async () => {
		mockFetch.mockRejectedValueOnce(new Error('Network error'));

		const { container } = render(InventoryValueWidget);

		await waitFor(() => {
			// Component should still render, just showing error state
			expect(container.querySelector('.alert')).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Successful Data Display
// ---------------------------------------------------------------------------
describe('InventoryValueWidget - Data Display', () => {
	it('displays widget title when data is loaded', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => validTimelineResponse
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/inventory value over time/i)).toBeInTheDocument();
		});
	});

	it('displays current value from summary', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => validTimelineResponse
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText('$150.00')).toBeInTheDocument();
		});
	});

	it('displays value change with correct sign', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => validTimelineResponse
		});

		const { container } = render(InventoryValueWidget);

		await waitFor(() => {
			// Check for the change text which includes both dollar amount and percentage
			const changeText = container.textContent;
			expect(changeText).toContain('$50.00');
			expect(changeText).toContain('+50.00%');
		});
	});

	it('displays percentage change', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => validTimelineResponse
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText(/\+50\.00%/)).toBeInTheDocument();
		});
	});

	it('displays negative change with correct styling', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => ({
				...validTimelineResponse,
				summary: {
					start_value_cents: 15000,
					end_value_cents: 10000,
					change_cents: -5000,
					change_percentage: -33.33
				}
			})
		});

		const { container } = render(InventoryValueWidget);

		await waitFor(() => {
			// Check for negative change text
			const changeText = container.textContent;
			expect(changeText).toContain('$-50.00');
			expect(changeText).toContain('-33.33%');
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Time Period Selection
// ---------------------------------------------------------------------------
describe('InventoryValueWidget - Time Period', () => {
	it('displays time period selector buttons', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => validTimelineResponse
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText('7 Days')).toBeInTheDocument();
			expect(screen.getByText('30 Days')).toBeInTheDocument();
			expect(screen.getByText('90 Days')).toBeInTheDocument();
		});
	});

	it('fetches new data when time period changes', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => validTimelineResponse
		});

		render(InventoryValueWidget);

		await waitFor(() => {
			expect(screen.getByText('30 Days')).toBeInTheDocument();
		});

		const sevenDayButton = screen.getByText('7 Days');
		await sevenDayButton.click();

		// Should trigger a new fetch
		expect(mockFetch).toHaveBeenCalledTimes(2);
	});
});

// ---------------------------------------------------------------------------
// Tests: Chart Rendering
// ---------------------------------------------------------------------------
describe('InventoryValueWidget - Chart', () => {
	it('renders chart container when data is available', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => validTimelineResponse
		});

		const { container } = render(InventoryValueWidget);

		await waitFor(() => {
			expect(container.querySelector('.chart-container')).toBeInTheDocument();
		});
	});

	it('does not render chart when timeline is empty', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => emptyTimelineResponse
		});

		const { container } = render(InventoryValueWidget);

		await waitFor(() => {
			expect(container.querySelector('.chart-container')).not.toBeInTheDocument();
		});
	});

	it('does not crash when rendering chart with valid data', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => validTimelineResponse
		});

		const { container } = render(InventoryValueWidget);

		await waitFor(() => {
			// Should render without errors
			expect(container.querySelector('.chart-container')).toBeInTheDocument();
		});
	});
});
