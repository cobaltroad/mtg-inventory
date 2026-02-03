import { vi } from 'vitest';

// ---------------------------------------------------------------------------
// Test Data
// ---------------------------------------------------------------------------
export const MOCK_CARD = {
	id: 'card-123',
	name: 'Lightning Bolt'
};

export const MOCK_PRINTINGS = [
	{
		id: 'print-1',
		name: 'Lightning Bolt',
		set: 'm21',
		set_name: 'Core Set 2021',
		collector_number: '125',
		image_url: 'https://example.com/m21-bolt.jpg',
		released_at: '2020-07-03'
	},
	{
		id: 'print-2',
		name: 'Lightning Bolt',
		set: 'm10',
		set_name: 'Magic 2010',
		collector_number: '146',
		image_url: 'https://example.com/m10-bolt.jpg',
		released_at: '2009-07-17'
	},
	{
		id: 'print-3',
		name: 'Lightning Bolt',
		set: 'lea',
		set_name: 'Limited Edition Alpha',
		collector_number: '157',
		image_url: 'https://example.com/lea-bolt.jpg',
		released_at: '1993-08-05'
	}
];

// ---------------------------------------------------------------------------
// Mock Helpers
// ---------------------------------------------------------------------------
export function mockFetchForPrintings(printings = MOCK_PRINTINGS, shouldFail = false) {
	return vi.fn().mockImplementation((url: string) => {
		if (typeof url === 'string' && url.includes('/printings')) {
			if (shouldFail) {
				return Promise.reject(new Error('Network error'));
			}
			return Promise.resolve({
				ok: true,
				json: () => Promise.resolve({ printings })
			});
		}
		return Promise.resolve({ ok: true, json: () => Promise.resolve({}) });
	});
}
