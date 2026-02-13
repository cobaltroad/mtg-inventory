import { base } from '$app/paths';
import type { PageLoad } from './$types';
import { browser } from '$app/environment';

export const load: PageLoad = async ({ fetch, url }) => {
	try {
		// Extract pagination parameters from URL
		const page = url.searchParams.get('page') || '1';

		// Get per_page from URL, or fallback to localStorage, or default to 20
		let perPage = url.searchParams.get('per_page');
		if (!perPage && browser) {
			perPage = localStorage.getItem('inventory-page-size') || '20';
		}
		if (!perPage) {
			perPage = '20';
		}

		// Fetch with pagination parameters
		const res = await fetch(`${base}/api/inventory?page=${page}&per_page=${perPage}`);
		if (!res.ok) {
			throw new Error(`Failed to fetch inventory: ${res.statusText}`);
		}

		const data = await res.json();

		// Handle both paginated and non-paginated response formats
		// Paginated: { items: [...], page: 1, per_page: 20, total_count: 150, total_pages: 8 }
		// Non-paginated (backwards compatibility): [...]
		if (Array.isArray(data)) {
			// Legacy format - convert to paginated format
			return {
				items: data,
				page: 1,
				per_page: data.length,
				total_count: data.length,
				total_pages: 1
			};
		}

		// New paginated format
		return {
			items: data.items || [],
			page: data.page || 1,
			per_page: data.per_page || 20,
			total_count: data.total_count || 0,
			total_pages: data.total_pages || 0
		};
	} catch (error) {
		console.error('Failed to fetch inventory:', error);
		return {
			items: [],
			page: 1,
			per_page: 20,
			total_count: 0,
			total_pages: 0,
			error: error instanceof Error ? error.message : 'Failed to load inventory'
		};
	}
};
