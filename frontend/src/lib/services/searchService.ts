import { base } from '$app/paths';
import type { SearchResults } from '$lib/types/search';

/**
 * Performs a search across decklists and inventory
 * @param query - The search query string
 * @returns Promise resolving to search results
 * @throws Error if the API request fails
 */
export async function performSearch(query: string): Promise<SearchResults> {
	const encodedQuery = encodeURIComponent(query);
	const response = await fetch(`${base}/api/search?q=${encodedQuery}`, {
		method: 'GET',
		headers: {
			'Content-Type': 'application/json'
		}
	});

	if (!response.ok) {
		throw new Error(`Search failed: ${response.status} ${response.statusText}`);
	}

	const results: SearchResults = await response.json();
	return results;
}
