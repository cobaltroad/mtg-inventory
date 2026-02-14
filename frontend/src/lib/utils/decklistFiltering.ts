/**
 * Decklist card filtering utilities for commander decklists
 * Enforces the commander-always-visible invariant: commanders are always visible regardless of filters
 */

export interface DecklistCard {
	card_id: string;
	card_name: string;
	quantity: number;
	is_commander?: boolean;
	card_type?: string;
	rarity?: string;
	edh_rank?: number;
	release_date?: string;
	usd_price?: string;
}

export interface FilterOptions {
	/** Array of card types to include (e.g., ["Artifact", "Creature"]) */
	cardTypes?: string[];
	/** Array of rarities to include (e.g., ["rare", "mythic"]) */
	rarities?: string[];
	/** Hide basic lands (Plains, Island, Swamp, Mountain, Forest) */
	hideBasicLands?: boolean;
	/** Minimum USD price (inclusive) */
	minPrice?: number;
	/** Maximum USD price (inclusive) */
	maxPrice?: number;
}

/**
 * Filters decklist cards according to the specified options
 * INVARIANT: Commander cards are always visible, regardless of filters
 *
 * @param cards - Array of decklist cards to filter
 * @param options - Filter options to apply
 * @returns Filtered array with commanders always included
 */
export function filterDecklistCards(
	cards: DecklistCard[],
	options: FilterOptions
): DecklistCard[] {
	// If no filters are applied, return all cards
	if (Object.keys(options).length === 0) {
		return cards;
	}

	return cards.filter((card) => {
		// INVARIANT: Commanders are always visible
		if (card.is_commander) {
			return true;
		}

		// Apply filters (AND logic - all must pass)
		return (
			passesCardTypeFilter(card, options.cardTypes) &&
			passesRarityFilter(card, options.rarities) &&
			passesBasicLandFilter(card, options.hideBasicLands) &&
			passesPriceRangeFilter(card, options.minPrice, options.maxPrice)
		);
	});
}

/**
 * Checks if card passes the card type filter
 * If no filter is specified, all cards pass
 * Uses partial matching (e.g., "Creature" matches "Legendary Creature")
 */
function passesCardTypeFilter(card: DecklistCard, cardTypes?: string[]): boolean {
	if (!cardTypes || cardTypes.length === 0) {
		return true;
	}

	if (!card.card_type) {
		return false;
	}

	// Check if card type contains any of the filter types (partial matching)
	return cardTypes.some((filterType) =>
		card.card_type!.toLowerCase().includes(filterType.toLowerCase())
	);
}

/**
 * Checks if card passes the rarity filter
 * If no filter is specified, all cards pass
 */
function passesRarityFilter(card: DecklistCard, rarities?: string[]): boolean {
	if (!rarities || rarities.length === 0) {
		return true;
	}

	if (!card.rarity) {
		return false;
	}

	return rarities.includes(card.rarity.toLowerCase());
}

/**
 * Checks if card passes the basic land filter
 * Basic lands are identified by "Basic Land" in their type line
 */
function passesBasicLandFilter(card: DecklistCard, hideBasicLands?: boolean): boolean {
	if (!hideBasicLands) {
		return true;
	}

	if (!card.card_type) {
		return true;
	}

	// Check if the type line contains "Basic Land"
	return !card.card_type.toLowerCase().includes('basic land');
}

/**
 * Checks if card passes the price range filter
 * If no price filter is specified, all cards pass
 * Cards without a price are excluded when a price filter is active
 */
function passesPriceRangeFilter(
	card: DecklistCard,
	minPrice?: number,
	maxPrice?: number
): boolean {
	// If no price filter is set, pass all cards
	if (minPrice === undefined && maxPrice === undefined) {
		return true;
	}

	// Parse the card's price
	const price = card.usd_price ? parseFloat(card.usd_price) : null;

	// Exclude cards with invalid or missing prices when price filter is active
	if (price === null || isNaN(price)) {
		return false;
	}

	// Check minimum price
	if (minPrice !== undefined && price < minPrice) {
		return false;
	}

	// Check maximum price
	if (maxPrice !== undefined && price > maxPrice) {
		return false;
	}

	return true;
}

/**
 * Gets a list of unique card types from a decklist
 * Useful for populating filter dropdowns
 */
export function getUniqueCardTypes(cards: DecklistCard[]): string[] {
	const types = new Set<string>();

	cards.forEach((card) => {
		if (!card.card_type) return;

		// Extract primary type from type line (e.g., "Creature" from "Legendary Creature — Human")
		const primaryType = extractPrimaryType(card.card_type);
		if (primaryType) {
			types.add(primaryType);
		}
	});

	return Array.from(types).sort();
}

/**
 * Extracts the primary card type from a type line
 * E.g., "Legendary Creature — Human" -> "Creature"
 *       "Artifact" -> "Artifact"
 */
function extractPrimaryType(typeLine: string): string | null {
	// Common primary types
	const primaryTypes = [
		'Creature',
		'Artifact',
		'Enchantment',
		'Instant',
		'Sorcery',
		'Planeswalker',
		'Land',
		'Battle'
	];

	for (const type of primaryTypes) {
		if (typeLine.includes(type)) {
			return type;
		}
	}

	return null;
}

/**
 * Gets a list of unique rarities from a decklist
 * Useful for populating filter dropdowns
 */
export function getUniqueRarities(cards: DecklistCard[]): string[] {
	const rarities = new Set<string>();

	cards.forEach((card) => {
		if (card.rarity) {
			rarities.add(card.rarity);
		}
	});

	return Array.from(rarities).sort();
}
