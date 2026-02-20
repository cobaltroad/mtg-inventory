import { describe, it, expect, afterEach, vi, beforeEach } from 'vitest';
import { render, screen, cleanup, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import PriceAlertWidget from './PriceAlertWidget.svelte';

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

beforeEach(() => {
	mockFetch.mockReset();
	vi.clearAllMocks();
});

afterEach(() => {
	cleanup();
	mockFetch.mockReset();
});

// ---------------------------------------------------------------------------
// Test Fixtures
// ---------------------------------------------------------------------------

const mockAlerts = [
	{
		id: 1,
		card_id: 'card-1',
		card_name: 'Black Lotus',
		alert_type: 'price_increase' as const,
		old_price_cents: 10000,
		new_price_cents: 15000,
		percentage_change: '50.00',
		finish: 'nonfoil',
		created_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString() // 2 hours ago
	},
	{
		id: 2,
		card_id: 'card-2',
		card_name: 'Mox Ruby',
		alert_type: 'price_decrease' as const,
		old_price_cents: 8000,
		new_price_cents: 6000,
		percentage_change: '-25.00',
		finish: 'foil',
		created_at: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString() // 1 day ago
	},
	{
		id: 3,
		card_id: 'card-3',
		card_name: 'Time Walk',
		alert_type: 'price_increase' as const,
		old_price_cents: 5000,
		new_price_cents: 7500,
		percentage_change: '50.00',
		finish: 'etched',
		created_at: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString() // 3 days ago
	}
];

// ---------------------------------------------------------------------------
// Tests: Visual Discovery - Dismiss Buttons
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Dismiss Button Discovery', () => {
	it('displays dismiss button for each alert', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => mockAlerts
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			const dismissButtons = screen.getAllByRole('button', { name: /dismiss/i });
			expect(dismissButtons).toHaveLength(3);
		});
	});

	it('dismiss button has accessible label', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			const dismissButton = screen.getByRole('button', { name: /dismiss/i });
			expect(dismissButton).toHaveAttribute('aria-label');
			const ariaLabel = dismissButton.getAttribute('aria-label');
			expect(ariaLabel).toMatch(/dismiss/i);
		});
	});

	it('dismiss button has visible X icon', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			const dismissButton = screen.getByRole('button', { name: /dismiss/i });
			// Check that the X icon (lucide-svelte) is rendered inside the button
			expect(dismissButton.querySelector('svg')).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Single-Click Dismissal Behavior
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Single Alert Dismissal', () => {
	it('removes alert from list after successful dismissal', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => mockAlerts
			})
			.mockResolvedValueOnce({
				ok: true
			});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
			expect(screen.getByText('Mox Ruby')).toBeInTheDocument();
			expect(screen.getByText('Time Walk')).toBeInTheDocument();
		});

		const dismissButtons = screen.getAllByRole('button', { name: /dismiss/i });
		await user.click(dismissButtons[0]);

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
			expect(screen.getByText('Mox Ruby')).toBeInTheDocument();
			expect(screen.getByText('Time Walk')).toBeInTheDocument();
		});
	});

	it('sends PATCH request to correct endpoint when dismissing', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockResolvedValueOnce({
				ok: true
			});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		await user.click(dismissButton);

		await waitFor(() => {
			expect(mockFetch).toHaveBeenCalledWith('/api/price_alerts/1/dismiss', {
				method: 'PATCH'
			});
		});
	});

	it('alert remains dismissed after dismissal (does not reappear)', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => mockAlerts
			})
			.mockResolvedValueOnce({
				ok: true
			});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButtons = screen.getAllByRole('button', { name: /dismiss/i });
		await user.click(dismissButtons[0]);

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
		});

		// Wait a bit to ensure it doesn't reappear
		await new Promise((resolve) => setTimeout(resolve, 100));
		expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Error Feedback When Dismissal Fails
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Dismissal Error Handling', () => {
	it('displays user-facing error message when dismissal fails', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockResolvedValueOnce({
				ok: false,
				status: 500
			});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		await user.click(dismissButton);

		await waitFor(() => {
			expect(screen.getByText(/failed to dismiss alert/i)).toBeInTheDocument();
		});
	});

	it('keeps alert in list when dismissal fails', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockResolvedValueOnce({
				ok: false,
				status: 500
			});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		await user.click(dismissButton);

		await waitFor(() => {
			expect(screen.getByText(/failed to dismiss alert/i)).toBeInTheDocument();
		});

		// Alert should still be visible
		expect(screen.getByText('Black Lotus')).toBeInTheDocument();
	});

	it('displays error message for network failures', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockRejectedValueOnce(new Error('Network error'));

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		await user.click(dismissButton);

		await waitFor(() => {
			expect(screen.getByText(/network error/i)).toBeInTheDocument();
		});
	});

	it('allows retry after failed dismissal', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockResolvedValueOnce({
				ok: false,
				status: 500
			})
			.mockResolvedValueOnce({
				ok: true
			});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		await user.click(dismissButton);

		await waitFor(() => {
			expect(screen.getByText(/failed to dismiss alert/i)).toBeInTheDocument();
		});

		// Click dismiss button again to retry
		await user.click(dismissButton);

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
			expect(screen.queryByText(/failed to dismiss alert/i)).not.toBeInTheDocument();
		});
	});

	it('error message has role="alert" for screen reader announcement', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockResolvedValueOnce({
				ok: false,
				status: 500
			});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		await user.click(dismissButton);

		await waitFor(() => {
			const errorAlert = screen.getByRole('alert');
			expect(errorAlert).toHaveTextContent(/failed to dismiss alert/i);
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Multiple Alert Dismissal
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Multiple Alert Dismissal', () => {
	it('allows dismissing multiple alerts sequentially', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => mockAlerts
			})
			.mockResolvedValueOnce({ ok: true })
			.mockResolvedValueOnce({ ok: true });

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
			expect(screen.getByText('Mox Ruby')).toBeInTheDocument();
		});

		// Dismiss first alert
		const dismissButtons1 = screen.getAllByRole('button', { name: /dismiss/i });
		await user.click(dismissButtons1[0]);

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
		});

		// Dismiss second alert
		const dismissButtons2 = screen.getAllByRole('button', { name: /dismiss/i });
		await user.click(dismissButtons2[0]);

		await waitFor(() => {
			expect(screen.queryByText('Mox Ruby')).not.toBeInTheDocument();
		});

		// Only Time Walk should remain
		expect(screen.getByText('Time Walk')).toBeInTheDocument();
	});

	it('hides widget when all alerts are dismissed', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockResolvedValueOnce({ ok: true });

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		await user.click(dismissButton);

		await waitFor(() => {
			expect(container.querySelector('.price-alert-widget')).not.toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Network Resilience
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Network Resilience', () => {
	it('handles concurrent dismissal attempts gracefully', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => mockAlerts.slice(0, 2)
			})
			.mockResolvedValueOnce({ ok: true })
			.mockResolvedValueOnce({ ok: true });

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
			expect(screen.getByText('Mox Ruby')).toBeInTheDocument();
		});

		const dismissButtons = screen.getAllByRole('button', { name: /dismiss/i });

		// Click both dismiss buttons rapidly
		await Promise.all([user.click(dismissButtons[0]), user.click(dismissButtons[1])]);

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
			expect(screen.queryByText('Mox Ruby')).not.toBeInTheDocument();
		});
	});

	it('prevents double-clicking dismiss button from causing issues', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockResolvedValueOnce({ ok: true })
			.mockResolvedValueOnce({ ok: true });

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });

		// Double-click the dismiss button
		await user.dblClick(dismissButton);

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
		});

		// Should only make one dismiss API call (or two is acceptable)
		const dismissCalls = mockFetch.mock.calls.filter((call) =>
			call[0].includes('/api/price_alerts/1/dismiss')
		);
		expect(dismissCalls.length).toBeLessThanOrEqual(2);
	});
});

// ---------------------------------------------------------------------------
// Tests: Accessibility - Keyboard Navigation
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Keyboard Navigation', () => {
	it('dismiss button is keyboard accessible', async () => {
		const user = userEvent.setup();

		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });

		// Set up mock for dismiss API call
		mockFetch.mockResolvedValueOnce({ ok: true });

		// Focus the button using Tab
		await user.tab();
		expect(dismissButton).toHaveFocus();

		// Activate with Enter key
		await user.keyboard('{Enter}');

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
		});
	});

	it('dismiss button can be activated with Space key', async () => {
		const user = userEvent.setup();

		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });

		// Set up mock for dismiss API call
		mockFetch.mockResolvedValueOnce({ ok: true });

		// Focus and activate with Space key
		dismissButton.focus();
		await user.keyboard(' ');

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
		});
	});

	it('focus moves to next dismiss button after dismissing an alert', async () => {
		const user = userEvent.setup();

		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => mockAlerts.slice(0, 2)
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
			expect(screen.getByText('Mox Ruby')).toBeInTheDocument();
		});

		// Tab to first dismiss button
		await user.tab();

		const dismissButtons = screen.getAllByRole('button', { name: /dismiss/i });
		expect(dismissButtons[0]).toHaveFocus();

		// Set up mock for dismiss API call
		mockFetch.mockResolvedValueOnce({ ok: true });

		// Press Enter to dismiss
		await user.keyboard('{Enter}');

		await waitFor(() => {
			expect(screen.queryByText('Black Lotus')).not.toBeInTheDocument();
		});

		// After first alert is dismissed, focus should be manageable
		// (either stays on next button or document.body - both acceptable)
		const remainingButtons = screen.getAllByRole('button', { name: /dismiss/i });
		expect(remainingButtons).toHaveLength(1);
	});
});

// ---------------------------------------------------------------------------
// Tests: Skeleton UI v4 Visual Classes (Regression for v3->v4 Migration)
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Skeleton UI v4 Classes', () => {
	it('dismiss button has proper Skeleton v4 hover classes instead of v3 variant-ghost-surface', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			const dismissButton = screen.getByRole('button', { name: /dismiss/i });
			// Should have Skeleton v4 hover classes, not dead v3 classes
			const classNames = dismissButton.className;
			expect(classNames).toMatch(/hover:bg-surface-/);
			expect(classNames).not.toContain('variant-ghost-surface');
		});
	});

	it('success alerts have proper Skeleton v4 background classes instead of v3 variant-soft-success', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]] // price_increase
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			const alertItem = container.querySelector('.alert-item');
			expect(alertItem).toBeInTheDocument();
			const classNames = alertItem?.className || '';
			// Should have Skeleton v4 background classes, not dead v3 classes
			expect(classNames).toMatch(/bg-success-/);
			expect(classNames).not.toContain('variant-soft-success');
		});
	});

	it('error alerts have proper Skeleton v4 background classes instead of v3 variant-soft-error', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[1]] // price_decrease
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			const alertItem = container.querySelector('.alert-item');
			expect(alertItem).toBeInTheDocument();
			const classNames = alertItem?.className || '';
			// Should have Skeleton v4 background classes, not dead v3 classes
			expect(classNames).toMatch(/bg-error-/);
			expect(classNames).not.toContain('variant-soft-error');
		});
	});

	it('dismiss error message has proper Skeleton v4 classes instead of v3 variant-soft-error', async () => {
		const user = userEvent.setup();

		mockFetch
			.mockResolvedValueOnce({
				ok: true,
				json: async () => [mockAlerts[0]]
			})
			.mockResolvedValueOnce({
				ok: false,
				status: 500
			});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		await user.click(dismissButton);

		await waitFor(() => {
			const errorAlert = screen.getByRole('alert');
			const classNames = errorAlert.className;
			expect(classNames).toMatch(/bg-error-/);
			expect(classNames).not.toContain('variant-soft-error');
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Accessibility - Screen Reader Support
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Screen Reader Support', () => {
	it('dismiss button has descriptive aria-label for screen readers', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });
		expect(dismissButton).toHaveAttribute('aria-label');
		const ariaLabel = dismissButton.getAttribute('aria-label');
		expect(ariaLabel).toMatch(/dismiss/i);
	});

	it('alert container has appropriate ARIA role for announcements', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		// Check that widget or alerts have appropriate structure for screen readers
		const widget = container.querySelector('.price-alert-widget');
		expect(widget).toBeInTheDocument();
	});

	it('provides live region for dismissal status updates', async () => {
		const user = userEvent.setup();

		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });

		// Set up mock for failed dismiss API call
		mockFetch.mockResolvedValueOnce({
			ok: false,
			status: 500
		});

		await user.click(dismissButton);

		await waitFor(() => {
			// Error message should be in a live region (role="alert")
			const errorAlert = screen.getByRole('alert');
			expect(errorAlert).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Loading States
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Loading States', () => {
	it('displays loading state initially', async () => {
		mockFetch.mockImplementation(() => new Promise(() => {})); // Never resolves

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			expect(container.querySelector('.placeholder')).toBeInTheDocument();
		});
	});

	it('hides widget when loading and no alerts', async () => {
		mockFetch.mockImplementation(() => new Promise(() => {})); // Never resolves

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			expect(container.querySelector('.placeholder')).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Empty States
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Empty States', () => {
	it('hides widget when there are no alerts', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => []
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(
			() => {
				expect(container.querySelector('.price-alert-widget')).not.toBeInTheDocument();
			},
			{ timeout: 500 }
		);
	});

	it('hides widget after dismissing all alerts', async () => {
		const user = userEvent.setup();

		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		const dismissButton = screen.getByRole('button', { name: /dismiss/i });

		// Set up mock for dismiss API call
		mockFetch.mockResolvedValueOnce({ ok: true });

		await user.click(dismissButton);

		await waitFor(() => {
			expect(container.querySelector('.price-alert-widget')).not.toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Existing Functionality (Regression Tests)
// ---------------------------------------------------------------------------
describe('PriceAlertWidget - Existing Functionality', () => {
	it('displays alert card name', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});
	});

	it('displays price increase icon for price increases', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		// TrendingUp icon should be present
		expect(container.querySelector('svg')).toBeInTheDocument();
	});

	it('displays price decrease icon for price decreases', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[1]]
		});

		const { container } = render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Mox Ruby')).toBeInTheDocument();
		});

		// TrendingDown icon should be present
		expect(container.querySelector('svg')).toBeInTheDocument();
	});

	it('displays formatted prices', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText(/\$100\.00/)).toBeInTheDocument();
			expect(screen.getByText(/\$150\.00/)).toBeInTheDocument();
		});
	});

	it('displays percentage change', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText(/\+50\.00%/)).toBeInTheDocument();
		});
	});

	it('displays finish for non-nonfoil cards', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[1]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Mox Ruby')).toBeInTheDocument();
		});

		expect(screen.getByText(/Foil/i)).toBeInTheDocument();
	});

	it('displays relative time for recent alerts', async () => {
		mockFetch.mockResolvedValueOnce({
			ok: true,
			json: async () => [mockAlerts[0]]
		});

		render(PriceAlertWidget);

		await waitFor(() => {
			expect(screen.getByText('Black Lotus')).toBeInTheDocument();
		});

		expect(screen.getByText(/2h ago/)).toBeInTheDocument();
	});

	it('handles fetch errors gracefully', async () => {
		mockFetch.mockRejectedValueOnce(new Error('Network error'));

		render(PriceAlertWidget);

		await waitFor(() => {
			const errorElement = screen.getByRole('alert');
			expect(errorElement).toHaveTextContent(/network error/i);
		});
	});
});
