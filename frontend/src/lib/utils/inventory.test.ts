import { describe, it, expect } from 'vitest';
import { filterBySet, sortInventory, calculateStats } from './inventory';
import type { InventoryItem } from '$lib/types/inventory';

// ---------------------------------------------------------------------------
// Mock Data
// ---------------------------------------------------------------------------
const MOCK_ITEMS: InventoryItem[] = [
	{
		id: 1,
		card_id: 'uuid-1',
		quantity: 3,
		card_name: 'Zombie Token',
		set: 'c15',
		set_name: 'Commander 2015',
		collector_number: '234',
		released_at: '2015-11-13',
		image_url: 'https://example.com/1.jpg',
		created_at: '2025-01-15T10:00:00Z',
		updated_at: '2025-01-15T10:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	},
	{
		id: 2,
		card_id: 'uuid-2',
		quantity: 1,
		card_name: 'Ancient Tomb',
		set: 'uma',
		set_name: 'Ultimate Masters',
		collector_number: '48',
		released_at: '2018-12-07',
		image_url: 'https://example.com/2.jpg',
		created_at: '2025-01-16T10:00:00Z',
		updated_at: '2025-01-16T10:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	},
	{
		id: 3,
		card_id: 'uuid-3',
		quantity: 5,
		card_name: 'Mox Pearl',
		set: 'c15',
		set_name: 'Commander 2015',
		collector_number: '100',
		released_at: '2015-11-13',
		image_url: 'https://example.com/3.jpg',
		created_at: '2025-01-14T10:00:00Z',
		updated_at: '2025-01-14T10:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	},
	{
		id: 4,
		card_id: 'uuid-4',
		quantity: 2,
		card_name: 'Black Lotus',
		set: 'lea',
		set_name: 'Limited Edition Alpha',
		collector_number: '5',
		released_at: '1993-08-05',
		image_url: 'https://example.com/4.jpg',
		created_at: '2025-01-17T10:00:00Z',
		updated_at: '2025-01-17T10:00:00Z',
		user_id: 1,
		collection_type: 'inventory'
	}
];

// ---------------------------------------------------------------------------
// Tests: filterBySet
// ---------------------------------------------------------------------------
describe('filterBySet', () => {
	it('returns all items when filter is empty', () => {
		const result = filterBySet(MOCK_ITEMS, '');
		expect(result).toEqual(MOCK_ITEMS);
	});

	it('filters items by set code', () => {
		const result = filterBySet(MOCK_ITEMS, 'c15');
		expect(result).toHaveLength(2);
		expect(result[0].card_name).toBe('Zombie Token');
		expect(result[1].card_name).toBe('Mox Pearl');
	});

	it('filters items by set name (case-insensitive)', () => {
		const result = filterBySet(MOCK_ITEMS, 'commander 2015');
		expect(result).toHaveLength(2);
		expect(result.every((item) => item.set === 'c15')).toBe(true);
	});

	it('returns empty array when no items match filter', () => {
		const result = filterBySet(MOCK_ITEMS, 'xyz');
		expect(result).toHaveLength(0);
	});

	it('handles set names with special characters', () => {
		const itemsWithSpecialChars: InventoryItem[] = [
			{
				...MOCK_ITEMS[0],
				set: 'sta',
				set_name: 'Strixhaven: School of Mages'
			}
		];
		const result = filterBySet(itemsWithSpecialChars, 'strixhaven: school');
		expect(result).toHaveLength(1);
	});
});

// ---------------------------------------------------------------------------
// Tests: sortInventory - Card Name
// ---------------------------------------------------------------------------
describe('sortInventory - Card Name', () => {
	it('sorts by card name A-Z', () => {
		const result = sortInventory(MOCK_ITEMS, 'name-asc');
		expect(result[0].card_name).toBe('Ancient Tomb');
		expect(result[1].card_name).toBe('Black Lotus');
		expect(result[2].card_name).toBe('Mox Pearl');
		expect(result[3].card_name).toBe('Zombie Token');
	});

	it('sorts by card name Z-A', () => {
		const result = sortInventory(MOCK_ITEMS, 'name-desc');
		expect(result[0].card_name).toBe('Zombie Token');
		expect(result[1].card_name).toBe('Mox Pearl');
		expect(result[2].card_name).toBe('Black Lotus');
		expect(result[3].card_name).toBe('Ancient Tomb');
	});
});

// ---------------------------------------------------------------------------
// Tests: sortInventory - Set Name
// ---------------------------------------------------------------------------
describe('sortInventory - Set Name', () => {
	it('sorts by set name A-Z', () => {
		const result = sortInventory(MOCK_ITEMS, 'set-asc');
		// Commander 2015 (2 cards), Limited Edition Alpha (1 card), Ultimate Masters (1 card)
		expect(result[0].set_name).toBe('Commander 2015');
		expect(result[1].set_name).toBe('Commander 2015');
		expect(result[2].set_name).toBe('Limited Edition Alpha');
		expect(result[3].set_name).toBe('Ultimate Masters');
	});

	it('sorts by set name Z-A', () => {
		const result = sortInventory(MOCK_ITEMS, 'set-desc');
		expect(result[0].set_name).toBe('Ultimate Masters');
		expect(result[1].set_name).toBe('Limited Edition Alpha');
		expect(result[2].set_name).toBe('Commander 2015');
	});

	it('within same set, sorts by card name', () => {
		const result = sortInventory(MOCK_ITEMS, 'set-asc');
		const c15Cards = result.filter((item) => item.set === 'c15');
		expect(c15Cards[0].card_name).toBe('Mox Pearl');
		expect(c15Cards[1].card_name).toBe('Zombie Token');
	});
});

// ---------------------------------------------------------------------------
// Tests: sortInventory - Release Date
// ---------------------------------------------------------------------------
describe('sortInventory - Release Date', () => {
	it('sorts by release date newest first', () => {
		const result = sortInventory(MOCK_ITEMS, 'release-newest');
		expect(result[0].released_at).toBe('2018-12-07'); // Ultimate Masters
		expect(result[1].released_at).toBe('2015-11-13'); // Commander 2015
		expect(result[3].released_at).toBe('1993-08-05'); // Limited Edition Alpha
	});

	it('sorts by release date oldest first', () => {
		const result = sortInventory(MOCK_ITEMS, 'release-oldest');
		expect(result[0].released_at).toBe('1993-08-05'); // Limited Edition Alpha
		expect(result[2].released_at).toBe('2015-11-13'); // Commander 2015
		expect(result[3].released_at).toBe('2018-12-07'); // Ultimate Masters
	});

	it('handles items with missing release dates', () => {
		const itemsWithMissing = [
			...MOCK_ITEMS,
			{
				...MOCK_ITEMS[0],
				id: 5,
				released_at: null
			}
		];
		const result = sortInventory(itemsWithMissing, 'release-newest');
		// Items with null dates should appear at the end
		expect(result[result.length - 1].released_at).toBeNull();
	});
});

// ---------------------------------------------------------------------------
// Tests: sortInventory - Quantity
// ---------------------------------------------------------------------------
describe('sortInventory - Quantity', () => {
	it('sorts by quantity highest to lowest', () => {
		const result = sortInventory(MOCK_ITEMS, 'quantity-high');
		expect(result[0].quantity).toBe(5);
		expect(result[1].quantity).toBe(3);
		expect(result[2].quantity).toBe(2);
		expect(result[3].quantity).toBe(1);
	});

	it('sorts by quantity lowest to highest', () => {
		const result = sortInventory(MOCK_ITEMS, 'quantity-low');
		expect(result[0].quantity).toBe(1);
		expect(result[1].quantity).toBe(2);
		expect(result[2].quantity).toBe(3);
		expect(result[3].quantity).toBe(5);
	});
});

// ---------------------------------------------------------------------------
// Tests: sortInventory - Date Added
// ---------------------------------------------------------------------------
describe('sortInventory - Date Added', () => {
	it('sorts by date added most recent first', () => {
		const result = sortInventory(MOCK_ITEMS, 'date-newest');
		expect(result[0].created_at).toBe('2025-01-17T10:00:00Z');
		expect(result[1].created_at).toBe('2025-01-16T10:00:00Z');
		expect(result[2].created_at).toBe('2025-01-15T10:00:00Z');
		expect(result[3].created_at).toBe('2025-01-14T10:00:00Z');
	});

	it('sorts by date added oldest first', () => {
		const result = sortInventory(MOCK_ITEMS, 'date-oldest');
		expect(result[0].created_at).toBe('2025-01-14T10:00:00Z');
		expect(result[1].created_at).toBe('2025-01-15T10:00:00Z');
		expect(result[2].created_at).toBe('2025-01-16T10:00:00Z');
		expect(result[3].created_at).toBe('2025-01-17T10:00:00Z');
	});
});

// ---------------------------------------------------------------------------
// Tests: calculateStats
// ---------------------------------------------------------------------------
describe('calculateStats', () => {
	it('calculates total unique cards', () => {
		const stats = calculateStats(MOCK_ITEMS);
		expect(stats.totalUniqueCards).toBe(4);
	});

	it('calculates total quantity across all cards', () => {
		const stats = calculateStats(MOCK_ITEMS);
		expect(stats.totalQuantity).toBe(11); // 3 + 1 + 5 + 2
	});

	it('calculates number of different sets', () => {
		const stats = calculateStats(MOCK_ITEMS);
		expect(stats.totalSets).toBe(3); // c15, uma, lea
	});

	it('identifies most collected set by card count', () => {
		const stats = calculateStats(MOCK_ITEMS);
		expect(stats.mostCollectedSet).toBe('Commander 2015');
	});

	it('handles empty inventory', () => {
		const stats = calculateStats([]);
		expect(stats.totalUniqueCards).toBe(0);
		expect(stats.totalQuantity).toBe(0);
		expect(stats.totalSets).toBe(0);
		expect(stats.mostCollectedSet).toBeNull();
	});

	it('updates stats when filtered', () => {
		const filtered = filterBySet(MOCK_ITEMS, 'c15');
		const stats = calculateStats(filtered);
		expect(stats.totalUniqueCards).toBe(2);
		expect(stats.totalQuantity).toBe(8); // 3 + 5
		expect(stats.totalSets).toBe(1);
		expect(stats.mostCollectedSet).toBe('Commander 2015');
	});
});
