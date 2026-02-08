/**
 * Formats a price in cents to a dollar string with 2 decimal places
 * @param cents - The price in cents
 * @returns Formatted price string with $ symbol, or "—" if undefined/null
 */
export function formatPrice(cents?: number): string {
	if (cents === undefined || cents === null) {
		return '—';
	}
	return `$${(cents / 100).toFixed(2)}`;
}
