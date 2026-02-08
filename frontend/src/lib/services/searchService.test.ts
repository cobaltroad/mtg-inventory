import { describe, it, expect, vi, beforeEach } from 'vitest';
import { performSearch } from './searchService';
import { base } from '$app/paths';
import type { SearchResults } from '$lib/types/search';

/**
 * TDD Tests for Search Service
 *
 * These tests verify:
 * - API call with correct URL and parameters
 * - Proper response handling
 * - Error handling
 * - Type safety
 */

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('searchService - performSearch', () => {
	beforeEach(() => {
		mockFetch.mockClear();
	});

	it('should call API with correct URL and query parameter', async () => {
		const mockResults: SearchResults = {
			query: 'Lightning Bolt',
			decklist_results: [],
			inventory_results: [],
			total_decklist_count: 0,
			total_inventory_count: 0
		};

		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => mockResults
		});

		await performSearch('Lightning Bolt');

		expect(mockFetch).toHaveBeenCalledWith(
			`${base}/api/search?q=Lightning%20Bolt`,
			expect.objectContaining({
				method: 'GET',
				headers: expect.objectContaining({
					'Content-Type': 'application/json'
				})
			})
		);
	});

	it('should return search results on successful API call', async () => {
		const mockResults: SearchResults = {
			query: 'Sol Ring',
			decklist_results: [
				{
					id: '1',
					name: 'Sol Ring',
					mana_cost: '{1}',
					type_line: 'Artifact',
					oracle_text: 'Tap: Add {C}{C}.',
					image_url: 'https://example.com/sol-ring.jpg',
					commander_id: 1,
					commander_name: 'Test Commander',
					deck_url: 'https://edhrec.com/test'
				}
			],
			inventory_results: [
				{
					id: '2',
					name: 'Sol Ring',
					mana_cost: '{1}',
					type_line: 'Artifact',
					oracle_text: 'Tap: Add {C}{C}.',
					image_url: 'https://example.com/sol-ring.jpg',
					quantity: 3,
					foil_quantity: 1
				}
			],
			total_decklist_count: 1,
			total_inventory_count: 1
		};

		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => mockResults
		});

		const results = await performSearch('Sol Ring');

		expect(results).toEqual(mockResults);
		expect(results.decklist_results).toHaveLength(1);
		expect(results.inventory_results).toHaveLength(1);
	});

	it('should handle empty results', async () => {
		const mockResults: SearchResults = {
			query: 'NonexistentCard',
			decklist_results: [],
			inventory_results: [],
			total_decklist_count: 0,
			total_inventory_count: 0
		};

		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => mockResults
		});

		const results = await performSearch('NonexistentCard');

		expect(results.decklist_results).toHaveLength(0);
		expect(results.inventory_results).toHaveLength(0);
		expect(results.total_decklist_count).toBe(0);
		expect(results.total_inventory_count).toBe(0);
	});

	it('should throw error when API returns error response', async () => {
		mockFetch.mockResolvedValue({
			ok: false,
			status: 500,
			statusText: 'Internal Server Error'
		});

		await expect(performSearch('test')).rejects.toThrow('Search failed: 500 Internal Server Error');
	});

	it('should throw error when network request fails', async () => {
		mockFetch.mockRejectedValue(new Error('Network error'));

		await expect(performSearch('test')).rejects.toThrow('Network error');
	});

	it('should properly encode special characters in query', async () => {
		const mockResults: SearchResults = {
			query: 'card & name',
			decklist_results: [],
			inventory_results: [],
			total_decklist_count: 0,
			total_inventory_count: 0
		};

		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => mockResults
		});

		await performSearch('card & name');

		expect(mockFetch).toHaveBeenCalledWith(
			`${base}/api/search?q=card%20%26%20name`,
			expect.any(Object)
		);
	});

	it('should handle queries with multiple words', async () => {
		const mockResults: SearchResults = {
			query: 'Black Lotus Flower',
			decklist_results: [],
			inventory_results: [],
			total_decklist_count: 0,
			total_inventory_count: 0
		};

		mockFetch.mockResolvedValue({
			ok: true,
			json: async () => mockResults
		});

		await performSearch('Black Lotus Flower');

		expect(mockFetch).toHaveBeenCalledWith(
			`${base}/api/search?q=Black%20Lotus%20Flower`,
			expect.any(Object)
		);
	});
});
