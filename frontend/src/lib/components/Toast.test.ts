import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, cleanup } from '@testing-library/svelte';
import Toast from './Toast.svelte';

describe('Toast', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	describe('Display and Styling', () => {
		it('renders toast with message', () => {
			render(Toast, { props: { message: 'Test message' } });

			const toast = screen.getByRole('status');
			expect(toast).toBeInTheDocument();
			expect(toast).toHaveTextContent('Test message');
		});

		it('applies success styling by default', () => {
			render(Toast, { props: { message: 'Success message' } });

			const toast = screen.getByRole('status');
			expect(toast).toHaveClass('success');
		});

		it('applies error styling when type is error', () => {
			render(Toast, { props: { message: 'Error message', type: 'error' } });

			const toast = screen.getByRole('status');
			expect(toast).toHaveClass('error');
		});

		it('has aria-live polite for accessibility', () => {
			render(Toast, { props: { message: 'Test message' } });

			const toast = screen.getByRole('status');
			expect(toast).toHaveAttribute('aria-live', 'polite');
		});
	});

	describe('Auto-dismiss Behavior', () => {
		it('auto-dismisses after default duration', async () => {
			vi.useFakeTimers();

			const onDismiss = vi.fn();
			render(Toast, { props: { message: 'Test message', onDismiss } });

			expect(screen.getByRole('status')).toBeInTheDocument();

			// Fast-forward 3 seconds (default duration)
			vi.advanceTimersByTime(3000);

			await vi.waitFor(() => {
				expect(screen.queryByRole('status')).not.toBeInTheDocument();
			});

			expect(onDismiss).toHaveBeenCalledOnce();

			vi.useRealTimers();
		});

		it('auto-dismisses after custom duration', async () => {
			vi.useFakeTimers();

			const onDismiss = vi.fn();
			render(Toast, { props: { message: 'Test message', duration: 5000, onDismiss } });

			expect(screen.getByRole('status')).toBeInTheDocument();

			// Fast-forward 4 seconds (not enough)
			vi.advanceTimersByTime(4000);

			expect(screen.getByRole('status')).toBeInTheDocument();
			expect(onDismiss).not.toHaveBeenCalled();

			// Fast-forward 1 more second (total 5 seconds)
			vi.advanceTimersByTime(1000);

			await vi.waitFor(() => {
				expect(screen.queryByRole('status')).not.toBeInTheDocument();
			});

			expect(onDismiss).toHaveBeenCalledOnce();

			vi.useRealTimers();
		});

		it('does not auto-dismiss when duration is 0', async () => {
			vi.useFakeTimers();

			const onDismiss = vi.fn();
			render(Toast, { props: { message: 'Test message', duration: 0, onDismiss } });

			expect(screen.getByRole('status')).toBeInTheDocument();

			// Fast-forward significant time
			vi.advanceTimersByTime(10000);

			expect(screen.getByRole('status')).toBeInTheDocument();
			expect(onDismiss).not.toHaveBeenCalled();

			vi.useRealTimers();
		});

		it('calls onDismiss callback when auto-dismissing', async () => {
			vi.useFakeTimers();

			const onDismiss = vi.fn();
			render(Toast, { props: { message: 'Test message', onDismiss } });

			vi.advanceTimersByTime(3000);

			await vi.waitFor(() => {
				expect(onDismiss).toHaveBeenCalledOnce();
			});

			vi.useRealTimers();
		});

		it('works without onDismiss callback', async () => {
			vi.useFakeTimers();

			render(Toast, { props: { message: 'Test message' } });

			expect(screen.getByRole('status')).toBeInTheDocument();

			vi.advanceTimersByTime(3000);

			await vi.waitFor(() => {
				expect(screen.queryByRole('status')).not.toBeInTheDocument();
			});

			vi.useRealTimers();
		});
	});
});
