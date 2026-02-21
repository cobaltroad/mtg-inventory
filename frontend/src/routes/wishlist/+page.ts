import { base } from '$app/paths';
import { redirect } from '@sveltejs/kit';
import type { PageLoad } from './$types';

const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED === 'true';

export const load: PageLoad = async ({ fetch }) => {
	// Check authentication first (only if auth is enabled)
	if (AUTH_ENABLED) {
		try {
			const authRes = await fetch(`${base}/api/auth/status`);
			const authData = await authRes.json();
			
			if (!authData.authenticated) {
				throw redirect(302, `${base}/login`);
			}
		} catch (e) {
			if (e.status === 302) throw e;
			throw redirect(302, `${base}/login`);
		}
	}

	try {
		const res = await fetch(`${base}/api/wishlist`);
		if (!res.ok) {
			throw new Error(`Failed to fetch wishlist: ${res.statusText}`);
		}
		const items = await res.json();
		return { items };
	} catch (error) {
		console.error('Failed to fetch wishlist:', error);
		return {
			items: [],
			error: error instanceof Error ? error.message : 'Failed to load wishlist'
		};
	}
};
