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

		case 'value-high':
			return sorted.sort((a, b) => {
				const aValue = a.total_price_cents ?? 0;
				const bValue = b.total_price_cents ?? 0;
				return bValue - aValue;
			});

		case 'value-low':
			return sorted.sort((a, b) => {
				const aValue = a.total_price_cents ?? 0;
				const bValue = b.total_price_cents ?? 0;
				return aValue - bValue;
			});

		case 'date-newest':
			return sorted.sort((a, b) => b.created_at.localeCompare(a.created_at));

		case 'date-oldest':
			return sorted.sort((a, b) => a.created_at.localeCompare(b.created_at));

		default:
			return sorted;
	}
}

