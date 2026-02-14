/**
 * Decklist card sorting utilities for commander decklists
 * Enforces the commander-first invariant: commanders always appear first regardless of sort option
 */

export interface DecklistCard {
	card_id: string;
	card_name: string;
	card_url?: string;
	quantity: number;
	is_commander?: boolean;
	card_type?: string;
	rarity?: string;
	edh_rank?: number;
	release_date?: string;
	usd_price?: string;
}

export type SortOption = 'alphabetical' | 'value' | 'edh-rank' | 'type';

/**
 * Sorts decklist cards according to the specified option
 * INVARIANT: Commander cards always appear first, regardless of sort option
 *
 * @param cards - Array of decklist cards to sort
 * @param sortBy - Sort option to apply
 * @returns Sorted array with commanders first
 */
export function sortDecklistCards(
	cards: DecklistCard[],
	sortBy: SortOption
): DecklistCard[] {
	// Separate commanders from non-commanders
	const commanders = cards.filter((card) => card.is_commander);
	const nonCommanders = cards.filter((card) => !card.is_commander);

	// Sort commanders alphabetically (for partner commanders)
	const sortedCommanders = [...commanders].sort((a, b) =>
		a.card_name.localeCompare(b.card_name)
	);

	// Sort non-commanders based on option
	let sortedNonCommanders: DecklistCard[];

	switch (sortBy) {
		case 'alphabetical':
			sortedNonCommanders = sortAlphabetically(nonCommanders);
			break;
		case 'value':
			sortedNonCommanders = sortByValue(nonCommanders);
			break;
		case 'edh-rank':
			sortedNonCommanders = sortByEdhRank(nonCommanders);
			break;
		case 'type':
			sortedNonCommanders = sortByType(nonCommanders);
			break;
		default:
			sortedNonCommanders = sortAlphabetically(nonCommanders);
	}

	// Commanders first, then sorted non-commanders
	return [...sortedCommanders, ...sortedNonCommanders];
}

/**
 * Sorts cards alphabetically by name
 */
function sortAlphabetically(cards: DecklistCard[]): DecklistCard[] {
	return [...cards].sort((a, b) => a.card_name.localeCompare(b.card_name));
}

/**
 * Sorts cards by USD price (descending - highest first)
 * Cards with no price are placed at the end
 */
function sortByValue(cards: DecklistCard[]): DecklistCard[] {
	return [...cards].sort((a, b) => {
		const priceA = a.usd_price ? parseFloat(a.usd_price) : -1;
		const priceB = b.usd_price ? parseFloat(b.usd_price) : -1;

		// Cards without prices go to the end
		if (priceA === -1 && priceB === -1) return a.card_name.localeCompare(b.card_name);
		if (priceA === -1) return 1;
		if (priceB === -1) return -1;

		// Sort by price descending (highest first)
		if (priceB !== priceA) return priceB - priceA;

		// Tie-breaker: alphabetical
		return a.card_name.localeCompare(b.card_name);
	});
}

/**
 * Sorts cards by EDH rank (ascending - most popular first)
 * Cards with no rank are placed at the end
 */
function sortByEdhRank(cards: DecklistCard[]): DecklistCard[] {
	return [...cards].sort((a, b) => {
		const rankA = a.edh_rank ?? Infinity;
		const rankB = b.edh_rank ?? Infinity;

		// Sort by rank ascending (lower rank = more popular)
		if (rankA !== rankB) return rankA - rankB;

		// Tie-breaker: alphabetical
		return a.card_name.localeCompare(b.card_name);
	});
}

/**
 * Sorts cards grouped by card type
 * Within each type group, cards are sorted alphabetically
 * Cards with no type are placed at the end
 */
function sortByType(cards: DecklistCard[]): DecklistCard[] {
	return [...cards].sort((a, b) => {
		const typeA = a.card_type || '';
		const typeB = b.card_type || '';

		// Cards without types go to the end
		if (!typeA && !typeB) return a.card_name.localeCompare(b.card_name);
		if (!typeA) return 1;
		if (!typeB) return -1;

		// Group by type
		if (typeA !== typeB) return typeA.localeCompare(typeB);

		// Within same type, sort alphabetically
		return a.card_name.localeCompare(b.card_name);
	});
}

