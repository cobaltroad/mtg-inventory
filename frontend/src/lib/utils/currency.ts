/**
 * Formats a price in cents as a US dollar currency string.
 * Uses thousand separators and two decimal places.
 *
 * @param cents - The price in cents
 * @returns Formatted currency string (e.g., "$1,234.56")
 *
 * @example
 * formatCurrency(12345) // Returns "$123.45"
 * formatCurrency(1234567) // Returns "$12,345.67"
 */
export function formatCurrency(cents: number): string {
	const dollars = cents / 100;
	return new Intl.NumberFormat('en-US', {
		style: 'currency',
		currency: 'USD'
	}).format(dollars);
}
