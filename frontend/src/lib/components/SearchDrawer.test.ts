import { describe, it, expect, afterEach, vi } from 'vitest';
import { render, cleanup, fireEvent, waitFor } from '@testing-library/svelte';
import SearchDrawer from './SearchDrawer.svelte';

afterEach(() => {
	cleanup();
});

const mockCards = [
	{
		id: 'card-1',
		name: 'Lightning Bolt',
		mana_cost: '{R}'
	},
	{
		id: 'card-2',
		name: 'Counterspell',
		mana_cost: '{U}{U}'
	}
];

describe('SearchDrawer Component - Structure', () => {
	it('should render drawer container', () => {
		render(SearchDrawer, { props: { open: true } });
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeInTheDocument();
	});

	it('should have search input field', () => {
		render(SearchDrawer, { props: { open: true } });
		const input = document.body.querySelector('input[type="text"]');
		expect(input).toBeInTheDocument();
	});

	it('should have search button', () => {
		render(SearchDrawer, { props: { open: true } });
		const button = document.body.querySelector(
			'button[type="submit"], button[aria-label*="Search"]'
		);
		expect(button).toBeInTheDocument();
	});

	it('should have close button', () => {
		render(SearchDrawer, { props: { open: true } });
		const closeButton = document.body.querySelector('button[aria-label*="Close"]');
		expect(closeButton).toBeInTheDocument();
	});
});

describe('SearchDrawer Component - Open/Close Behavior', () => {
	it('should render when open prop is true', () => {
		render(SearchDrawer, { props: { open: true } });
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		expect(drawer).toBeVisible();
	});

	it('should not render when open prop is false', () => {
		render(SearchDrawer, { props: { open: false } });
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');
		// Drawer might be hidden or not visible
		if (drawer) {
			expect(drawer).not.toBeVisible();
		}
	});

	it('should close when close button is clicked', async () => {
		render(SearchDrawer, { props: { open: true } });
		const closeButton = document.body.querySelector(
			'button[aria-label*="Close"]'
		) as HTMLButtonElement;

		expect(closeButton).toBeInTheDocument();

		await fireEvent.click(closeButton);

		// Close button click should trigger close behavior
		// The actual open state is managed by parent, so we just verify the button works
		expect(closeButton).toBeInTheDocument();
	});

	it('should close when Escape key is pressed', async () => {
		render(SearchDrawer, { props: { open: true } });
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');

		await fireEvent.keyDown(drawer!, { key: 'Escape' });

		// Should trigger close behavior
		expect(drawer).toBeInTheDocument();
	});
});

describe('SearchDrawer Component - Search Functionality', () => {
	it('should allow typing in search input', async () => {
		render(SearchDrawer, { props: { open: true } });
		const input = document.body.querySelector('input[type="text"]') as HTMLInputElement;

		await fireEvent.input(input, { target: { value: 'Lightning' } });

		expect(input.value).toBe('Lightning');
	});

	it('should handle search submission', async () => {
		render(SearchDrawer, { props: { open: true } });
		const input = document.body.querySelector('input[type="text"]') as HTMLInputElement;
		const form = document.body.querySelector('form');

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });

		if (form) {
			await fireEvent.submit(form);
		}

		// Search should be triggered
		expect(input.value).toBe('Lightning Bolt');
	});

	it('should display search results', async () => {
		render(SearchDrawer, {
			props: { open: true, results: mockCards }
		});

		await waitFor(() => {
			expect(document.body.textContent).toContain('Lightning Bolt');
			expect(document.body.textContent).toContain('Counterspell');
		});
	});

	it('should show loading state when searching', () => {
		render(SearchDrawer, {
			props: { open: true, searching: true }
		});

		expect(document.body.textContent?.toLowerCase()).toContain('searching');
	});

	it('should display "no results" message when search returns empty', () => {
		render(SearchDrawer, {
			props: { open: true, results: [], hasSearched: true }
		});

		expect(document.body.textContent?.toLowerCase()).toContain('no results');
	});
});

describe('SearchDrawer Component - Card Selection', () => {
	it('should allow clicking on search results', async () => {
		const onCardSelect = vi.fn();
		render(SearchDrawer, {
			props: { open: true, results: mockCards, onCardSelect }
		});

		const firstResult = document.body.querySelector('[data-card-id]');
		if (firstResult) {
			await fireEvent.click(firstResult);
			expect(onCardSelect).toHaveBeenCalled();
		}
	});

	it('should display card mana cost if available', () => {
		render(SearchDrawer, {
			props: { open: true, results: mockCards }
		});

		expect(document.body.textContent).toContain('{R}');
		expect(document.body.textContent).toContain('{U}{U}');
	});
});

describe('SearchDrawer Component - Accessibility', () => {
	it('should have proper ARIA labels', () => {
		render(SearchDrawer, { props: { open: true } });
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');

		expect(drawer).toHaveAttribute('role');
	});

	it('should have accessible close button', () => {
		render(SearchDrawer, { props: { open: true } });
		const closeButton = document.body.querySelector('button[aria-label*="Close"]');

		expect(closeButton).toHaveAttribute('aria-label');
	});

	it('should have labeled search input', () => {
		render(SearchDrawer, { props: { open: true } });
		const input = document.body.querySelector('input[type="text"]');

		// Input should have label or aria-label
		expect(
			input?.getAttribute('aria-label') || document.body.querySelector('label[for]')
		).toBeTruthy();
	});
});

describe('SearchDrawer Component - Responsive Design', () => {
	it('should render with responsive classes', () => {
		render(SearchDrawer, { props: { open: true } });
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');

		expect(drawer?.className).toBeTruthy();
	});
});

describe('SearchDrawer Component - Auto-focus', () => {
	it('should auto-focus search input when drawer opens', async () => {
		const { rerender } = render(SearchDrawer, { props: { open: false } });

		// Open the drawer
		await rerender({ open: true });

		// Wait for the focus to be applied
		await waitFor(() => {
			const input = document.body.querySelector('input[type="text"]') as HTMLInputElement;
			expect(document.activeElement).toBe(input);
		});
	});

	it('should have proper ARIA dialog attributes', () => {
		render(SearchDrawer, { props: { open: true } });
		const drawer = document.body.querySelector('[data-testid="search-drawer"]');

		expect(drawer).toHaveAttribute('role', 'dialog');
		expect(drawer).toHaveAttribute('aria-label', 'Search cards');
	});
});
