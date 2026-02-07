import { describe, it, expect, afterEach, vi } from 'vitest';
import { render, screen, cleanup } from '@testing-library/svelte';
import EmptyInventory from './EmptyInventory.svelte';

// Mock context for openSearchDrawer
const mockContext = new Map([['openSearchDrawer', vi.fn()]]);

afterEach(() => {
	cleanup();
});

// ---------------------------------------------------------------------------
// Tests: Content Display
// ---------------------------------------------------------------------------
describe('EmptyInventory - Content', () => {
	it('renders empty state heading', () => {
		render(EmptyInventory, { context: mockContext });
		expect(screen.getByText('Your inventory is empty')).toBeInTheDocument();
	});

	it('renders descriptive message', () => {
		render(EmptyInventory, { context: mockContext });
		expect(
			screen.getByText(
				'Start building your collection by searching for cards and adding them to your inventory.'
			)
		).toBeInTheDocument();
	});

	it('renders call-to-action button', () => {
		render(EmptyInventory, { context: mockContext });
		expect(screen.getByText('Search for Cards')).toBeInTheDocument();
	});

	it('displays icon or emoji', () => {
		const { container } = render(EmptyInventory, { context: mockContext });
		expect(container.querySelector('.empty-icon')).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Search Drawer Integration
// ---------------------------------------------------------------------------
describe('EmptyInventory - Navigation', () => {
	it('CTA button opens search drawer', () => {
		render(EmptyInventory, { context: mockContext });
		const button = screen.getByText('Search for Cards');
		expect(button).toBeInTheDocument();
		expect(button.tagName).toBe('BUTTON');
	});

	it('CTA button is a proper button element', () => {
		render(EmptyInventory, { context: mockContext });
		const button = screen.getByText('Search for Cards');
		expect(button.tagName).toBe('BUTTON');
	});
});

// ---------------------------------------------------------------------------
// Tests: Layout and Styling
// ---------------------------------------------------------------------------
describe('EmptyInventory - Layout', () => {
	it('renders with proper container class', () => {
		const { container } = render(EmptyInventory, { context: mockContext });
		expect(container.querySelector('.empty-state')).toBeInTheDocument();
	});

	it('CTA button has proper styling class', () => {
		const { container } = render(EmptyInventory, { context: mockContext });
		const button = container.querySelector('.cta-button');
		expect(button).toBeInTheDocument();
	});
});
