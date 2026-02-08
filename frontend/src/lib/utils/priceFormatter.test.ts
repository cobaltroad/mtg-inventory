import { describe, it, expect } from 'vitest';
import { formatPrice } from './priceFormatter';

/**
 * Tests for price formatting utility
 */
describe('formatPrice', () => {
	it('should format price with dollars and cents', () => {
		expect(formatPrice(500)).toBe('$5.00');
		expect(formatPrice(1000)).toBe('$10.00');
		expect(formatPrice(12345)).toBe('$123.45');
	});

	it('should handle zero price', () => {
		expect(formatPrice(0)).toBe('$0.00');
	});

	it('should format prices less than a dollar', () => {
		expect(formatPrice(50)).toBe('$0.50');
		expect(formatPrice(99)).toBe('$0.99');
		expect(formatPrice(1)).toBe('$0.01');
	});

	it('should always show two decimal places', () => {
		expect(formatPrice(100)).toBe('$1.00');
		expect(formatPrice(1050)).toBe('$10.50');
	});

	it('should return placeholder for undefined', () => {
		expect(formatPrice(undefined)).toBe('—');
	});

	it('should return placeholder for null', () => {
		expect(formatPrice(null as any)).toBe('—');
	});

	it('should handle large amounts', () => {
		expect(formatPrice(1000000)).toBe('$10000.00');
		expect(formatPrice(999999)).toBe('$9999.99');
	});
});
