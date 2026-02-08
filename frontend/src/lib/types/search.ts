/**
 * Represents a card found in a commander decklist
 */
export interface DecklistCard {
	id: string;
	name: string;
	mana_cost?: string;
	type_line?: string;
	oracle_text?: string;
	image_url?: string;
	commander_id: number;
	commander_name: string;
	deck_url: string;
}

/**
 * Represents a card found in inventory
 */
export interface InventoryCard {
	id: string;
	name: string;
	mana_cost?: string;
	type_line?: string;
	oracle_text?: string;
	image_url?: string;
	quantity: number;
	foil_quantity?: number;
}

/**
 * Complete search results from the API
 */
export interface SearchResults {
	query: string;
	decklist_results: DecklistCard[];
	inventory_results: InventoryCard[];
	total_decklist_count: number;
	total_inventory_count: number;
}

/**
 * Tab options for search results filtering
 */
export type SearchTab = 'all' | 'decklists' | 'inventory';
