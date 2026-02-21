import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, cleanup, waitFor } from '@testing-library/svelte';
import CallbackPage from './+page.svelte';

vi.mock('$lib/services/authService.svelte', () => ({
	checkAuthStatus: vi.fn().mockResolvedValue(undefined)
}));

vi.mock('$app/navigation', () => ({
	goto: vi.fn()
}));

vi.mock('$app/paths', () => ({
	base: '/test-base'
}));

describe('Auth Callback Page', () => {
	beforeEach(() => {
		cleanup();
		vi.clearAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	it('renders loading spinner while checking auth status', () => {
		render(CallbackPage);
		expect(screen.getByText('Verifying authentication...')).toBeTruthy();
	});

	it('calls checkAuthStatus on mount', async () => {
		const { checkAuthStatus } = await import('$lib/services/authService.svelte');
		render(CallbackPage);

		await waitFor(() => {
			expect(checkAuthStatus).toHaveBeenCalledTimes(1);
		});
	});

	it('navigates to inventory after auth check', async () => {
		const { goto } = await import('$app/navigation');
		render(CallbackPage);

		await waitFor(() => {
			expect(goto).toHaveBeenCalledWith('/test-base/inventory');
		});
	});
});
