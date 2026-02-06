import { describe, it, expect } from 'vitest';
import { formatPrice, formatDate, pluralize, formatCurrency } from './format';

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

describe('formatCurrency', () => {
	it('should return "Price N/A" when unit price is null', () => {
		expect(formatCurrency(null, null, 1)).toBe('Price N/A');
		expect(formatCurrency(undefined, undefined, 1)).toBe('Price N/A');
	});

	it('should return unit price for quantity of 1', () => {
		expect(formatCurrency(250, 250, 1)).toBe('$2.50');
		expect(formatCurrency(1000, 1000, 1)).toBe('$10.00');
	});

	it('should show unit and total price for multiple copies', () => {
		expect(formatCurrency(250, 750, 3)).toBe('Unit: $2.50 | Total: $7.50');
		expect(formatCurrency(125, 625, 5)).toBe('Unit: $1.25 | Total: $6.25');
	});

	it('should handle quantity > 1 but total price is null', () => {
		expect(formatCurrency(250, null, 3)).toBe('$2.50');
		expect(formatCurrency(250, undefined, 3)).toBe('$2.50');
	});

	it('should format zero prices correctly', () => {
		expect(formatCurrency(0, 0, 1)).toBe('$0.00');
		expect(formatCurrency(0, 0, 5)).toBe('Unit: $0.00 | Total: $0.00');
	});

	it('should handle large quantities', () => {
		expect(formatCurrency(100, 10000, 100)).toBe('Unit: $1.00 | Total: $100.00');
	});
});
