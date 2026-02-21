import { describe, it, expect, vi, beforeEach } from 'vitest';
import { checkAuthStatus, login, logout, getAuthState } from './authService.svelte';
import { base } from '$app/paths';
import { goto } from '$app/navigation';

vi.mock('$app/paths', () => ({
	base: '/test-base'
}));

vi.mock('$app/navigation', () => ({
	goto: vi.fn()
}));

const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('authService', () => {
	beforeEach(() => {
		mockFetch.mockClear();
		goto.mockClear();
	});

	describe('getAuthState', () => {
		it('should return initial state with loading: true, isAuthenticated: false, user: null', () => {
			const state = getAuthState();

			expect(state.loading).toBe(true);
			expect(state.isAuthenticated).toBe(false);
			expect(state.user).toBe(null);
		});
	});

	describe('checkAuthStatus', () => {
		it('should return authenticated user data when logged in', async () => {
			const mockUser = {
				id: 1,
				email: 'test@example.com',
				name: 'Test User'
			};

			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => ({
					authenticated: true,
					user: mockUser
				})
			});

			await checkAuthStatus();
			const state = getAuthState();

			expect(state.isAuthenticated).toBe(true);
			expect(state.user).toEqual(mockUser);
			expect(state.loading).toBe(false);
		});

		it('should return unauthenticated when not logged in', async () => {
			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => ({
					authenticated: false,
					user: null
				})
			});

			await checkAuthStatus();
			const state = getAuthState();

			expect(state.isAuthenticated).toBe(false);
			expect(state.user).toBe(null);
			expect(state.loading).toBe(false);
		});

		it('should handle API errors gracefully', async () => {
			mockFetch.mockRejectedValue(new Error('Network error'));

			await checkAuthStatus();
			const state = getAuthState();

			expect(state.isAuthenticated).toBe(false);
			expect(state.user).toBe(null);
			expect(state.loading).toBe(false);
		});
	});

	describe('login', () => {
		it('should redirect to Discord OAuth URL', () => {
			login();

			expect(goto).toHaveBeenCalledWith(`${base}/api/auth/discord`);
		});
	});

	describe('logout', () => {
		it('should clear user and redirect to login', async () => {
			mockFetch.mockResolvedValue({
				ok: true,
				json: async () => ({})
			});

			await logout();

			expect(mockFetch).toHaveBeenCalledWith(
				`${base}/api/auth/logout`,
				expect.objectContaining({
					method: 'DELETE'
				})
			);

			const state = getAuthState();
			expect(state.user).toBe(null);
			expect(state.isAuthenticated).toBe(false);
			expect(goto).toHaveBeenCalledWith(`${base}/login`);
		});

		it('should clear state even if logout request fails', async () => {
			mockFetch.mockRejectedValue(new Error('Network error'));

			await logout();

			const state = getAuthState();
			expect(state.user).toBe(null);
			expect(state.isAuthenticated).toBe(false);
			expect(goto).toHaveBeenCalledWith(`${base}/login`);
		});
	});
});
