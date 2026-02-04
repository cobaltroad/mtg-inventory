import { describe, it, expect, afterEach, vi } from 'vitest';
import { render, cleanup, fireEvent } from '@testing-library/svelte';
import Sidebar from '$lib/components/Sidebar.svelte';

afterEach(() => {
	cleanup();
});

describe('Search Drawer Integration - Sidebar Trigger', () => {
	it('should have Search button in sidebar instead of link', () => {
		// Mock window.location for Sidebar component
		Object.defineProperty(window, 'location', {
			value: { pathname: '/' },
			writable: true
		});

		const { container } = render(Sidebar);

		// Find the Search button in the sidebar
		const searchButton = container.querySelector('button[aria-label*="Search"]') as HTMLButtonElement;
		expect(searchButton).toBeInTheDocument();
		expect(searchButton).toHaveAttribute('type', 'button');

		// Should not have a search link
		const searchLink = container.querySelector('a[href*="search"]');
		expect(searchLink).not.toBeInTheDocument();
	});

	it('should trigger onSearchClick callback when Search button is clicked', async () => {
		Object.defineProperty(window, 'location', {
			value: { pathname: '/' },
			writable: true
		});

		const onSearchClick = vi.fn();
		const { container } = render(Sidebar, { props: { onSearchClick } });

		const searchButton = container.querySelector('button[aria-label*="Search"]') as HTMLButtonElement;
		await fireEvent.click(searchButton);

		// Callback should be called
		expect(onSearchClick).toHaveBeenCalledTimes(1);
	});

	it('should have proper ARIA labels on Search button', () => {
		Object.defineProperty(window, 'location', {
			value: { pathname: '/' },
			writable: true
		});

		const { container } = render(Sidebar);

		const searchButton = container.querySelector('button[aria-label*="Search"]') as HTMLButtonElement;

		expect(searchButton).toHaveAttribute('aria-label');
		expect(searchButton.getAttribute('aria-label')).toContain('Search');
	});

	it('should still have Home and Inventory as navigation links', () => {
		Object.defineProperty(window, 'location', {
			value: { pathname: '/' },
			writable: true
		});

		const { container } = render(Sidebar);

		const homeLink = container.querySelector('a[href="/"]');
		expect(homeLink).toBeInTheDocument();

		const inventoryLink = container.querySelector('a[href="/inventory"]');
		expect(inventoryLink).toBeInTheDocument();
	});

	it('should work from any page (Home, Inventory, etc)', () => {
		const pages = ['/', '/inventory'];

		pages.forEach((pathname) => {
			Object.defineProperty(window, 'location', {
				value: { pathname },
				writable: true
			});

			const onSearchClick = vi.fn();
			const { container } = render(Sidebar, { props: { onSearchClick } });

			const searchButton = container.querySelector('button[aria-label*="Search"]') as HTMLButtonElement;
			expect(searchButton).toBeInTheDocument();

			cleanup();
		});
	});
});
