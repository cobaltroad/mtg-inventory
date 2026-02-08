/**
 * Represents a card match within a decklist result
 */
export interface CardMatch {
	card_name: string;
	quantity: number;
}

/**
 * Represents a commander decklist result from search
 */
export interface DecklistResult {
	commander_id: number;
	commander_name: string;
	commander_rank: number;
	card_matches: CardMatch[];
	match_count: number;
}

/**
 * Represents a card found in inventory
 */
export interface InventoryResult {
	id: number;
	card_id: string;
	card_name: string;
	set: string;
	set_name: string;
	collector_number: string;
	quantity: number;
	image_url?: string;
	treatment?: string;
	unit_price_cents?: number;
	total_price_cents?: number;
}

/**
 * Complete search results from the API
 */
export interface SearchResults {
	query: string;
	total_results: number;
	results: {
		decklists: DecklistResult[];
		inventory: InventoryResult[];
	};
}

/**
 * Tab options for search results filtering
 */
export type SearchTab = 'all' | 'decklists' | 'inventory';
