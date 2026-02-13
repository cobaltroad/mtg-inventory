import { base } from '$app/paths';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch }) => {
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
