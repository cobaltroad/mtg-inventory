import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { render, screen, cleanup, waitFor } from '@testing-library/svelte';
import InventoryItem from './InventoryItem.svelte';
import type { InventoryItem as InventoryItemType } from '$lib/types/inventory';

// ---------------------------------------------------------------------------
// Mock Data
// ---------------------------------------------------------------------------
const MOCK_ITEM_FULL: InventoryItemType = {
	id: 1,
	card_id: 'uuid-123',
	quantity: 3,
	card_name: 'Black Lotus',
	set: 'lea',
	set_name: 'Limited Edition Alpha',
	collector_number: '234',
	image_url: 'https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg',
	acquired_date: '2025-01-15',
	acquired_price_cents: 5000,
	treatment: 'Foil',
	language: 'Japanese',
	created_at: '2025-01-15T10:00:00Z',
	updated_at: '2025-01-15T10:00:00Z',
	user_id: 1,
	collection_type: 'inventory'
};

const MOCK_ITEM_MINIMAL: InventoryItemType = {
	id: 2,
	card_id: 'uuid-456',
	quantity: 1,
	card_name: 'Lightning Bolt',
	set: 'm21',
	set_name: 'Core Set 2021',
	collector_number: '125',
	image_url: 'https://cards.scryfall.io/normal/front/l/b/lightning-bolt.jpg',
	acquired_date: null,
	acquired_price_cents: null,
	treatment: null,
	language: null,
	created_at: '2025-01-16T10:00:00Z',
	updated_at: '2025-01-16T10:00:00Z',
	user_id: 1,
	collection_type: 'inventory'
};

beforeEach(() => {
	// Reset any state between tests
});

afterEach(() => {
	cleanup();
});

// ---------------------------------------------------------------------------
// Tests: Basic Rendering
// ---------------------------------------------------------------------------
describe('InventoryItem - Basic Rendering', () => {
	it('renders card name', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('Black Lotus')).toBeInTheDocument();
	});

	it('renders set information', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('Limited Edition Alpha (LEA)')).toBeInTheDocument();
	});

	it('renders collector number', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('#234')).toBeInTheDocument();
	});

	it('renders quantity', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('3')).toBeInTheDocument();
		expect(screen.getByText(/Quantity:/)).toBeInTheDocument();
	});

	it('displays uppercase set code', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		const setText = screen.getByText('Limited Edition Alpha (LEA)');
		expect(setText.textContent).toContain('LEA');
	});
});

// ---------------------------------------------------------------------------
// Tests: Image Handling
// ---------------------------------------------------------------------------
describe('InventoryItem - Image Handling', () => {
	it('renders card image with correct src', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		const img = screen.getByAltText('Black Lotus') as HTMLImageElement;
		expect(img).toBeInTheDocument();
		expect(img.src).toBe('https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg');
	});

	it('has loading="lazy" attribute for images', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		const img = screen.getByAltText('Black Lotus') as HTMLImageElement;
		expect(img).toHaveAttribute('loading', 'lazy');
	});

	it('displays loading placeholder initially', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('Loading...')).toBeInTheDocument();
	});

	it('hides image until loaded', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		const img = screen.getByAltText('Black Lotus') as HTMLImageElement;
		expect(img.style.display).toBe('none');
	});

	it('displays error message when image fails to load', async () => {
		const { component } = render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		const img = screen.getByAltText('Black Lotus') as HTMLImageElement;

		// Simulate image error
		img.dispatchEvent(new Event('error'));

		await waitFor(() => {
			expect(screen.getByText('Image unavailable')).toBeInTheDocument();
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Enhanced Tracking Fields
// ---------------------------------------------------------------------------
describe('InventoryItem - Enhanced Tracking Fields', () => {
	it('displays treatment when present', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('Foil')).toBeInTheDocument();
	});

	it('displays language when present', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('Japanese')).toBeInTheDocument();
	});

	it('displays acquired date when present', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('Acquired: 2025-01-15')).toBeInTheDocument();
	});

	it('displays acquired price formatted as currency', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(screen.getByText('Price: $50.00')).toBeInTheDocument();
	});

	it('does not display treatment when null', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_MINIMAL } });
		expect(screen.queryByText('Foil')).not.toBeInTheDocument();
	});

	it('does not display language when null', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_MINIMAL } });
		expect(screen.queryByText('Japanese')).not.toBeInTheDocument();
	});

	it('does not display acquired date when null', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_MINIMAL } });
		expect(screen.queryByText(/Acquired:/)).not.toBeInTheDocument();
	});

	it('does not display price when null', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_MINIMAL } });
		expect(screen.queryByText(/Price:/)).not.toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Price Formatting
// ---------------------------------------------------------------------------
describe('InventoryItem - Price Formatting', () => {
	it('formats price with two decimal places', () => {
		const item = { ...MOCK_ITEM_FULL, acquired_price_cents: 1234 };
		render(InventoryItem, { props: { item } });
		expect(screen.getByText('Price: $12.34')).toBeInTheDocument();
	});

	it('formats zero price correctly', () => {
		const item = { ...MOCK_ITEM_FULL, acquired_price_cents: 0 };
		render(InventoryItem, { props: { item } });
		expect(screen.getByText('Price: $0.00')).toBeInTheDocument();
	});

	it('formats large prices correctly', () => {
		const item = { ...MOCK_ITEM_FULL, acquired_price_cents: 999999 };
		render(InventoryItem, { props: { item } });
		expect(screen.getByText('Price: $9999.99')).toBeInTheDocument();
	});

	it('displays N/A for undefined price', () => {
		const item = { ...MOCK_ITEM_FULL, acquired_price_cents: undefined };
		render(InventoryItem, { props: { item } });
		// Price should not be displayed when undefined
		expect(screen.queryByText(/Price:/)).not.toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Different Quantities
// ---------------------------------------------------------------------------
describe('InventoryItem - Quantity Display', () => {
	it('displays quantity of 1', () => {
		render(InventoryItem, { props: { item: MOCK_ITEM_MINIMAL } });
		expect(screen.getByText('1')).toBeInTheDocument();
	});

	it('displays large quantity', () => {
		const item = { ...MOCK_ITEM_FULL, quantity: 999 };
		render(InventoryItem, { props: { item } });
		expect(screen.getByText('999')).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Layout and Styling
// ---------------------------------------------------------------------------
describe('InventoryItem - Layout', () => {
	it('renders with proper container class', () => {
		const { container } = render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(container.querySelector('.inventory-item')).toBeInTheDocument();
	});

	it('has card image container', () => {
		const { container } = render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(container.querySelector('.card-image')).toBeInTheDocument();
	});

	it('has card details container', () => {
		const { container } = render(InventoryItem, { props: { item: MOCK_ITEM_FULL } });
		expect(container.querySelector('.card-details')).toBeInTheDocument();
	});
});
