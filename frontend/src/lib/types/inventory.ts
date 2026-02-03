export interface InventoryItem {
	id: number;
	card_id: string;
	quantity: number;
	card_name: string;
	set: string;
	set_name: string;
	collector_number: string;
	image_url: string;
	acquired_date?: string | null;
	acquired_price_cents?: number | null;
	treatment?: string | null;
	language?: string | null;
	created_at: string;
	updated_at: string;
	user_id: number;
	collection_type: string;
}
