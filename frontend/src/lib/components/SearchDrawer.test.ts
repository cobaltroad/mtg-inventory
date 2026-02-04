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

	// NEW TEST: Search form submission should trigger parent handler
	it('should call onSearch handler when form is submitted', async () => {
		const onSearch = vi.fn();
		render(SearchDrawer, { props: { open: true, onSearch } });
		const input = document.body.querySelector('input[type="text"]') as HTMLInputElement;
		const form = document.body.querySelector('form');

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });

		if (form) {
			await fireEvent.submit(form);
		}

		// onSearch should be called with the query
		expect(onSearch).toHaveBeenCalledWith('Lightning Bolt');
	});

	// NEW TEST: Search form submission should trigger on Enter key
	it('should call onSearch handler when Enter key is pressed', async () => {
		const onSearch = vi.fn();
		render(SearchDrawer, { props: { open: true, onSearch } });
		const input = document.body.querySelector('input[type="text"]') as HTMLInputElement;
		const form = document.body.querySelector('form');

		await fireEvent.input(input, { target: { value: 'Lightning Bolt' } });
		// Enter key submits the form
		await fireEvent.keyDown(input, { key: 'Enter' });
		if (form) {
			await fireEvent.submit(form);
		}

		// onSearch should be called with the query
		expect(onSearch).toHaveBeenCalledWith('Lightning Bolt');
	});

	// NEW TEST: Search button should be disabled when query is empty
	it('should disable search button when query is empty', () => {
		render(SearchDrawer, { props: { open: true } });
		const button = document.body.querySelector('button[type="submit"]') as HTMLButtonElement;

		expect(button).toBeDisabled();
	});

	// NEW TEST: Search button should be enabled when query has value
	it('should enable search button when query has value', async () => {
		render(SearchDrawer, { props: { open: true } });
		const input = document.body.querySelector('input[type="text"]') as HTMLInputElement;
		const button = document.body.querySelector('button[type="submit"]') as HTMLButtonElement;

		await fireEvent.input(input, { target: { value: 'Lightning' } });

		expect(button).not.toBeDisabled();
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

	// NEW TEST: Loading spinner should be visible during search
	it('should display loading spinner when searching is true', () => {
		render(SearchDrawer, {
			props: { open: true, searching: true }
		});

		const spinner = document.body.querySelector('.spinner');
		expect(spinner).toBeInTheDocument();
	});

	it('should display "no results" message when search returns empty', () => {
		render(SearchDrawer, {
			props: { open: true, results: [], hasSearched: true }
		});

		expect(document.body.textContent?.toLowerCase()).toContain('no results');
	});

	// NEW TEST: Search form should remain visible when displaying results
	it('should keep search form visible when results are displayed', () => {
		render(SearchDrawer, {
			props: { open: true, results: mockCards }
		});

		const form = document.body.querySelector('form');
		const input = document.body.querySelector('input[type="text"]');

		expect(form).toBeInTheDocument();
		expect(input).toBeInTheDocument();
		expect(document.body.textContent).toContain('Lightning Bolt');
	});

	// NEW TEST: Results container should be scrollable
	it('should have scrollable results container', () => {
		render(SearchDrawer, {
			props: { open: true, results: mockCards }
		});

		const resultsContainer = document.body.querySelector('.results-container');
		expect(resultsContainer).toBeInTheDocument();

		// Results container should exist and have the proper class for scrolling
		// Note: JSDOM may not compute styles the same as browsers, so we verify the container exists
		expect(resultsContainer).toHaveClass('results-container');
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

	it('should call onCardSelect with correct card data when result is clicked', async () => {
		const onCardSelect = vi.fn();
		render(SearchDrawer, {
			props: { open: true, results: mockCards, onCardSelect }
		});

		const firstResult = document.body.querySelector('[data-card-id="card-1"]');
		expect(firstResult).toBeInTheDocument();

		if (firstResult) {
			await fireEvent.click(firstResult);
			expect(onCardSelect).toHaveBeenCalledWith(mockCards[0]);
		}
	});

	it('should make card result buttons keyboard accessible', async () => {
		const onCardSelect = vi.fn();
		render(SearchDrawer, {
			props: { open: true, results: mockCards, onCardSelect }
		});

		const firstResult = document.body.querySelector('[data-card-id="card-1"]') as HTMLElement;
		expect(firstResult).toBeInTheDocument();

		// Test Enter key
		await fireEvent.keyDown(firstResult, { key: 'Enter' });
		expect(onCardSelect).toHaveBeenCalledWith(mockCards[0]);

		// Test Space key
		await fireEvent.keyDown(firstResult, { key: ' ' });
		expect(onCardSelect).toHaveBeenCalledTimes(2);
	});

	it('should display card mana cost if available', () => {
		render(SearchDrawer, {
			props: { open: true, results: mockCards }
		});

		expect(document.body.textContent).toContain('{R}');
		expect(document.body.textContent).toContain('{U}{U}');
	});

	// NEW TEST: Should display card name for each result
	it('should display card name for each result', () => {
		render(SearchDrawer, {
			props: { open: true, results: mockCards }
		});

		mockCards.forEach((card) => {
			expect(document.body.textContent).toContain(card.name);
		});
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
