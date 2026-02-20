import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/svelte';
import InventoryResult from './InventoryResult.svelte';
import type { InventoryResult as InventoryResultType } from '$lib/types/search';

// Mock data defined at module level for access across all describe blocks
const mockResult: InventoryResultType = {
	id: 1,
	card_id: 'test-card-id',
	card_name: 'Lightning Bolt',
	set: 'lea',
	set_name: 'Limited Edition Alpha',
	collector_number: '161',
	quantity: 4,
	image_url: 'https://example.com/card.jpg',
	finish: 'foil',
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

/**
 * Tests for InventoryResult component
 */
describe('InventoryResult', () => {
	afterEach(() => {
		cleanup();
	});

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

	it('should render finish when provided', () => {
		render(InventoryResult, { result: mockResult, onViewDetails: mockViewDetails });
		expect(screen.getByText('Foil')).toBeInTheDocument();
	});

	it('should not render finish when not provided', () => {
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

describe('InventoryResult - Finish Type Display', () => {
	let mockViewDetailsFinish: (result: InventoryResultType) => void;

	beforeEach(() => {
		mockViewDetailsFinish = vi.fn() as (result: InventoryResultType) => void;
	});

	afterEach(() => {
		cleanup();
	});

	it('should render star indicator for foil finish', () => {
		const foilResult = { ...mockResult, finish: 'foil' };
		const { container } = render(InventoryResult, {
			result: foilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should render star indicator for etched finish', () => {
		const etchedResult = { ...mockResult, finish: 'etched' };
		const { container } = render(InventoryResult, {
			result: etchedResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should render star indicator for halofoil finish', () => {
		const halofoilResult = { ...mockResult, finish: 'halofoil' };
		const { container } = render(InventoryResult, {
			result: halofoilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should render star indicator for rainbowfoil finish', () => {
		const rainbowfoilResult = { ...mockResult, finish: 'rainbowfoil' };
		const { container } = render(InventoryResult, {
			result: rainbowfoilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should render star indicator for surgefoil finish', () => {
		const surgefoilResult = { ...mockResult, finish: 'surgefoil' };
		const { container } = render(InventoryResult, {
			result: surgefoilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toBeInTheDocument();
		expect(star?.textContent).toBe('★');
	});

	it('should display "Foil" tooltip without "finish" suffix', () => {
		const foilResult = { ...mockResult, finish: 'foil' };
		const { container } = render(InventoryResult, {
			result: foilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Foil');
		expect(star?.getAttribute('title')).not.toContain('finish');
	});

	it('should display "Etched" tooltip without "finish" suffix', () => {
		const etchedResult = { ...mockResult, finish: 'etched' };
		const { container } = render(InventoryResult, {
			result: etchedResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Etched');
		expect(star?.getAttribute('title')).not.toContain('finish');
	});

	it('should display "Halofoil" tooltip', () => {
		const halofoilResult = { ...mockResult, finish: 'halofoil' };
		const { container } = render(InventoryResult, {
			result: halofoilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Halofoil');
	});

	it('should display "Rainbowfoil" tooltip', () => {
		const rainbowfoilResult = { ...mockResult, finish: 'rainbowfoil' };
		const { container } = render(InventoryResult, {
			result: rainbowfoilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Rainbowfoil');
	});

	it('should display "Surgefoil" tooltip', () => {
		const surgefoilResult = { ...mockResult, finish: 'surgefoil' };
		const { container } = render(InventoryResult, {
			result: surgefoilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).toHaveAttribute('title', 'Surgefoil');
	});

	it('should not render star indicator for nonfoil cards', () => {
		const nonfoilResult = { ...mockResult, finish: 'nonfoil' };
		const { container } = render(InventoryResult, {
			result: nonfoilResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).not.toBeInTheDocument();
	});

	it('should not render star indicator for null finish', () => {
		const nullFinishResult = { ...mockResult, finish: null };
		const { container } = render(InventoryResult, {
			result: nullFinishResult,
			onViewDetails: mockViewDetailsFinish
		});
		const star = container.querySelector('.foil-star');
		expect(star).not.toBeInTheDocument();
	});
});
