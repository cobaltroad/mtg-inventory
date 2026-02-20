import { describe, it, expect } from 'vitest';
import { sortDecklistCards, type SortOption, type DecklistCard } from './decklistSorting';

describe('sortDecklistCards', () => {
	// Sample test data
	const commander: DecklistCard = {
		card_id: 'cmd-1',
		card_name: "Atraxa, Praetors' Voice",
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

	const expensiveCard: DecklistCard = {
		card_id: 'exp-1',
		card_name: 'Expensive Artifact',
		quantity: 1,
		card_type: 'Artifact',
		rarity: 'rare',
		edh_rank: 100,
		release_date: '2020-01-01',
		usd_price: '99.99'
	};

	const cardNoPrice: DecklistCard = {
		card_id: 'np-1',
		card_name: 'No Price Card',
		quantity: 1,
		card_type: 'Creature',
		rarity: 'rare',
		edh_rank: 50,
		release_date: '2021-06-15',
		usd_price: undefined
	};

	const cardNoRank: DecklistCard = {
		card_id: 'nr-1',
		card_name: 'No Rank Card',
		quantity: 1,
		card_type: 'Instant',
		rarity: 'uncommon',
		edh_rank: undefined,
		release_date: '2022-03-20',
		usd_price: '2.50'
	};

	describe('alphabetical sorting', () => {
		it('sorts cards alphabetically with commander first', () => {
			const cards = [solRing, commander, commandTower];
			const sorted = sortDecklistCards(cards, 'alphabetical');

			expect(sorted[0].card_name).toBe("Atraxa, Praetors' Voice");
			expect(sorted[1].card_name).toBe('Command Tower');
			expect(sorted[2].card_name).toBe('Sol Ring');
		});

		it('handles multiple commanders at the beginning', () => {
			const partner: DecklistCard = {
				...solRing,
				card_name: 'Partner Commander',
				is_commander: true
			};

			const cards = [solRing, commander, partner, commandTower];
			const sorted = sortDecklistCards(cards, 'alphabetical');

			// Both commanders should be first
			expect(sorted[0].is_commander).toBe(true);
			expect(sorted[1].is_commander).toBe(true);
			// Then alphabetical non-commanders
			expect(sorted[2].card_name).toBe('Command Tower');
			expect(sorted[3].card_name).toBe('Sol Ring');
		});
	});

	describe('value sorting', () => {
		it('sorts by USD price descending with commander first', () => {
			const cards = [commandTower, commander, solRing, expensiveCard];
			const sorted = sortDecklistCards(cards, 'value');

			expect(sorted[0].card_name).toBe("Atraxa, Praetors' Voice"); // Commander first
			expect(sorted[1].card_name).toBe('Expensive Artifact'); // 99.99
			expect(sorted[2].card_name).toBe('Sol Ring'); // 1.50
			expect(sorted[3].card_name).toBe('Command Tower'); // 0.25
		});

		it('places cards with no price at the end', () => {
			const cards = [cardNoPrice, solRing, commander];
			const sorted = sortDecklistCards(cards, 'value');

			expect(sorted[0].card_name).toBe("Atraxa, Praetors' Voice");
			expect(sorted[1].card_name).toBe('Sol Ring');
			expect(sorted[2].card_name).toBe('No Price Card');
		});
	});

	describe('EDH rank sorting', () => {
		it('sorts by EDH rank ascending with commander first', () => {
			const cards = [commandTower, commander, solRing, expensiveCard];
			const sorted = sortDecklistCards(cards, 'edh-rank');

			expect(sorted[0].card_name).toBe("Atraxa, Praetors' Voice"); // Commander
			expect(sorted[1].card_name).toBe('Sol Ring'); // Rank 2
			expect(sorted[2].card_name).toBe('Command Tower'); // Rank 3
			expect(sorted[3].card_name).toBe('Expensive Artifact'); // Rank 100
		});

		it('places cards with no EDH rank at the end', () => {
			const cards = [cardNoRank, solRing, commander];
			const sorted = sortDecklistCards(cards, 'edh-rank');

			expect(sorted[0].card_name).toBe("Atraxa, Praetors' Voice");
			expect(sorted[1].card_name).toBe('Sol Ring');
			expect(sorted[2].card_name).toBe('No Rank Card');
		});
	});

	describe('type grouping', () => {
		it('groups by card type with commander first', () => {
			const cards = [commandTower, solRing, commander, expensiveCard];
			const sorted = sortDecklistCards(cards, 'type');

			// Commander first
			expect(sorted[0].is_commander).toBe(true);

			// Then grouped by type (alphabetically within each group)
			// Artifact group
			expect(sorted[1].card_type).toBe('Artifact');
			expect(sorted[2].card_type).toBe('Artifact');

			// Land group
			expect(sorted[3].card_type).toBe('Land');
		});

		it('handles missing card types', () => {
			const noType: DecklistCard = {
				...solRing,
				card_name: 'No Type',
				card_type: undefined
			};

			const cards = [noType, commander, solRing];
			const sorted = sortDecklistCards(cards, 'type');

			expect(sorted[0].is_commander).toBe(true);
			expect(sorted[1].card_name).toBe('Sol Ring'); // Has type
			expect(sorted[2].card_name).toBe('No Type'); // No type goes last
		});
	});

	describe('commander-first invariant', () => {
		it('always places commanders first regardless of sort option', () => {
			const sortOptions: SortOption[] = ['alphabetical', 'value', 'edh-rank', 'type'];

			const cards = [solRing, commandTower, commander, expensiveCard];

			sortOptions.forEach((option) => {
				const sorted = sortDecklistCards(cards, option);
				expect(sorted[0].is_commander).toBe(true);
			});
		});
	});
});
