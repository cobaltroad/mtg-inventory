import { describe, it, expect, afterEach } from 'vitest';
import { render, cleanup } from '@testing-library/svelte';
import InventoryTable from './InventoryTable.svelte';
import type { InventoryItem } from '$lib/types/inventory';

afterEach(() => {
	cleanup();
});

const mockItems: InventoryItem[] = [
	{
		id: 1,
		card_id: 'card-123',
		quantity: 2,
		card_name: 'Lightning Bolt',
		set: 'lea',
		set_name: 'Limited Edition Alpha',
		collector_number: '161',
		image_url: 'https://example.com/card1.jpg',
		acquired_date: '2024-01-15',
		acquired_price_cents: 1000,
		treatment: 'foil',
		language: 'English',
		created_at: '2024-01-15T10:00:00Z',
		updated_at: '2024-01-15T10:00:00Z',
		user_id: 1,
		collection_type: 'collection'
	},
	{
		id: 2,
		card_id: 'card-456',
		quantity: 1,
		card_name: 'Black Lotus',
		set: 'lea',
		set_name: 'Limited Edition Alpha',
		collector_number: '232',
		image_url: 'https://example.com/card2.jpg',
		acquired_date: null,
		acquired_price_cents: null,
		treatment: null,
		language: null,
		created_at: '2024-01-16T10:00:00Z',
		updated_at: '2024-01-16T10:00:00Z',
		user_id: 1,
		collection_type: 'collection'
	}
];

describe('InventoryTable Component - Table Structure', () => {
	it('should render a table element', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });
		const table = container.querySelector('table');
		expect(table).toBeInTheDocument();
	});

	it('should render table headers', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });
		const headers = container.querySelectorAll('th');

		expect(headers.length).toBeGreaterThan(0);

		const headerTexts = Array.from(headers).map((h) => h.textContent?.toLowerCase().trim());
		expect(headerTexts).toContain('card name');
		expect(headerTexts).toContain('value');
		expect(headerTexts).toContain('quantity');
	});

	it('should render table rows for each item', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });
		const rows = container.querySelectorAll('tbody tr');

		expect(rows.length).toBe(mockItems.length);
	});
});

describe('InventoryTable Component - Data Display', () => {
	it('should display card names correctly', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });

		mockItems.forEach((item) => {
			expect(container.textContent).toContain(item.card_name);
		});
	});

	it('should display set code correctly', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });

		mockItems.forEach((item) => {
			expect(container.textContent).toContain(item.set.toUpperCase());
		});
	});

	it('should display quantity correctly', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });

		mockItems.forEach((item) => {
			expect(container.textContent).toContain(item.quantity.toString());
		});
	});

	it('should format price correctly', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });

		// $10.00 for 1000 cents
		expect(container.textContent).toContain('$10.00');
	});

	it('should handle null values gracefully', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });

		// Should render without errors even with null values
		expect(container).toBeInTheDocument();
	});
});

describe('InventoryTable Component - Empty State', () => {
	it('should render empty state when no items provided', () => {
		const { container } = render(InventoryTable, { props: { items: [] } });

		const emptyMessage = container.querySelector('[data-testid="empty-state"]');
		expect(emptyMessage).toBeInTheDocument();
	});

	it('should display empty state message', () => {
		const { container } = render(InventoryTable, { props: { items: [] } });

		expect(container.textContent).toContain('No items');
	});
});

describe('InventoryTable Component - Loading State', () => {
	it('should render loading state when loading prop is true', () => {
		const { container } = render(InventoryTable, {
			props: { items: [], loading: true }
		});

		const loadingIndicator = container.querySelector('[data-testid="loading-state"]');
		expect(loadingIndicator).toBeInTheDocument();
	});

	it('should display loading message', () => {
		const { container } = render(InventoryTable, {
			props: { items: [], loading: true }
		});

		expect(container.textContent?.toLowerCase()).toContain('loading');
	});

	it('should not show table when loading', () => {
		const { container } = render(InventoryTable, {
			props: { items: mockItems, loading: true }
		});

		const table = container.querySelector('table');
		// Table might be hidden or not rendered
		if (table) {
			expect(table).not.toBeVisible();
		}
	});
});

describe('InventoryTable Component - Responsive Design', () => {
	it('should have responsive table classes', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });
		const table = container.querySelector('table');

		// Should have classes for responsive behavior
		expect(table?.className).toBeTruthy();
	});

	it('should render card images with proper attributes', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });
		const images = container.querySelectorAll('img');

		images.forEach((img) => {
			expect(img).toHaveAttribute('src');
			expect(img).toHaveAttribute('alt');
		});
	});
});

describe('InventoryTable Component - Price Display', () => {
	it('should display unit price for single card', () => {
		const itemsWithPrice: InventoryItem[] = [
			{
				...mockItems[0],
				quantity: 1,
				unit_price_cents: 250,
				total_price_cents: 250
			}
		];

		const { container } = render(InventoryTable, { props: { items: itemsWithPrice } });
		expect(container.textContent).toContain('$2.50');
	});

	it('should display unit and total price for multiple copies', () => {
		const itemsWithPrice: InventoryItem[] = [
			{
				...mockItems[0],
				quantity: 4,
				unit_price_cents: 250,
				total_price_cents: 1000
			}
		];

		const { container } = render(InventoryTable, { props: { items: itemsWithPrice } });
		expect(container.textContent).toContain('Unit: $2.50');
		expect(container.textContent).toContain('Total: $10.00');
	});

	it('should display "Price N/A" when no price data exists', () => {
		const itemsWithoutPrice: InventoryItem[] = [
			{
				...mockItems[0],
				unit_price_cents: null,
				total_price_cents: null,
				price_updated_at: null
			}
		];

		const { container } = render(InventoryTable, { props: { items: itemsWithoutPrice } });
		expect(container.textContent).toContain('Price N/A');
	});

	it('should handle undefined prices', () => {
		const itemsWithUndefinedPrice: InventoryItem[] = [
			{
				...mockItems[0],
				unit_price_cents: undefined,
				total_price_cents: undefined,
				price_updated_at: undefined
			}
		];

		const { container } = render(InventoryTable, { props: { items: itemsWithUndefinedPrice } });
		expect(container.textContent).toContain('Price N/A');
	});

	it('should display zero prices correctly', () => {
		const itemsWithZeroPrice: InventoryItem[] = [
			{
				...mockItems[0],
				quantity: 1,
				unit_price_cents: 0,
				total_price_cents: 0
			}
		];

		const { container } = render(InventoryTable, { props: { items: itemsWithZeroPrice } });
		expect(container.textContent).toContain('$0.00');
	});

	it('should show both prices for high quantities', () => {
		const itemsWithMultiple: InventoryItem[] = [
			{
				...mockItems[0],
				quantity: 10,
				unit_price_cents: 150,
				total_price_cents: 1500
			}
		];

		const { container } = render(InventoryTable, { props: { items: itemsWithMultiple } });
		expect(container.textContent).toContain('Unit: $1.50');
		expect(container.textContent).toContain('Total: $15.00');
	});
});

describe('InventoryTable Component - Styling', () => {
	it('should render table with proper structure', () => {
		const { container } = render(InventoryTable, { props: { items: mockItems } });
		const table = container.querySelector('table');

		expect(table).toBeInTheDocument();
	});
});
