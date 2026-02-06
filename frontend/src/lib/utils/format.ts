/**
 * Formats a price in cents to a USD currency string
 * @param cents - Price in cents (e.g., 1000 = $10.00)
 * @returns Formatted price string (e.g., "$10.00") or "N/A" if null/undefined
 */
export function formatPrice(cents: number | null | undefined): string {
	if (cents === null || cents === undefined) return 'N/A';
	return `$${(cents / 100).toFixed(2)}`;
}

/**
 * Formats a date string to a localized date
 * @param dateString - ISO date string
 * @param locale - Locale for formatting (default: 'en-US')
 * @returns Formatted date string or original if invalid
 */
export function formatDate(dateString: string | null | undefined, locale = 'en-US'): string {
	if (!dateString) return '';

	try {
		const date = new Date(dateString);
		// Check if date is invalid
		if (isNaN(date.getTime())) {
			return dateString;
		}
		return date.toLocaleDateString(locale);
	} catch {
		return dateString;
	}
}

/**
 * Pluralizes a word based on count
 * @param count - Number to check
 * @param singular - Singular form of word
 * @param plural - Plural form of word (defaults to singular + 's')
 * @returns Appropriately pluralized word
 */
export function pluralize(count: number, singular: string, plural?: string): string {
	if (count === 1) return singular;
	return plural || `${singular}s`;
}

/**
 * Formats currency value for display in inventory
 * @param unitPrice - Unit price in cents
 * @param totalPrice - Total price in cents (for multiple copies)
 * @param quantity - Number of copies
 * @returns Formatted currency string or "Price N/A"
 */
export function formatCurrency(
	unitPrice: number | null | undefined,
	totalPrice: number | null | undefined,
	quantity: number
): string {
	if (unitPrice === null || unitPrice === undefined) {
		return 'Price N/A';
	}

	const unitPriceStr = formatPrice(unitPrice);

	if (quantity > 1 && totalPrice !== null && totalPrice !== undefined) {
		const totalPriceStr = formatPrice(totalPrice);
		return `Unit: ${unitPriceStr} | Total: ${totalPriceStr}`;
	}

	return unitPriceStr;
}
