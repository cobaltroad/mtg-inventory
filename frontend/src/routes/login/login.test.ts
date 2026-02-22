import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/svelte';
import LoginPage from './+page.svelte';

vi.mock('$lib/services/authService.svelte', () => ({
	login: vi.fn()
}));

vi.mock('$app/paths', () => ({
	base: ''
}));

describe('Login Page', () => {
	beforeEach(() => {
		cleanup();
		vi.clearAllMocks();
		// Set VITE_AUTH_ENABLED for tests that need the login button
		import.meta.env.VITE_AUTH_ENABLED = 'true';
	});

	afterEach(() => {
		cleanup();
		import.meta.env.VITE_AUTH_ENABLED = undefined;
	});

	it('renders the page title', () => {
		render(LoginPage);
		expect(screen.getByText('MTG Inventory')).toBeTruthy();
	});

	it('renders the subtitle', () => {
		render(LoginPage);
		expect(screen.getByText('Sign in to manage your collection')).toBeTruthy();
	});

	it('renders the login with Discord link', () => {
		render(LoginPage);
		const link = screen.getByRole('link', { name: /login with discord/i });
		expect(link).toBeTruthy();
	});

	it('link has correct href', () => {
		render(LoginPage);
		const link = screen.getByRole('link', { name: /login with discord/i });
		expect(link.getAttribute('href')).toBe('/api/auth/discord');
	});
});
