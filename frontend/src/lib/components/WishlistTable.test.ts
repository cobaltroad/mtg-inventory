import { describe, it, expect, afterEach } from 'vitest';
import { render, cleanup } from '@testing-library/svelte';
import WishlistTable from './WishlistTable.svelte';
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
		acquired_date: null,
		acquired_price_cents: null,
		finish: 'foil',
		language: 'English',
		created_at: '2024-01-15T10:00:00Z',
		updated_at: '2024-01-15T10:00:00Z',
		user_id: 1,
		collection_type: 'wishlist'
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
		finish: null,
		language: null,
		created_at: '2024-01-16T10:00:00Z',
		updated_at: '2024-01-16T10:00:00Z',
		user_id: 1,
		collection_type: 'wishlist'
	}
];

describe('WishlistTable Component - Finish Type Display', () => {
	it('should render star indicator for foil finish', () => {
		const foilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'foil'
			}
		];
		const { container } = render(WishlistTable, { props: { items: foilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should render star indicator for etched finish', () => {
		const etchedItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'etched'
			}
		];
		const { container } = render(WishlistTable, { props: { items: etchedItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should render star indicator for halofoil finish', () => {
		const halofoilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'foil',
				promo_types: ['halofoil']
			}
		];
		const { container } = render(WishlistTable, { props: { items: halofoilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should render star indicator for rainbowfoil finish', () => {
		const rainbowfoilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'foil',
				promo_types: ['rainbowfoil']
			}
		];
		const { container } = render(WishlistTable, { props: { items: rainbowfoilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should render star indicator for surgefoil finish', () => {
		const surgefoilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'foil',
				promo_types: ['surgefoil']
			}
		];
		const { container } = render(WishlistTable, { props: { items: surgefoilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should display "Foil" tooltip without "finish" suffix', () => {
		const foilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'foil'
			}
		];
		const { container } = render(WishlistTable, { props: { items: foilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Foil');
		expect(star?.getAttribute('title')).not.toContain('finish');
	});

	it('should display "Etched" tooltip without "finish" suffix', () => {
		const etchedItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'etched'
			}
		];
		const { container } = render(WishlistTable, { props: { items: etchedItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Etched');
		expect(star?.getAttribute('title')).not.toContain('finish');
	});

	it('should display "Halofoil" tooltip', () => {
		const halofoilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'foil',
				promo_types: ['halofoil']
			}
		];
		const { container } = render(WishlistTable, { props: { items: halofoilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Halofoil');
	});

	it('should display "Rainbowfoil" tooltip', () => {
		const rainbowfoilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'foil',
				promo_types: ['rainbowfoil']
			}
		];
		const { container } = render(WishlistTable, { props: { items: rainbowfoilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Rainbowfoil');
	});

	it('should display "Surgefoil" tooltip', () => {
		const surgefoilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'foil',
				promo_types: ['surgefoil']
			}
		];
		const { container } = render(WishlistTable, { props: { items: surgefoilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Surgefoil');
	});

	it('should not render star indicator for nonfoil cards', () => {
		const nonfoilItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: 'nonfoil'
			}
		];
		const { container } = render(WishlistTable, { props: { items: nonfoilItem } });
		const star = container.querySelector('.foil-star');
		expect(star).not.toBeInTheDocument();
	});

	it('should not render star indicator for null finish', () => {
		const nullFinishItem: InventoryItem[] = [
			{
				...mockItems[0],
				finish: null
			}
		];
		const { container } = render(WishlistTable, { props: { items: nullFinishItem } });
		const star = container.querySelector('.foil-star');
		expect(star).not.toBeInTheDocument();
	});
});
