import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/svelte';
import InventoryResult from './InventoryResult.svelte';
import type { InventoryResult as InventoryResultType } from '$lib/types/search';

/**
 * Tests for InventoryResult component
 */
describe('InventoryResult', () => {
	afterEach(() => {
		cleanup();
	});
	const mockResult: InventoryResultType = {
		id: 1,
		card_id: 'test-card-id',
		card_name: 'Lightning Bolt',
		set: 'lea',
		set_name: 'Limited Edition Alpha',
		collector_number: '161',
		quantity: 4,
		image_url: 'https://example.com/card.jpg',
		treatment: 'Foil',
		unit_price_cents: 500,
		total_price_cents: 2000
	};

	const mockResultNoPrice: InventoryResultType = {
		id: 2,
		card_id: 'test-card-id-2',
		card_name: 'Test Card',
		set: 'test',
		set_name: 'Test Set',
		collector_number: '1',
		quantity: 1
	};

	let mockViewDetails: (result: InventoryResultType) => void;

	beforeEach(() => {
		mockViewDetails = vi.fn() as (result: InventoryResultType) => void;
	});

	it('should render card name', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		expect(screen.getByText('Lightning Bolt')).toBeInTheDocument();
	});

	it('should render set information', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		expect(screen.getByText('Limited Edition Alpha')).toBeInTheDocument();
		expect(screen.getByText(/LEA/i)).toBeInTheDocument();
		expect(screen.getByText(/#161/i)).toBeInTheDocument();
	});

	it('should render quantity', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		expect(screen.getByText(/Qty.*4/i)).toBeInTheDocument();
	});

	it('should render treatment when provided', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		expect(screen.getByText('Foil')).toBeInTheDocument();
	});

	it('should not render treatment when not provided', () => {
		render(InventoryResult, { result: mockResultNoPrice, onViewDetails: mockViewDetails });
		expect(screen.queryByText('Foil')).not.toBeInTheDocument();
	});

	it('should render card image when image_url is provided', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		const image = screen.getByAltText('Lightning Bolt from Limited Edition Alpha');
		expect(image).toBeInTheDocument();
		expect(image).toHaveAttribute('src', 'https://example.com/card.jpg');
	});

	it('should render placeholder when image_url is not provided', () => {
		render(InventoryResult, { result: mockResultNoPrice, onViewDetails: mockViewDetails });
		expect(screen.queryByRole('img')).not.toBeInTheDocument();
		expect(screen.getByText('Test Card', { selector: '.card-name-text' })).toBeInTheDocument();
	});

	it('should format prices correctly', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		expect(screen.getByText(/\$5\.00/)).toBeInTheDocument();
		expect(screen.getByText(/\$20\.00/)).toBeInTheDocument();
	});

	it('should display placeholder for missing prices', () => {
		render(InventoryResult, { result: mockResultNoPrice, onViewDetails: mockViewDetails });
		const placeholders = screen.getAllByText('—');
		expect(placeholders.length).toBe(2); // unit price and total price
	});

	it('should render View Details button', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		expect(screen.getByRole('button', { name: /View Details/i })).toBeInTheDocument();
	});

	it('should call onViewDetails when View Details button is clicked', async () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		const button = screen.getByRole('button', { name: /View Details/i });
		await fireEvent.click(button);
		expect(mockViewDetails).toHaveBeenCalledWith(mockResult);
	});

	it('should have proper accessibility attributes for image', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		const image = screen.getByAltText('Lightning Bolt from Limited Edition Alpha');
		expect(image).toHaveClass('card-image');
	});
});
