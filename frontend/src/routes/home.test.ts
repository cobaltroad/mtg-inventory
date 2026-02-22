import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, cleanup, waitFor } from '@testing-library/svelte';

// Mock $app/paths so we can control `base` in tests
vi.mock('$app/paths', () => ({
	base: process.env.PUBLIC_BASE_PATH || ''
}));

// Mock LayerCake to avoid rendering issues in test environment
vi.mock('layercake', () => ({
	LayerCake: vi.fn(() => ({
		$$: {}
	})),
	Svg: vi.fn(() => ({
		$$: {}
	}))
}));

const BASE = process.env.PUBLIC_BASE_PATH || '';

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

// Import AFTER the mock is registered so the component picks it up
import HomePage from './+page.svelte';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe('Home Page', () => {
	let originalEnv: NodeJS.ProcessEnv;

	beforeEach(() => {
		originalEnv = process.env;
		cleanup();
		vi.clearAllMocks();

		mockFetch.mockImplementation((url) => {
			if (url.includes('/api/auth/status')) {
				return Promise.resolve({
					ok: true,
					json: async () => ({ authenticated: false, user: null })
				});
			}
			if (url.includes('/api/price_alerts')) {
				return Promise.resolve({
					ok: true,
					json: async () => []
				});
			}
			if (url.includes('/api/inventory/value_timeline')) {
				return Promise.resolve({
					ok: true,
					json: async () => ({
						time_period: '30',
						timeline: [],
						summary: {
							start_value_cents: 0,
							end_value_cents: 0,
							change_cents: 0,
							change_percentage: 0.0
						}
					})
				});
			}
			return Promise.reject(new Error('Unhandled fetch URL'));
		});
	});

	afterEach(() => {
		process.env = originalEnv;
		vi.resetModules();
	});

	it('renders the search link with the base path prepended', async () => {
		render(HomePage);

		await waitFor(() => {
			const link = screen.getByRole('link', { name: /search cards/i });
			expect(link).toHaveAttribute('href', `${BASE}/search`);
		});
	});

	it('search button has proper Skeleton v4 classes instead of v3 variant-filled-primary', async () => {
		render(HomePage);

		await waitFor(() => {
			const link = screen.getByRole('link', { name: /search cards/i });
			const classNames = link.className;
			expect(classNames).toMatch(/bg-primary-/);
			expect(classNames).not.toContain('variant-filled-primary');
		});
	});

	it('redirects to login when not authenticated and auth is enabled', async () => {
		process.env = { ...originalEnv, VITE_AUTH_ENABLED: 'true' };
		vi.resetModules();

		const { load } = await import('./+page.ts');

		const mockUrl = {
			pathname: '/'
		} as any;

		await expect(load({ url: mockUrl, fetch: mockFetch } as any)).rejects.toThrow();
	});
});
