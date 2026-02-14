import { describe, it, expect } from 'vitest';
import { filterDecklistCards, type FilterOptions, type DecklistCard } from './decklistFiltering';

describe('filterDecklistCards', () => {
	// Sample test data
	const commander: DecklistCard = {
		card_id: 'cmd-1',
		card_name: 'Atraxa, Praetors\' Voice',
		quantity: 1,
		is_commander: true,
		card_type: 'Legendary Creature — Phyrexian Angel Horror',
		rarity: 'mythic',
		edh_rank: 1,
		release_date: '2016-11-11',
		usd_price: '39.99'
	};

	const solRing: DecklistCard = {
		card_id: 'sr-1',
		card_name: 'Sol Ring',
		quantity: 1,
		card_type: 'Artifact',
		rarity: 'uncommon',
		edh_rank: 2,
		release_date: '2023-08-04',
		usd_price: '1.50'
	};

	const commandTower: DecklistCard = {
		card_id: 'ct-1',
		card_name: 'Command Tower',
		quantity: 1,
		card_type: 'Land',
		rarity: 'common',
		edh_rank: 3,
		release_date: '2023-11-17',
		usd_price: '0.25'
	};

	const plains: DecklistCard = {
		card_id: 'pl-1',
		card_name: 'Plains',
		quantity: 1,
		card_type: 'Basic Land — Plains',
		rarity: 'common',
		release_date: '2023-01-01',
		usd_price: '0.10'
	};

	const island: DecklistCard = {
		card_id: 'is-1',
		card_name: 'Island',
		quantity: 1,
		card_type: 'Basic Land — Island',
		rarity: 'common',
		release_date: '2023-01-01',
		usd_price: '0.10'
	};

	const expensiveCreature: DecklistCard = {
		card_id: 'exp-1',
		card_name: 'Expensive Creature',
		quantity: 1,
		card_type: 'Creature — Dragon',
		rarity: 'rare',
		edh_rank: 50,
		release_date: '2020-01-01',
		usd_price: '99.99'
	};

	const instant: DecklistCard = {
		card_id: 'ins-1',
		card_name: 'Lightning Bolt',
		quantity: 1,
		card_type: 'Instant',
		rarity: 'common',
		release_date: '2022-03-20',
		usd_price: '0.50'
	};

	const cardNoPrice: DecklistCard = {
		card_id: 'np-1',
		card_name: 'No Price Card',
		quantity: 1,
		card_type: 'Enchantment',
		rarity: 'rare',
		edh_rank: 100,
		release_date: '2021-06-15'
	};

	describe('no filters', () => {
		it('returns all cards when no filters are applied', () => {
			const cards = [commander, solRing, commandTower];
			const filtered = filterDecklistCards(cards, {});

			expect(filtered).toHaveLength(3);
		});
	});

	describe('commander-always-visible invariant', () => {
		it('always includes commanders regardless of filters', () => {
			const cards = [commander, solRing, commandTower];

			// Filter that would exclude commander by type
			const filtered = filterDecklistCards(cards, {
				cardTypes: ['Artifact']
			});

			// Commander should still be visible
			expect(filtered.some((c) => c.is_commander)).toBe(true);
			expect(filtered.find((c) => c.is_commander)?.card_name).toBe('Atraxa, Praetors\' Voice');
		});

		it('includes commanders even with strict price filter', () => {
			const cards = [commander, solRing, commandTower];

			// Filter that would exclude expensive commander
			const filtered = filterDecklistCards(cards, {
				minPrice: 0,
				maxPrice: 2
			});

			// Commander should still be visible
			expect(filtered.some((c) => c.is_commander)).toBe(true);
		});
	});

	describe('card type filtering', () => {
		it('filters by single card type', () => {
			const cards = [commander, solRing, commandTower, expensiveCreature];
			const filtered = filterDecklistCards(cards, {
				cardTypes: ['Artifact']
			});

			// Commander + Sol Ring
			expect(filtered).toHaveLength(2);
			expect(filtered.some((c) => c.card_name === 'Sol Ring')).toBe(true);
		});

		it('filters by multiple card types', () => {
			const cards = [commander, solRing, commandTower, expensiveCreature];
			const filtered = filterDecklistCards(cards, {
				cardTypes: ['Artifact', 'Creature']
			});

			// Commander + Sol Ring + Expensive Creature
			expect(filtered).toHaveLength(3);
			expect(filtered.some((c) => c.card_name === 'Sol Ring')).toBe(true);
			expect(filtered.some((c) => c.card_name === 'Expensive Creature')).toBe(true);
		});

		it('handles partial type matching (e.g., "Creature" matches "Legendary Creature")', () => {
			const cards = [commander, solRing, expensiveCreature];
			const filtered = filterDecklistCards(cards, {
				cardTypes: ['Creature']
			});

			// Commander + Expensive Creature (both have "Creature" in type)
			expect(filtered).toHaveLength(2);
			expect(filtered.some((c) => c.is_commander)).toBe(true);
			expect(filtered.some((c) => c.card_name === 'Expensive Creature')).toBe(true);
		});
	});

	describe('rarity filtering', () => {
		it('filters by single rarity', () => {
			const cards = [commander, solRing, commandTower, expensiveCreature];
			const filtered = filterDecklistCards(cards, {
				rarities: ['common']
			});

			// Commander + Command Tower
			expect(filtered).toHaveLength(2);
			expect(filtered.some((c) => c.card_name === 'Command Tower')).toBe(true);
		});

		it('filters by multiple rarities', () => {
			const cards = [commander, solRing, commandTower, expensiveCreature];
			const filtered = filterDecklistCards(cards, {
				rarities: ['rare', 'uncommon']
			});

			// Commander + Sol Ring + Expensive Creature
			expect(filtered).toHaveLength(3);
			expect(filtered.some((c) => c.card_name === 'Sol Ring')).toBe(true);
			expect(filtered.some((c) => c.card_name === 'Expensive Creature')).toBe(true);
		});
	});

	describe('basic lands filtering', () => {
		it('excludes basic lands when hideBasicLands is true', () => {
			const cards = [commander, solRing, commandTower, plains, island];
			const filtered = filterDecklistCards(cards, {
				hideBasicLands: true
			});

			// Commander + Sol Ring + Command Tower (no Plains/Island)
			expect(filtered).toHaveLength(3);
			expect(filtered.some((c) => c.card_name === 'Plains')).toBe(false);
			expect(filtered.some((c) => c.card_name === 'Island')).toBe(false);
		});

		it('includes basic lands when hideBasicLands is false', () => {
			const cards = [commander, solRing, plains, island];
			const filtered = filterDecklistCards(cards, {
				hideBasicLands: false
			});

			expect(filtered).toHaveLength(4);
			expect(filtered.some((c) => c.card_name === 'Plains')).toBe(true);
		});

		it('does not exclude non-basic lands', () => {
			const cards = [commander, commandTower, plains];
			const filtered = filterDecklistCards(cards, {
				hideBasicLands: true
			});

			// Command Tower is not a basic land
			expect(filtered.some((c) => c.card_name === 'Command Tower')).toBe(true);
		});
	});

	describe('price range filtering', () => {
		it('filters by minimum price', () => {
			const cards = [commander, solRing, commandTower, expensiveCreature];
			const filtered = filterDecklistCards(cards, {
				minPrice: 1.0
			});

			// Commander + Sol Ring + Expensive Creature (>= $1.00)
			expect(filtered).toHaveLength(3);
			expect(filtered.some((c) => c.card_name === 'Command Tower')).toBe(false);
		});

		it('filters by maximum price', () => {
			const cards = [commander, solRing, commandTower, expensiveCreature];
			const filtered = filterDecklistCards(cards, {
				maxPrice: 2.0
			});

			// Commander + Sol Ring + Command Tower (<= $2.00, commander always included)
			expect(filtered).toHaveLength(3);
			expect(filtered.some((c) => c.card_name === 'Expensive Creature')).toBe(false);
		});

		it('filters by price range', () => {
			const cards = [commander, solRing, commandTower, expensiveCreature];
			const filtered = filterDecklistCards(cards, {
				minPrice: 0.5,
				maxPrice: 10.0
			});

			// Commander + Sol Ring ($1.50)
			expect(filtered).toHaveLength(2);
			expect(filtered.some((c) => c.card_name === 'Sol Ring')).toBe(true);
		});

		it('excludes cards with no price when filtering by price', () => {
			const cards = [commander, solRing, cardNoPrice];
			const filtered = filterDecklistCards(cards, {
				minPrice: 0.5
			});

			// Commander + Sol Ring (cardNoPrice excluded)
			expect(filtered).toHaveLength(2);
			expect(filtered.some((c) => c.card_name === 'No Price Card')).toBe(false);
		});

		it('includes cards with no price when no price filter is set', () => {
			const cards = [commander, solRing, cardNoPrice];
			const filtered = filterDecklistCards(cards, {});

			expect(filtered).toHaveLength(3);
			expect(filtered.some((c) => c.card_name === 'No Price Card')).toBe(true);
		});
	});

	describe('combined filters', () => {
		it('applies multiple filters together (AND logic)', () => {
			const cards = [commander, solRing, commandTower, expensiveCreature, instant];

			const filtered = filterDecklistCards(cards, {
				cardTypes: ['Artifact', 'Creature'],
				rarities: ['uncommon', 'rare'],
				minPrice: 1.0
			});

			// Commander (always included) + Sol Ring (Artifact, uncommon, $1.50) + Expensive Creature (Creature, rare, $99.99)
			expect(filtered).toHaveLength(3);
			expect(filtered.some((c) => c.is_commander)).toBe(true);
			expect(filtered.some((c) => c.card_name === 'Sol Ring')).toBe(true);
			expect(filtered.some((c) => c.card_name === 'Expensive Creature')).toBe(true);
		});

		it('applies all filter types together', () => {
			const cards = [commander, solRing, commandTower, plains, expensiveCreature];

			const filtered = filterDecklistCards(cards, {
				cardTypes: ['Artifact'],
				rarities: ['uncommon'],
				hideBasicLands: true,
				minPrice: 1.0,
				maxPrice: 5.0
			});

			// Commander (always) + Sol Ring (Artifact, uncommon, $1.50)
			expect(filtered).toHaveLength(2);
			expect(filtered.some((c) => c.is_commander)).toBe(true);
			expect(filtered.some((c) => c.card_name === 'Sol Ring')).toBe(true);
		});
	});

	describe('edge cases', () => {
		it('handles empty card array', () => {
			const filtered = filterDecklistCards([], {
				cardTypes: ['Artifact']
			});

			expect(filtered).toHaveLength(0);
		});

		it('handles cards with missing metadata', () => {
			const noMetadata: DecklistCard = {
				card_id: 'nm-1',
				card_name: 'No Metadata',
				quantity: 1
			};

			const cards = [commander, noMetadata];
			const filtered = filterDecklistCards(cards, {
				cardTypes: ['Artifact']
			});

			// Commander (always) + no metadata card should be excluded
			expect(filtered).toHaveLength(1);
			expect(filtered[0].is_commander).toBe(true);
		});

		it('handles invalid price values', () => {
			const invalidPrice: DecklistCard = {
				...solRing,
				card_name: 'Invalid Price',
				usd_price: 'not-a-number'
			};

			const cards = [commander, invalidPrice];
			const filtered = filterDecklistCards(cards, {
				minPrice: 1.0
			});

			// Commander (always) + invalid price excluded
			expect(filtered).toHaveLength(1);
		});
	});
});
