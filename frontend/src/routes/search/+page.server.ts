import { redirect } from '@sveltejs/kit';
import { base } from '$app/paths';

/**
 * Load function for the old /search route.
 * Redirects to home page since search functionality is now in a drawer.
 *
 * This ensures old bookmarks and direct navigation to /search
 * redirect users to the home page instead of showing a 404.
 */
export function load() {
	throw redirect(302, `${base}/`);
}
