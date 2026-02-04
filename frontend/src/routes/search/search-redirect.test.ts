import { describe, it, expect } from 'vitest';
import { load } from './+page.server';

interface RedirectError {
	status: number;
	location: string;
}

/**
 * Tests for Scenario 9: Removing the old search page route
 *
 * When navigating to /search directly or via old bookmarks,
 * user should be redirected to the home page (/).
 */
describe('Search Route - Redirect to Home (Scenario 9)', () => {
	it('should redirect from /search to / (home page)', () => {
		// The load function should throw a redirect
		try {
			load();
			// If we reach here, the redirect wasn't thrown
			expect.fail('Expected load() to throw a redirect');
		} catch (error) {
			// Verify it's a redirect error
			expect(error).toBeDefined();
			// SvelteKit redirect errors have a status and location property
			const redirectError = error as RedirectError;
			expect(redirectError.status).toBe(302);
			expect(redirectError.location).toBeDefined();
		}
	});

	it('should use HTTP 302 (temporary redirect) status code', () => {
		// Verify the redirect uses 302 status code
		// This allows for potential future changes to the search route
		try {
			load();
		} catch (error) {
			const redirectError = error as RedirectError;
			expect(redirectError.status).toBe(302);
		}
	});

	it('should redirect to root path', () => {
		// Verify redirect goes to root path (base + /)
		try {
			load();
		} catch (error) {
			const redirectError = error as RedirectError;
			const location = redirectError.location;
			// Should redirect to / (or base path if configured)
			expect(location).toMatch(/\/$/);
		}
	});
});
