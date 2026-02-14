/**
 * Test suite for simplified inventory page widgets
 * Verifies that Total Value, Cards Over $10, and Different Sets widgets
 * have been removed while keeping Most Valuable Card and Most Collected Set
 */

import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import InventoryStats from '$lib/components/InventoryStats.svelte';

describe('Simplified Inventory Widgets', () => {
	it('should NOT display Total Value widget', () => {
		const stats = {
			mostValuableCard: 'Black Lotus',
			mostCollectedSet: 'Alpha'
		};

		render(InventoryStats, { props: { stats } });

		// Should not find "Total Value" label
		expect(screen.queryByText('Total Value')).toBeNull();

		// Should not find dollar sign icon for total value
		const statLabels = screen.queryAllByText(/Total Value/i);
		expect(statLabels).toHaveLength(0);
	});

	it('should NOT display Cards Over $10 widget', () => {
		const stats = {
			mostValuableCard: 'Black Lotus',
			mostCollectedSet: 'Alpha'
		};

		render(InventoryStats, { props: { stats } });

		// Should not find "Cards Over $10" label
		expect(screen.queryByText('Cards Over $10')).toBeNull();

		const statLabels = screen.queryAllByText(/Cards Over \$10/i);
		expect(statLabels).toHaveLength(0);
	});

	it('should NOT display Different Sets widget', () => {
		const stats = {
			mostValuableCard: 'Black Lotus',
			mostCollectedSet: 'Alpha'
		};

		render(InventoryStats, { props: { stats } });

		// Should not find "Different Sets" label
		expect(screen.queryByText('Different Sets')).toBeNull();

		const statLabels = screen.queryAllByText(/Different Sets/i);
		expect(statLabels).toHaveLength(0);
	});

	it('should ONLY display Most Valuable Card and Most Collected Set widgets', () => {
		const stats = {
			mostValuableCard: 'Black Lotus',
			mostCollectedSet: 'Alpha'
		};

		const { container } = render(InventoryStats, { props: { stats } });

		// Should find exactly these two labels in this specific container
		const mostValuableLabels = container.querySelectorAll('.stat-label');
		const labelTexts = Array.from(mostValuableLabels).map((el) => el.textContent);
		expect(labelTexts).toContain('Most Valuable');
		expect(labelTexts).toContain('Most Collected Set');

		// Should find exactly 2 stat cards in this container
		const statCards = container.querySelectorAll('.stat-card');
		expect(statCards.length).toBe(2);
	});

	it('should render Most Valuable Card widget with correct value', () => {
		const stats = {
			mostValuableCard: 'Black Lotus',
			mostCollectedSet: 'Alpha'
		};

		const { container } = render(InventoryStats, { props: { stats } });

		expect(container.textContent).toContain('Black Lotus');
		expect(container.textContent).toContain('Most Valuable');
	});

	it('should render Most Collected Set widget with correct value', () => {
		const stats = {
			mostValuableCard: 'Black Lotus',
			mostCollectedSet: 'Alpha'
		};

		const { container } = render(InventoryStats, { props: { stats } });

		expect(container.textContent).toContain('Alpha');
		expect(container.textContent).toContain('Most Collected Set');
	});

	it('should handle missing mostValuableCard gracefully', () => {
		const stats = {
			mostValuableCard: null,
			mostCollectedSet: 'Alpha'
		};

		const { container } = render(InventoryStats, { props: { stats } });

		// Should only show 1 stat card when mostValuableCard is null
		const statCards = container.querySelectorAll('.stat-card');
		expect(statCards.length).toBe(1);
		expect(container.textContent).toContain('Most Collected Set');
	});

	it('should handle missing mostCollectedSet gracefully', () => {
		const stats = {
			mostValuableCard: 'Black Lotus',
			mostCollectedSet: null
		};

		const { container } = render(InventoryStats, { props: { stats } });

		// Should only show 1 stat card when mostCollectedSet is null
		const statCards = container.querySelectorAll('.stat-card');
		expect(statCards.length).toBe(1);
		expect(container.textContent).toContain('Most Valuable');
	});
});
