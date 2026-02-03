import { describe, it, expect } from 'vitest';
import { formatPrice, formatDate, pluralize } from './format';

describe('formatPrice', () => {
	it('should format price in cents to USD string', () => {
		expect(formatPrice(1000)).toBe('$10.00');
		expect(formatPrice(500)).toBe('$5.00');
		expect(formatPrice(99)).toBe('$0.99');
	});

	it('should return N/A for null or undefined', () => {
		expect(formatPrice(null)).toBe('N/A');
		expect(formatPrice(undefined)).toBe('N/A');
	});

	it('should handle zero correctly', () => {
		expect(formatPrice(0)).toBe('$0.00');
	});
});

describe('formatDate', () => {
	it('should format ISO date string', () => {
		const result = formatDate('2024-01-15');
		expect(result).toBeTruthy();
		expect(typeof result).toBe('string');
	});

	it('should return empty string for null or undefined', () => {
		expect(formatDate(null)).toBe('');
		expect(formatDate(undefined)).toBe('');
	});

	it('should handle invalid date strings gracefully', () => {
		const invalidDate = 'not-a-date';
		expect(formatDate(invalidDate)).toBe(invalidDate);
	});
});

describe('pluralize', () => {
	it('should return singular for count of 1', () => {
		expect(pluralize(1, 'card')).toBe('card');
		expect(pluralize(1, 'item')).toBe('item');
	});

	it('should return plural for count other than 1', () => {
		expect(pluralize(0, 'card')).toBe('cards');
		expect(pluralize(2, 'card')).toBe('cards');
		expect(pluralize(100, 'card')).toBe('cards');
	});

	it('should use custom plural form when provided', () => {
		expect(pluralize(2, 'person', 'people')).toBe('people');
		expect(pluralize(1, 'person', 'people')).toBe('person');
	});
});
