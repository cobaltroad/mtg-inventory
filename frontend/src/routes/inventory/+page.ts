import { base } from '$app/paths';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch }) => {
	try {
		const res = await fetch(`${base}/api/inventory`);
		if (!res.ok) {
			throw new Error(`Failed to fetch inventory: ${res.statusText}`);
		}
		const items = await res.json();
		return { items };
	} catch (error) {
		console.error('Failed to fetch inventory:', error);
		return {
			items: [],
			error: error instanceof Error ? error.message : 'Failed to load inventory'
		};
	}
};
