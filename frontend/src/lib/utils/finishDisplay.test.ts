import { describe, it, expect } from 'vitest';
import { shouldShowFinishIndicator, getFinishDisplayName } from './finishDisplay';

describe('shouldShowFinishIndicator', () => {
	describe('special finish types in promo_types', () => {
		it('should return true for halofoil in promo_types', () => {
			expect(shouldShowFinishIndicator('foil', ['halofoil'])).toBe(true);
		});

		it('should return true for rainbowfoil in promo_types', () => {
			expect(shouldShowFinishIndicator('foil', ['rainbowfoil'])).toBe(true);
		});

		it('should return true for surgefoil in promo_types', () => {
			expect(shouldShowFinishIndicator('foil', ['surgefoil'])).toBe(true);
		});

		it('should return true when special finish is in promo_types array with other types', () => {
			expect(shouldShowFinishIndicator('foil', ['prerelease', 'halofoil'])).toBe(true);
		});

		it('should return false when promo_types contains only non-finish promo types', () => {
			expect(shouldShowFinishIndicator('nonfoil', ['prerelease', 'datestamped'])).toBe(false);
		});
	});

	describe('standard finish types', () => {
		it('should return true for foil finish', () => {
			expect(shouldShowFinishIndicator('foil', [])).toBe(true);
		});

		it('should return true for etched finish', () => {
			expect(shouldShowFinishIndicator('etched', [])).toBe(true);
		});

		it('should return false for nonfoil finish', () => {
			expect(shouldShowFinishIndicator('nonfoil', [])).toBe(false);
		});

		it('should return false for null finish', () => {
			expect(shouldShowFinishIndicator(null, [])).toBe(false);
		});

		it('should return false for undefined finish', () => {
			expect(shouldShowFinishIndicator(undefined, [])).toBe(false);
		});
	});

	describe('edge cases', () => {
		it('should return false when both finish and promo_types are empty', () => {
			expect(shouldShowFinishIndicator(null, [])).toBe(false);
		});

		it('should return false when promo_types is undefined', () => {
			expect(shouldShowFinishIndicator('nonfoil', undefined)).toBe(false);
		});

		it('should prioritize promo_types over standard finish', () => {
			expect(shouldShowFinishIndicator('nonfoil', ['halofoil'])).toBe(true);
		});
	});
});

describe('getFinishDisplayName', () => {
	describe('special finish types in promo_types', () => {
		it('should return "Halofoil" for halofoil in promo_types', () => {
			expect(getFinishDisplayName('foil', ['halofoil'])).toBe('Halofoil');
		});

		it('should return "Rainbowfoil" for rainbowfoil in promo_types', () => {
			expect(getFinishDisplayName('foil', ['rainbowfoil'])).toBe('Rainbowfoil');
		});

		it('should return "Surgefoil" for surgefoil in promo_types', () => {
			expect(getFinishDisplayName('foil', ['surgefoil'])).toBe('Surgefoil');
		});

		it('should return first special finish when multiple exist in promo_types', () => {
			expect(getFinishDisplayName('foil', ['halofoil', 'rainbowfoil'])).toBe('Halofoil');
		});

		it('should return special finish from promo_types even with non-finish types', () => {
			expect(getFinishDisplayName('foil', ['prerelease', 'surgefoil'])).toBe('Surgefoil');
		});
	});

	describe('standard finish types', () => {
		it('should return "Foil" for foil finish without promo_types', () => {
			expect(getFinishDisplayName('foil', [])).toBe('Foil');
		});

		it('should return "Etched" for etched finish without promo_types', () => {
			expect(getFinishDisplayName('etched', [])).toBe('Etched');
		});

		it('should return "Nonfoil" for nonfoil finish', () => {
			expect(getFinishDisplayName('nonfoil', [])).toBe('Nonfoil');
		});

		it('should return empty string for null finish', () => {
			expect(getFinishDisplayName(null, [])).toBe('');
		});

		it('should return empty string for undefined finish', () => {
			expect(getFinishDisplayName(undefined, [])).toBe('');
		});
	});

	describe('tooltip text should NOT contain "finish" suffix', () => {
		it('should return "Foil" not "Foil finish"', () => {
			const result = getFinishDisplayName('foil', []);
			expect(result).toBe('Foil');
			expect(result).not.toContain('finish');
		});

		it('should return "Etched" not "Etched finish"', () => {
			const result = getFinishDisplayName('etched', []);
			expect(result).toBe('Etched');
			expect(result).not.toContain('finish');
		});

		it('should return "Halofoil" without any suffix', () => {
			const result = getFinishDisplayName('foil', ['halofoil']);
			expect(result).toBe('Halofoil');
			expect(result).not.toContain('finish');
		});
	});

	describe('edge cases', () => {
		it('should return empty string when both finish and promo_types are empty', () => {
			expect(getFinishDisplayName(null, [])).toBe('');
		});

		it('should return empty string when promo_types is undefined and finish is null', () => {
			expect(getFinishDisplayName(null, undefined)).toBe('');
		});

		it('should prioritize promo_types over standard finish', () => {
			expect(getFinishDisplayName('foil', ['rainbowfoil'])).toBe('Rainbowfoil');
		});
	});
});
