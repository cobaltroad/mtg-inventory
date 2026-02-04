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

describe('Sidebar Component - Navigation Links', () => {
	it('should render with Home navigation link', () => {
		const { container } = render(Sidebar);
		const homeLink = container.querySelector('a[href="/"]');
		expect(homeLink).toBeInTheDocument();
		expect(homeLink).toHaveAttribute('href', `${base}/`);
	});

	it('should render with Search navigation button', () => {
		const { container } = render(Sidebar);
		const searchButton = container.querySelector('button[aria-label*="Search"]');
		expect(searchButton).toBeInTheDocument();
		expect(searchButton).toHaveAttribute('type', 'button');
	});

	it('should render with Inventory navigation link', () => {
		const { container } = render(Sidebar);
		const inventoryLink = container.querySelector('a[href="/inventory"]');
		expect(inventoryLink).toBeInTheDocument();
		expect(inventoryLink).toHaveAttribute('href', `${base}/inventory`);
	});

	it('should render all navigation items in correct order', () => {
		const { container } = render(Sidebar);
		const links = container.querySelectorAll('a.nav-link');
		const buttons = container.querySelectorAll('button.nav-button');

		// Should have exactly 2 links and 1 button
		expect(links).toHaveLength(2);
		expect(buttons).toHaveLength(1);

		// Check link hrefs are correct
		const hrefs = Array.from(links).map((link) => link.getAttribute('href'));
		expect(hrefs).toContain('/');
		expect(hrefs).toContain('/inventory');
	});
});

describe('Sidebar Component - Responsive Behavior', () => {
	it('should have a toggle button for mobile menu', () => {
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
		await toggleButton.click();

		// aria-expanded should have changed
		const afterClickExpanded = toggleButton.getAttribute('aria-expanded');
		expect(afterClickExpanded).not.toBe(initialExpanded);
	});

	it('should be collapsible by default on mobile views', () => {
		const { container } = render(Sidebar);
		const aside = container.querySelector('aside[aria-label="Navigation sidebar"]');
		expect(aside).toBeInTheDocument();
	});
});

describe('Sidebar Component - Accessibility', () => {
	it('should have proper ARIA landmark role', () => {
		const { container } = render(Sidebar);
		const sidebar = container.querySelector('aside[aria-label="Navigation sidebar"]');
		expect(sidebar).toBeInTheDocument();
	});

	it('should have accessible navigation items', () => {
		const { container } = render(Sidebar);
		const links = container.querySelectorAll('a.nav-link');
		const buttons = container.querySelectorAll('button.nav-button');

		// Should have exactly 2 links and 1 button
		expect(links.length).toBe(2);
		expect(buttons.length).toBe(1);

		links.forEach((link) => {
			expect(link).toBeInTheDocument();
		});

		buttons.forEach((button) => {
			expect(button).toBeInTheDocument();
		});
	});

	it('should have keyboard navigable toggle button', () => {
		const { container } = render(Sidebar);
		const toggleButton = container.querySelector('button[aria-label="Toggle navigation menu"]');
		expect(toggleButton).toHaveAttribute('type', 'button');
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
});

describe('Sidebar Component - Styling', () => {
	it('should render with proper structure', () => {
		const { container } = render(Sidebar);
		const sidebar = container.querySelector('aside');
		expect(sidebar).toBeInTheDocument();
	});
});

describe('Sidebar Component - Search Drawer Trigger', () => {
	it('should render Search as a button instead of anchor link', () => {
		const { container } = render(Sidebar);
		const searchButton = container.querySelector('button[aria-label*="Search"]');
		expect(searchButton).toBeInTheDocument();

		// Should not have an anchor link for Search
		const searchLink = container.querySelector('a[href*="search"]');
		expect(searchLink).not.toBeInTheDocument();
	});

	it('should call onSearchClick when Search button is clicked', async () => {
		const onSearchClick = vi.fn();
		const { container } = render(Sidebar, { props: { onSearchClick } });

		const searchButton = container.querySelector(
			'button[aria-label*="Search"]'
		) as HTMLButtonElement;
		expect(searchButton).toBeInTheDocument();

		await fireEvent.click(searchButton);

		expect(onSearchClick).toHaveBeenCalledTimes(1);
	});

	it('should have proper ARIA attributes on Search button', () => {
		const { container } = render(Sidebar);
		const searchButton = container.querySelector('button[aria-label*="Search"]');

		expect(searchButton).toHaveAttribute('type', 'button');
		expect(searchButton).toHaveAttribute('aria-label');
	});

	it('should still render Home and Inventory as navigation links', () => {
		const { container } = render(Sidebar);

		const homeLink = container.querySelector('a[href="/"]');
		expect(homeLink).toBeInTheDocument();

		const inventoryLink = container.querySelector('a[href="/inventory"]');
		expect(inventoryLink).toBeInTheDocument();
	});

	it('should only have 2 anchor links (Home and Inventory)', () => {
		const { container } = render(Sidebar);
		const links = container.querySelectorAll('a.nav-link');

		// Should have exactly 2 links now (Home and Inventory)
		expect(links).toHaveLength(2);
	});
});
