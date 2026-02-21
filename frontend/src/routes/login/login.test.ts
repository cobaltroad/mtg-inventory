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
	});

	afterEach(() => {
		cleanup();
	});

	it('renders the page title', () => {
		render(LoginPage);
		expect(screen.getByText('MTG Inventory')).toBeTruthy();
	});

	it('renders the subtitle', () => {
		render(LoginPage);
		expect(screen.getByText('Sign in to manage your collection')).toBeTruthy();
	});

	it('renders the login with Discord button', () => {
		render(LoginPage);
		const button = screen.getByRole('button', { name: /login with discord/i });
		expect(button).toBeTruthy();
	});

	it('calls login function when button is clicked', async () => {
		const { login } = await import('$lib/services/authService.svelte');
		render(LoginPage);

		const button = screen.getByRole('button', { name: /login with discord/i });
		await fireEvent.click(button);

		expect(login).toHaveBeenCalledTimes(1);
	});
});
