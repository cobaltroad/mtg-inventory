export interface InventoryItem {
	id: number;
	card_id: string;
	quantity: number;
	card_name: string;
	set: string;
	set_name: string;
	collector_number: string;
	released_at?: string | null;
	image_url: string;
	acquired_date?: string | null;
	acquired_price_cents?: number | null;
	finish?: string | null;
	language?: string | null;
	unit_price_cents?: number | null;
	total_price_cents?: number | null;
	price_updated_at?: string | null;
	created_at: string;
	updated_at: string;
	user_id: number;
	collection_type: string;
}

// Valid finish types aligned with Scryfall API
export type CardFinish = 'nonfoil' | 'foil' | 'etched';

export const FINISH_OPTIONS: readonly CardFinish[] = ['nonfoil', 'foil', 'etched'] as const;

export type SortOption =
	| 'name-asc'
	| 'name-desc'
	| 'set-asc'
	| 'set-desc'
	| 'release-newest'
	| 'release-oldest'
	| 'value-high'
	| 'value-low'
	| 'date-newest'
	| 'date-oldest';

export interface InventoryStats {
	mostValuableCard: string | null;
	totalValueCents: number;
	cardsOverTenDollars: number;
	totalSets: number;
	mostCollectedSet: string | null;
}
