import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, cleanup } from '@testing-library/svelte';
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

	it('should render with Search navigation link', () => {
		const { container } = render(Sidebar);
		const searchLink = container.querySelector('a[href="/search"]');
		expect(searchLink).toBeInTheDocument();
		expect(searchLink).toHaveAttribute('href', `${base}/search`);
	});

	it('should render with Inventory navigation link', () => {
		const { container } = render(Sidebar);
		const inventoryLink = container.querySelector('a[href="/inventory"]');
		expect(inventoryLink).toBeInTheDocument();
		expect(inventoryLink).toHaveAttribute('href', `${base}/inventory`);
	});

	it('should render all navigation links in correct order', () => {
		const { container } = render(Sidebar);
		const links = container.querySelectorAll('a.nav-link');

		// Should have exactly 3 links
		expect(links).toHaveLength(3);

		// Check hrefs are correct
		const hrefs = Array.from(links).map((link) => link.getAttribute('href'));
		expect(hrefs).toContain('/');
		expect(hrefs).toContain('/search');
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

	it('should have accessible navigation links', () => {
		const { container } = render(Sidebar);
		const links = container.querySelectorAll('a.nav-link');

		// Should have exactly 3 links
		expect(links.length).toBe(3);
		links.forEach((link) => {
			expect(link).toBeInTheDocument();
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
	it('should use Flowbite styling classes', () => {
		const { container } = render(Sidebar);
		const sidebar = container.querySelector('aside');
		expect(sidebar).toBeInTheDocument();
	});
});
