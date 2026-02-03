/**
 * Represents a Magic: The Gathering card from search results
 */
export interface Card {
	id: string;
	name: string;
	mana_cost?: string;
	type_line?: string;
	oracle_text?: string;
	power?: string;
	toughness?: string;
	colors?: string[];
	color_identity?: string[];
	set?: string;
	set_name?: string;
	collector_number?: string;
	rarity?: string;
	image_url?: string;
}

/**
 * Search result response from the API
 */
export interface CardSearchResult {
	cards: Card[];
	total?: number;
	hasMore?: boolean;
}
