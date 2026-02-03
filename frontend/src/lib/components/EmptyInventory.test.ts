import { describe, it, expect, afterEach } from 'vitest';
import { render, screen, cleanup } from '@testing-library/svelte';
import EmptyInventory from './EmptyInventory.svelte';

afterEach(() => {
	cleanup();
});

// ---------------------------------------------------------------------------
// Tests: Content Display
// ---------------------------------------------------------------------------
describe('EmptyInventory - Content', () => {
	it('renders empty state heading', () => {
		render(EmptyInventory);
		expect(screen.getByText('Your inventory is empty')).toBeInTheDocument();
	});

	it('renders descriptive message', () => {
		render(EmptyInventory);
		expect(
			screen.getByText(
				'Start building your collection by searching for cards and adding them to your inventory.'
			)
		).toBeInTheDocument();
	});

	it('renders call-to-action button', () => {
		render(EmptyInventory);
		expect(screen.getByText('Search for Cards')).toBeInTheDocument();
	});

	it('displays icon or emoji', () => {
		const { container } = render(EmptyInventory);
		expect(container.querySelector('.empty-icon')).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Navigation Link
// ---------------------------------------------------------------------------
describe('EmptyInventory - Navigation', () => {
	it('CTA button links to search page', () => {
		render(EmptyInventory);
		const link = screen.getByText('Search for Cards').closest('a');
		expect(link).toHaveAttribute('href', '/search');
	});

	it('CTA button is a proper link element', () => {
		render(EmptyInventory);
		const link = screen.getByText('Search for Cards');
		expect(link.tagName).toBe('A');
	});
});

// ---------------------------------------------------------------------------
// Tests: Layout and Styling
// ---------------------------------------------------------------------------
describe('EmptyInventory - Layout', () => {
	it('renders with proper container class', () => {
		const { container } = render(EmptyInventory);
		expect(container.querySelector('.empty-state')).toBeInTheDocument();
	});

	it('CTA button has proper styling class', () => {
		const { container } = render(EmptyInventory);
		const button = container.querySelector('.cta-button');
		expect(button).toBeInTheDocument();
	});
});
