import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fetchCommanders, fetchCommander } from './commanderService';

// Mock $app/paths
vi.mock('$app/paths', () => ({
	base: ''
}));

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('commanderService', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	describe('fetchCommanders', () => {
		it('fetches all commanders from the API', async () => {
			const mockCommanders = [
				{
					id: 1,
					name: "Atraxa, Praetors' Voice",
					rank: 1,
					edhrec_url: 'https://edhrec.com/commanders/atraxa-praetors-voice',
					last_scraped_at: '2026-02-05T10:00:00Z',
					card_count: 100
				},
				{
					id: 2,
					name: 'Muldrotha, the Gravetide',
					rank: 2,
					edhrec_url: 'https://edhrec.com/commanders/muldrotha-the-gravetide',
					last_scraped_at: '2026-02-05T10:00:00Z',
					card_count: 99
				}
			];

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockCommanders
			});

			const result = await fetchCommanders();

			expect(mockFetch).toHaveBeenCalledWith('/api/commanders');
			expect(result).toEqual(mockCommanders);
		});

		it('throws an error when the API request fails', async () => {
			mockFetch.mockResolvedValueOnce({
				ok: false,
				status: 500
			});

			await expect(fetchCommanders()).rejects.toThrow('Failed to fetch commanders');
		});

		it('throws an error when fetch throws', async () => {
			mockFetch.mockRejectedValueOnce(new Error('Network error'));

			await expect(fetchCommanders()).rejects.toThrow('Network error');
		});
	});

	describe('fetchCommander', () => {
		it('fetches a single commander with decklist from the API', async () => {
			const mockCommander = {
				id: 1,
				name: "Atraxa, Praetors' Voice",
				rank: 1,
				edhrec_url: 'https://edhrec.com/commanders/atraxa-praetors-voice',
				last_scraped_at: '2026-02-05T10:00:00Z',
				card_count: 100,
				cards: [
					{ card_id: 'abc-123', card_name: 'Sol Ring', quantity: 1 },
					{ card_id: 'def-456', card_name: 'Command Tower', quantity: 1 }
				]
			};

			mockFetch.mockResolvedValueOnce({
				ok: true,
				json: async () => mockCommander
			});

			const result = await fetchCommander('1');

			expect(mockFetch).toHaveBeenCalledWith('/api/commanders/1');
			expect(result).toEqual(mockCommander);
		});

		it('throws an error when commander is not found', async () => {
			mockFetch.mockResolvedValueOnce({
				ok: false,
				status: 404
			});

			await expect(fetchCommander('999')).rejects.toThrow('Commander not found');
		});

		it('throws an error when server returns 500', async () => {
			mockFetch.mockResolvedValueOnce({
				ok: false,
				status: 500
			});

			await expect(fetchCommander('1')).rejects.toThrow('Failed to fetch commander');
		});

		it('throws an error when fetch throws', async () => {
			mockFetch.mockRejectedValueOnce(new Error('Network error'));

			await expect(fetchCommander('1')).rejects.toThrow('Network error');
		});
	});
});
