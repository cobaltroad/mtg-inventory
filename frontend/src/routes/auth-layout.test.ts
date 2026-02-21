import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { cleanup } from '@testing-library/svelte';
import { base } from '$app/paths';

vi.mock('$lib/services/authService.svelte', () => ({
	getAuthState: vi.fn(() => ({
		user: null,
		isAuthenticated: false,
		loading: false
	})),
	checkAuthStatus: vi.fn(() => Promise.resolve()),
	logout: vi.fn(() => Promise.resolve())
}));

vi.mock('$app/paths', () => ({
	base: '/projects/mtg'
}));

describe('Auth Layout - VITE_AUTH_ENABLED', () => {
	let originalEnv: NodeJS.ProcessEnv;

	beforeEach(() => {
		originalEnv = process.env;
		vi.resetModules();
	});

	afterEach(() => {
		process.env = originalEnv;
		cleanup();
	});

	it('redirects to login when auth enabled and user not authenticated', async () => {
		process.env = { ...originalEnv, VITE_AUTH_ENABLED: 'true' };
		vi.resetModules();

		const { load } = await import('../routes/+layout.ts');
		
		const mockUrl = {
			pathname: '/inventory'
		} as any;

		await expect(load({ url: mockUrl } as any)).rejects.toThrow();
	});

	it('does not redirect when auth disabled (default)', async () => {
		delete process.env.VITE_AUTH_ENABLED;
		vi.resetModules();

		const { load } = await import('../routes/+layout.ts');
		
		const mockUrl = {
			pathname: '/inventory'
		} as any;

		const result = await load({ url: mockUrl } as any);
		expect(result).toEqual({});
	});

	it('does not redirect to public routes', async () => {
		process.env = { ...originalEnv, VITE_AUTH_ENABLED: 'true' };
		vi.resetModules();

		const { load } = await import('../routes/+layout.ts');
		
		const mockUrl = {
			pathname: '/login'
		} as any;

		const result = await load({ url: mockUrl } as any);
		expect(result).toEqual({});
	});
});
