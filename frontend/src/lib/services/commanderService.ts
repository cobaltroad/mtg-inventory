import { base } from '$app/paths';

/**
 * Commander data structure returned from the API
 */
export interface Commander {
	id: number;
	name: string;
	rank: number;
	edhrec_url: string;
	last_scraped_at: string;
	card_count: number;
}

/**
 * Card data structure in a decklist
 */
export interface DecklistCard {
	card_id: string;
	card_name: string;
	quantity: number;
}

/**
 * Commander with full decklist
 */
export interface CommanderWithDecklist extends Commander {
	cards: DecklistCard[];
}

/**
 * Fetches all commanders from the API
 * @returns Promise<Commander[]> Array of commanders ordered by rank
 * @throws Error if the API request fails
 */
export async function fetchCommanders(): Promise<Commander[]> {
	const response = await fetch(`${base}/api/commanders`);

	if (!response.ok) {
		throw new Error('Failed to fetch commanders');
	}

	return await response.json();
}

/**
 * Fetches a single commander with full decklist from the API
 * @param id Commander ID
 * @returns Promise<CommanderWithDecklist> Commander with cards array
 * @throws Error if the commander is not found or API request fails
 */
export async function fetchCommander(id: string): Promise<CommanderWithDecklist> {
	const response = await fetch(`${base}/api/commanders/${id}`);

	if (!response.ok) {
		if (response.status === 404) {
			throw new Error('Commander not found');
		}
		throw new Error('Failed to fetch commander');
	}

	return await response.json();
}
