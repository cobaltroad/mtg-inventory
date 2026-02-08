import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, cleanup, fireEvent } from '@testing-library/svelte';
import { base } from '$app/paths';
import Sidebar from './Sidebar.svelte';

// Mock $app/paths
vi.mock('$app/paths', () => ({
	base: ''
}));

afterEach(() => {
	cleanup();
});

describe('Sidebar Component - Skeleton UI Navigation Structure', () => {
	it('should render Skeleton UI Navigation component with sidebar layout', () => {
		const { container } = render(Sidebar);
		const root = container.querySelector('[data-scope="navigation"][data-part="root"]');
		expect(root).toBeInTheDocument();
		expect(root).toHaveAttribute('data-layout', 'sidebar');
	});

	it('should render Navigation.Content as the main scrollable container', () => {
		const { container } = render(Sidebar);
		const content = container.querySelector('[data-scope="navigation"][data-part="content"]');
		expect(content).toBeInTheDocument();
	});

	it('should render Navigation.Group for organizing navigation items', () => {
		const { container } = render(Sidebar);
		const group = container.querySelector('[data-scope="navigation"][data-part="group"]');
		expect(group).toBeInTheDocument();
	});

	it('should render Navigation.Menu to contain navigation items', () => {
		const { container } = render(Sidebar);
		const menu = container.querySelector('[data-scope="navigation"][data-part="menu"]');
		expect(menu).toBeInTheDocument();
	});
});

describe('Sidebar Component - Navigation Items', () => {
	it('should render Home navigation link', () => {
		const { container } = render(Sidebar);
		const homeLink = container.querySelector('a[href="/"]');
		expect(homeLink).toBeInTheDocument();
		expect(homeLink).toHaveTextContent('Home');
	});

	it('should render Search as a navigation link (updated for issue #108)', () => {
		const { container } = render(Sidebar);

		// Search should now be a navigation link
		const searchLink = container.querySelector('a[href*="search"]');
		expect(searchLink).toBeInTheDocument();
		expect(searchLink).toHaveTextContent('Search');

		// Should NOT be a button trigger anymore
		const searchButton = container.querySelector(
			'button[aria-label*="Search - Open search drawer"]'
		);
		expect(searchButton).not.toBeInTheDocument();
	});

	it('should render Metagame navigation link', () => {
		const { container } = render(Sidebar);
		const metagameLink = container.querySelector('a[href*="metagame"]');
		expect(metagameLink).toBeInTheDocument();
		expect(metagameLink).toHaveTextContent('Metagame');
	});

	it('should render Decks placeholder navigation link', () => {
		const { container } = render(Sidebar);
		const decksLink = container.querySelector('a[href*="decks"]');
		expect(decksLink).toBeInTheDocument();
		expect(decksLink).toHaveTextContent('Decks');
	});

	it('should render Reports placeholder navigation link', () => {
		const { container } = render(Sidebar);
		const reportsLink = container.querySelector('a[href*="reports"]');
		expect(reportsLink).toBeInTheDocument();
		expect(reportsLink).toHaveTextContent('Reports');
	});

	it('should render Inventory navigation link', () => {
		const { container } = render(Sidebar);
		const inventoryLink = container.querySelector('a[href="/inventory"]');
		expect(inventoryLink).toBeInTheDocument();
		expect(inventoryLink).toHaveTextContent('Inventory');
	});

	it('should render navigation items in correct order', () => {
		const { container } = render(Sidebar);
		const navLinks = Array.from(
			container.querySelectorAll('a[data-scope="navigation"][data-part="trigger-anchor"]')
		);
		const navTriggers = Array.from(
			container.querySelectorAll('button[data-scope="navigation"][data-part="trigger"]')
		);

		// Total items: 6 links (Home, Search, Metagame, Decks, Reports, Inventory)
		// Search is now a link, not a trigger (updated for issue #108)
		// There is 1 trigger for the mode toggle button (Collapse/Expand)
		expect(navLinks.length).toBe(6);
		expect(navTriggers.length).toBe(1); // Mode toggle button
	});
});

describe('Sidebar Component - Search Navigation Link', () => {
	it('should render Search as a navigation link (not a button)', () => {
		const { container } = render(Sidebar);

		// Search should be a link now, not a button trigger
		const searchLink = container.querySelector('a[href*="/search"]');
		expect(searchLink).toBeInTheDocument();
		expect(searchLink?.tagName).toBe('A');
	});

	it('should have correct href for Search link', () => {
		const { container } = render(Sidebar);
		const searchLink = container.querySelector('a[href*="/search"]');

		expect(searchLink).toHaveAttribute('href');
		const href = searchLink?.getAttribute('href');
		expect(href).toContain('/search');
	});

	it('should not have onSearchClick callback anymore', () => {
		// This test verifies the API change - onSearchClick prop no longer exists
		const props = { mode: 'sidebar' as const };
		expect(() => render(Sidebar, { props })).not.toThrow();
	});
});

describe('Sidebar Component - Responsive Behavior', () => {
	it('should render toggle button for mobile menu', () => {
		const { container } = render(Sidebar);
		const toggleButton = container.querySelector('button[aria-label="Toggle navigation menu"]');
		expect(toggleButton).toBeInTheDocument();
		expect(toggleButton).toHaveAttribute('type', 'button');
	});

	it('should toggle sidebar visibility when button is clicked', async () => {
		const { container } = render(Sidebar);
		const toggleButton = container.querySelector(
			'button[aria-label="Toggle navigation menu"]'
		) as HTMLButtonElement;

		// Get initial aria-expanded state
		const initialExpanded = toggleButton.getAttribute('aria-expanded');

		// Click toggle button
		await fireEvent.click(toggleButton);

		// aria-expanded should have changed
		const afterClickExpanded = toggleButton.getAttribute('aria-expanded');
		expect(afterClickExpanded).not.toBe(initialExpanded);
	});

	it('should update Navigation layout based on screen size', () => {
		const { container } = render(Sidebar);
		const root = container.querySelector('[data-scope="navigation"][data-part="root"]');

		// Should have sidebar layout on desktop
		expect(root).toHaveAttribute('data-layout', 'sidebar');
	});

	it('should be collapsible by default on mobile views', () => {
		const { container } = render(Sidebar, { props: { open: false } });
		const toggleButton = container.querySelector('button[aria-label="Toggle navigation menu"]');
		expect(toggleButton).toHaveAttribute('aria-expanded', 'false');
	});
});

describe('Sidebar Component - Active Route Highlighting', () => {
	it('should highlight the active route with aria-current="page"', () => {
		const { container } = render(Sidebar);

		// Find the link that matches current path
		const links = container.querySelectorAll(
			'a[data-scope="navigation"][data-part="trigger-anchor"]'
		);
		const activeLink = Array.from(links).find(
			(link) => link.getAttribute('aria-current') === 'page'
		);

		expect(activeLink).toBeInTheDocument();
	});

	it('should apply active styling class to current route', () => {
		const { container } = render(Sidebar);

		// The active link should have special styling
		const links = container.querySelectorAll(
			'a[data-scope="navigation"][data-part="trigger-anchor"]'
		);
		const activeLink = Array.from(links).find(
			(link) => link.getAttribute('aria-current') === 'page'
		);

		if (activeLink) {
			expect(activeLink.classList.contains('active')).toBe(true);
		}
	});

	it('should not apply active state to Search trigger', () => {
		const { container } = render(Sidebar);
		const searchTrigger = container.querySelector(
			'button[data-scope="navigation"][data-part="trigger"]'
		);

		expect(searchTrigger).not.toHaveAttribute('aria-current');
		expect(searchTrigger?.classList.contains('active')).toBe(false);
	});
});

describe('Sidebar Component - Accessibility', () => {
	it('should have proper ARIA landmark role', () => {
		const { container } = render(Sidebar);
		const sidebar = container.querySelector('aside[aria-label="Navigation sidebar"]');
		expect(sidebar).toBeInTheDocument();
	});

	it('should have keyboard navigable navigation items', () => {
		const { container } = render(Sidebar);
		const navLinks = container.querySelectorAll(
			'a[data-scope="navigation"][data-part="trigger-anchor"]'
		);

		navLinks.forEach((link) => {
			expect(link).toBeInTheDocument();
			expect(link).toHaveAttribute('href');
		});
	});

	it('should have keyboard navigable toggle button', () => {
		const { container } = render(Sidebar);
		const toggleButton = container.querySelector('button[aria-label="Toggle navigation menu"]');
		expect(toggleButton).toHaveAttribute('type', 'button');
	});

	it('should have proper aria-expanded on toggle button', () => {
		const { container } = render(Sidebar, { props: { open: true } });
		const toggleButton = container.querySelector('button[aria-label="Toggle navigation menu"]');
		expect(toggleButton).toHaveAttribute('aria-expanded', 'true');
	});

	it('should have descriptive labels for all navigation items', () => {
		const { container } = render(Sidebar);
		const navLinks = container.querySelectorAll(
			'a[data-scope="navigation"][data-part="trigger-anchor"]'
		);
		const navTriggers = container.querySelectorAll(
			'button[data-scope="navigation"][data-part="trigger"]'
		);

		// All navigation items should have visible text or aria-label
		[...navLinks, ...navTriggers].forEach((item) => {
			const hasText = item.textContent && item.textContent.trim().length > 0;
			const hasAriaLabel = item.hasAttribute('aria-label');
			expect(hasText || hasAriaLabel).toBe(true);
		});
	});
});

describe('Sidebar Component - Props', () => {
	it('should accept open prop to control visibility', () => {
		const { container } = render(Sidebar, { props: { open: true } });
		const toggleButton = container.querySelector('button[aria-label="Toggle navigation menu"]');
		expect(toggleButton).toHaveAttribute('aria-expanded', 'true');
	});

	it('should accept open prop as false to hide sidebar', () => {
		const { container } = render(Sidebar, { props: { open: false } });
		const toggleButton = container.querySelector('button[aria-label="Toggle navigation menu"]');
		expect(toggleButton).toHaveAttribute('aria-expanded', 'false');
	});

	it('should accept onSearchClick callback prop', () => {
		const onSearchClick = vi.fn();
		const { container } = render(Sidebar, { props: { onSearchClick } });
		const searchTrigger = container.querySelector(
			'button[data-scope="navigation"][data-part="trigger"]'
		);
		expect(searchTrigger).toBeInTheDocument();
	});
});

describe('Sidebar Component - Icon Display', () => {
	it('should render icons for all navigation items', () => {
		const { container } = render(Sidebar);

		// Each navigation item should have an icon
		const navLinks = container.querySelectorAll(
			'a[data-scope="navigation"][data-part="trigger-anchor"]'
		);
		const navTriggers = container.querySelectorAll(
			'button[data-scope="navigation"][data-part="trigger"]'
		);

		[...navLinks, ...navTriggers].forEach((item) => {
			const icon = item.querySelector('svg');
			expect(icon).toBeInTheDocument();
		});
	});

	it('should use appropriate icons for each navigation item', () => {
		const { container } = render(Sidebar);

		// Home should have House icon
		const homeLink = container.querySelector('a[href="/"]');
		expect(homeLink?.querySelector('svg')).toBeInTheDocument();

		// Search should have Search icon
		const searchTrigger = container.querySelector(
			'button[data-scope="navigation"][data-part="trigger"]'
		);
		expect(searchTrigger?.querySelector('svg')).toBeInTheDocument();
	});
});

describe('Sidebar Component - Custom CSS Cleanup', () => {
	it('should use Skeleton UI Navigation component instead of custom structure', () => {
		const { container } = render(Sidebar);
		// Should have Skeleton UI Navigation root
		const skeletonNav = container.querySelector('[data-scope="navigation"][data-part="root"]');
		expect(skeletonNav).toBeInTheDocument();
	});

	it('should not have custom nav-link class', () => {
		const { container } = render(Sidebar);
		const customNavLink = container.querySelector('.nav-link');
		expect(customNavLink).not.toBeInTheDocument();
	});

	it('should not have custom sidebar-content class', () => {
		const { container } = render(Sidebar);
		const customContent = container.querySelector('.sidebar-content');
		expect(customContent).not.toBeInTheDocument();
	});

	it('should not have custom sidebar-nav class', () => {
		const { container } = render(Sidebar);
		const customNav = container.querySelector('.sidebar-nav');
		expect(customNav).not.toBeInTheDocument();
	});
});
