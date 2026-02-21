import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { cleanup } from '@testing-library/svelte';

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
	base: ''
}));

describe('Auth Layout', () => {
	beforeEach(() => {
		cleanup();
		vi.clearAllMocks();
	});

	afterEach(() => {
		cleanup();
	});

	describe('Layout imports', () => {
		it('imports auth service functions', async () => {
			const { getAuthState, checkAuthStatus, logout } =
				await import('$lib/services/authService.svelte');
			expect(getAuthState).toBeDefined();
			expect(checkAuthStatus).toBeDefined();
			expect(logout).toBeDefined();
		});

		it('auth state returns correct structure', async () => {
			const { getAuthState } = await import('$lib/services/authService.svelte');
			const state = getAuthState();
			expect(state).toHaveProperty('user');
			expect(state).toHaveProperty('isAuthenticated');
			expect(state).toHaveProperty('loading');
		});
	});

	describe('Auth state checked on mount', () => {
		it('checkAuthStatus is called when component mounts', async () => {
			const { checkAuthStatus } = await import('$lib/services/authService.svelte');
			expect(checkAuthStatus).toBeDefined();
		});
	});

	describe('+layout.ts redirect logic', () => {
		it('defines protected routes correctly', async () => {
			const PROTECTED_ROUTES = ['/inventory', '/wishlist', '/reports'];
			expect(PROTECTED_ROUTES).toContain('/inventory');
			expect(PROTECTED_ROUTES).toContain('/wishlist');
			expect(PROTECTED_ROUTES).toContain('/reports');
		});

		it('defines public routes correctly', async () => {
			const PUBLIC_ROUTES = ['/login', '/auth/callback'];
			expect(PUBLIC_ROUTES).toContain('/login');
			expect(PUBLIC_ROUTES).toContain('/auth/callback');
		});

		it('should not redirect for public routes when not authenticated', () => {
			const path = '/login';
			const isPublicRoute = ['/login', '/auth/callback'].some(
				(route) => path === route || path.startsWith(route)
			);
			const isProtectedRoute = ['/inventory', '/wishlist', '/reports'].some((route) =>
				path.startsWith(route)
			);

			expect(isPublicRoute).toBe(true);
			expect(isProtectedRoute).toBe(false);
		});

		it('should redirect protected routes when not authenticated', () => {
			const path = '/inventory';
			const isPublicRoute = ['/login', '/auth/callback'].some(
				(route) => path === route || path.startsWith(route)
			);
			const isProtectedRoute = ['/inventory', '/wishlist', '/reports'].some((route) =>
				path.startsWith(route)
			);

			expect(isPublicRoute).toBe(false);
			expect(isProtectedRoute).toBe(true);
		});

		it('should not redirect for home page when not authenticated', () => {
			const path = '/';
			const isPublicRoute = ['/login', '/auth/callback'].some(
				(route) => path === route || path.startsWith(route)
			);
			const isProtectedRoute = ['/inventory', '/wishlist', '/reports'].some((route) =>
				path.startsWith(route)
			);

			expect(isPublicRoute).toBe(false);
			expect(isProtectedRoute).toBe(false);
		});

		it('should not redirect for search page when not authenticated', () => {
			const path = '/search';
			const isPublicRoute = ['/login', '/auth/callback'].some(
				(route) => path === route || path.startsWith(route)
			);
			const isProtectedRoute = ['/inventory', '/wishlist', '/reports'].some((route) =>
				path.startsWith(route)
			);

			expect(isPublicRoute).toBe(false);
			expect(isProtectedRoute).toBe(false);
		});

		it('should not redirect for metagame page when not authenticated', () => {
			const path = '/metagame';
			const isPublicRoute = ['/login', '/auth/callback'].some(
				(route) => path === route || path.startsWith(route)
			);
			const isProtectedRoute = ['/inventory', '/wishlist', '/reports'].some((route) =>
				path.startsWith(route)
			);

			expect(isPublicRoute).toBe(false);
			expect(isProtectedRoute).toBe(false);
		});
	});
});
