import { base } from '$app/paths';
import { redirect } from '@sveltejs/kit';
import type { PageLoad } from './$types';
import { browser } from '$app/environment';

const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED !== 'false';

export const load: PageLoad = async ({ fetch, url }) => {
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

		// Get sort from URL, or fallback to localStorage, or default to name-asc
		let sort = url.searchParams.get('sort');
		if (!sort && browser) {
			sort = localStorage.getItem('inventory-sort') || 'name-asc';
		}
		if (!sort) {
			sort = 'name-asc';
		}

		// Get color filters from URL, or fallback to localStorage
		let colors = url.searchParams.get('colors');
		if (!colors && browser) {
			colors = localStorage.getItem('inventory-colors') || '';
		}
		if (!colors) {
			colors = '';
		}

		// Build query parameters
		const params = new URLSearchParams({
			page,
			per_page: perPage,
			sort
		});

		// Add colors parameter if present
		if (colors) {
			params.set('colors', colors);
		}

		// Fetch with pagination, sort, and color filter parameters
		const res = await fetch(`${base}/api/inventory?${params.toString()}`);
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
				total_pages: 1,
				stats: null
			};
		}

		// New paginated format
		return {
			items: data.items || [],
			page: data.page || 1,
			per_page: data.per_page || 20,
			total_count: data.total_count || 0,
			total_pages: data.total_pages || 0,
			sort: data.sort || 'name-asc',
			stats: data.stats || null
		};
	} catch (error) {
		console.error('Failed to fetch inventory:', error);
		return {
			items: [],
			page: 1,
			per_page: 20,
			total_count: 0,
			total_pages: 0,
			sort: 'name-asc',
			stats: null,
			error: error instanceof Error ? error.message : 'Failed to load inventory'
		};
	}
};
