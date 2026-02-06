import type { InventoryItem, SortOption, InventoryStats } from '$lib/types/inventory';

/**
 * Filters inventory items by set code or set name (case-insensitive)
 */
export function filterBySet(items: InventoryItem[], filter: string): InventoryItem[] {
	if (!filter) return items;

	const lowerFilter = filter.toLowerCase();
	return items.filter(
		(item) =>
			item.set.toLowerCase().includes(lowerFilter) ||
			item.set_name.toLowerCase().includes(lowerFilter)
	);
}

/**
 * Sorts inventory items by the specified sort option
 */
export function sortInventory(items: InventoryItem[], sortOption: SortOption): InventoryItem[] {
	// Create a shallow copy to avoid mutating the original array
	const sorted = [...items];

	switch (sortOption) {
		case 'name-asc':
			return sorted.sort((a, b) => a.card_name.localeCompare(b.card_name));

		case 'name-desc':
			return sorted.sort((a, b) => b.card_name.localeCompare(a.card_name));

		case 'set-asc':
			return sorted.sort((a, b) => {
				const setCompare = a.set_name.localeCompare(b.set_name);
				if (setCompare !== 0) return setCompare;
				return a.card_name.localeCompare(b.card_name);
			});

		case 'set-desc':
			return sorted.sort((a, b) => {
				const setCompare = b.set_name.localeCompare(a.set_name);
				if (setCompare !== 0) return setCompare;
				return a.card_name.localeCompare(b.card_name);
			});

		case 'release-newest':
			return sorted.sort((a, b) => {
				if (!a.released_at && !b.released_at) return 0;
				if (!a.released_at) return 1;
				if (!b.released_at) return -1;
				return b.released_at.localeCompare(a.released_at);
			});

		case 'release-oldest':
			return sorted.sort((a, b) => {
				if (!a.released_at && !b.released_at) return 0;
				if (!a.released_at) return 1;
				if (!b.released_at) return -1;
				return a.released_at.localeCompare(b.released_at);
			});

		case 'quantity-high':
			return sorted.sort((a, b) => b.quantity - a.quantity);

		case 'quantity-low':
			return sorted.sort((a, b) => a.quantity - b.quantity);

		case 'date-newest':
			return sorted.sort((a, b) => b.created_at.localeCompare(a.created_at));

		case 'date-oldest':
			return sorted.sort((a, b) => a.created_at.localeCompare(b.created_at));

		default:
			return sorted;
	}
}

/**
 * Calculates statistics for the inventory
 */
export function calculateStats(items: InventoryItem[]): InventoryStats {
	if (items.length === 0) {
		return {
			totalUniqueCards: 0,
			totalQuantity: 0,
			totalSets: 0,
			mostCollectedSet: null
		};
	}

	const totalUniqueCards = items.length;
	const totalQuantity = items.reduce((sum, item) => sum + item.quantity, 0);

	// Count unique sets
	const uniqueSets = new Set(items.map((item) => item.set));
	const totalSets = uniqueSets.size;

	// Find most collected set by counting cards per set
	const setCardCounts = items.reduce(
		(acc, item) => {
			acc[item.set_name] = (acc[item.set_name] || 0) + 1;
			return acc;
		},
		{} as Record<string, number>
	);

	const mostCollectedSet =
		Object.keys(setCardCounts).length > 0
			? Object.entries(setCardCounts).reduce(
					(max, [setName, count]) => (count > max[1] ? [setName, count] : max),
					['', 0] as [string, number]
				)[0]
			: null;

	return {
		totalUniqueCards,
		totalQuantity,
		totalSets,
		mostCollectedSet
	};
}
