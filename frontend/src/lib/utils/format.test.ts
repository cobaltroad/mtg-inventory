import { describe, it, expect } from 'vitest';
import { formatPrice, formatDate, pluralize, formatCurrency, formatRelativeTime } from './format';

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

describe('formatRelativeTime', () => {
	it('should return empty string for null or undefined', () => {
		expect(formatRelativeTime(null)).toBe('');
		expect(formatRelativeTime(undefined)).toBe('');
	});

	it('should return "just now" for very recent times', () => {
		const now = new Date();
		const nowIso = now.toISOString();
		expect(formatRelativeTime(nowIso)).toBe('just now');
	});

	it('should format minutes ago', () => {
		const date = new Date();
		date.setMinutes(date.getMinutes() - 5);
		const result = formatRelativeTime(date.toISOString());
		expect(result).toBe('5 minutes ago');
	});

	it('should format hours ago', () => {
		const date = new Date();
		date.setHours(date.getHours() - 3);
		const result = formatRelativeTime(date.toISOString());
		expect(result).toBe('3 hours ago');
	});

	it('should format days ago', () => {
		const date = new Date();
		date.setDate(date.getDate() - 2);
		const result = formatRelativeTime(date.toISOString());
		expect(result).toBe('2 days ago');
	});

	it('should handle singular units correctly', () => {
		const date1 = new Date();
		date1.setMinutes(date1.getMinutes() - 1);
		expect(formatRelativeTime(date1.toISOString())).toBe('1 minute ago');

		const date2 = new Date();
		date2.setHours(date2.getHours() - 1);
		expect(formatRelativeTime(date2.toISOString())).toBe('1 hour ago');

		const date3 = new Date();
		date3.setDate(date3.getDate() - 1);
		expect(formatRelativeTime(date3.toISOString())).toBe('1 day ago');
	});

	it('should handle invalid date strings gracefully', () => {
		const invalidDate = 'not-a-date';
		expect(formatRelativeTime(invalidDate)).toBe(invalidDate);
	});
});
