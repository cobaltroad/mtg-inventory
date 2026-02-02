import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, cleanup } from '@testing-library/svelte';

// ---------------------------------------------------------------------------
// Mock $app/paths so we can control `base` in tests
// ---------------------------------------------------------------------------
vi.mock('$app/paths', () => ({
	base: '/projects/mtg-inventory'
}));

// Import AFTER the mock is registered so the component picks it up
import HomePage from './+page.svelte';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe('Home Page', () => {
	beforeEach(() => {
		cleanup();
		vi.restoreAllMocks();
	});

	it('renders the search link with the base path prepended', () => {
		render(HomePage);

		const link = screen.getByRole('link', { name: /search cards/i });
		expect(link).toHaveAttribute('href', '/projects/mtg-inventory/search');
	});
});
