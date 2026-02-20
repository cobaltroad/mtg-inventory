/**
 * Utility functions for displaying card finish types (foil, halofoil, etc.)
 */

// Special finish types that appear in promo_types array
const SPECIAL_FINISH_TYPES = ['halofoil', 'rainbowfoil', 'surgefoil'] as const;

export type SpecialFinishType = (typeof SPECIAL_FINISH_TYPES)[number];

/**
 * Determines if a card should show a finish indicator (star icon)
 *
 * @param finish - The standard finish type (foil, etched, nonfoil, etc.)
 * @param promoTypes - Array of promo types from Scryfall API
 * @returns true if the card has a special finish that should display an indicator
 */
export function shouldShowFinishIndicator(finish?: string | null, promoTypes?: string[]): boolean {
	// Check promo_types first for special finish types
	if (promoTypes && promoTypes.length > 0) {
		const hasSpecialFinish = promoTypes.some((type) =>
			SPECIAL_FINISH_TYPES.includes(type as SpecialFinishType)
		);
		if (hasSpecialFinish) {
			return true;
		}
	}

	// Fall back to standard finish field for foil/etched
	return finish === 'foil' || finish === 'etched';
}

/**
 * Gets the display name for a card's finish type
 *
 * @param finish - The standard finish type (foil, etched, nonfoil, etc.)
 * @param promoTypes - Array of promo types from Scryfall API
 * @returns Capitalized finish type name (e.g., "Halofoil", "Foil", "Etched")
 */
export function getFinishDisplayName(finish?: string | null, promoTypes?: string[]): string {
	// Check promo_types first for specific finish types
	if (promoTypes && promoTypes.length > 0) {
		const specialFinish = promoTypes.find((type) =>
			SPECIAL_FINISH_TYPES.includes(type as SpecialFinishType)
		);
		if (specialFinish) {
			return capitalizeFirstLetter(specialFinish);
		}
	}

	// Fall back to standard finish field (without "finish" suffix)
	if (finish) {
		return capitalizeFirstLetter(finish);
	}

	return '';
}

/**
 * Capitalizes the first letter of a string
 *
 * @param text - The text to capitalize
 * @returns Text with first letter capitalized
 */
export function capitalizeFirstLetter(text: string): string {
	return text.charAt(0).toUpperCase() + text.slice(1);
}
