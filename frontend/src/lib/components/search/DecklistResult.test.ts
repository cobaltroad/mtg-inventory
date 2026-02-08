import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { render, screen, cleanup } from '@testing-library/svelte';
import DecklistResult from './DecklistResult.svelte';
import type { DecklistResult as DecklistResultType } from '$lib/types/search';

// ---------------------------------------------------------------------------
// Mock Data
// ---------------------------------------------------------------------------
const MOCK_RESULT_SINGLE_MATCH: DecklistResultType = {
	commander_id: 1,
	commander_name: "Atraxa, Praetors' Voice",
	commander_rank: 5,
	card_matches: [{ card_name: 'Sol Ring', quantity: 1 }],
	match_count: 1
};

const MOCK_RESULT_MULTIPLE_MATCHES: DecklistResultType = {
	commander_id: 2,
	commander_name: 'Chulane, Teller of Tales',
	commander_rank: 12,
	card_matches: [
		{ card_name: 'Sol Ring', quantity: 1 },
		{ card_name: 'Mana Crypt', quantity: 1 },
		{ card_name: 'Arcane Signet', quantity: 1 }
	],
	match_count: 3
};

const MOCK_RESULT_MANY_MATCHES: DecklistResultType = {
	commander_id: 3,
	commander_name: 'The Ur-Dragon',
	commander_rank: 20,
	card_matches: [
		{ card_name: 'Sol Ring', quantity: 1 },
		{ card_name: 'Mana Crypt', quantity: 1 },
		{ card_name: 'Arcane Signet', quantity: 1 },
		{ card_name: 'Command Tower', quantity: 1 },
		{ card_name: 'Chromatic Lantern', quantity: 1 },
		{ card_name: 'Smothering Tithe', quantity: 1 }
	],
	match_count: 6
};

beforeEach(() => {
	// Reset any state between tests
});

afterEach(() => {
	cleanup();
});

// ---------------------------------------------------------------------------
// Tests: Basic Rendering
// ---------------------------------------------------------------------------
describe('DecklistResult - Basic Rendering', () => {
	it('renders commander name', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		expect(screen.getByText("Atraxa, Praetors' Voice")).toBeInTheDocument();
	});

	it('renders commander rank', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		expect(screen.getByText('Rank #5')).toBeInTheDocument();
	});

	it('renders match count', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		expect(screen.getByText(/1 match/i)).toBeInTheDocument();
	});

	it('renders match count with plural', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_MULTIPLE_MATCHES } });
		expect(screen.getByText(/3 matches/i)).toBeInTheDocument();
	});

	it('displays card matches with quantities', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		expect(screen.getByText(/Sol Ring.*1x/)).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Multiple Card Matches
// ---------------------------------------------------------------------------
describe('DecklistResult - Multiple Card Matches', () => {
	it('displays all card matches when count is less than 5', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_MULTIPLE_MATCHES } });
		expect(screen.getByText(/Sol Ring.*1x/)).toBeInTheDocument();
		expect(screen.getByText(/Mana Crypt.*1x/)).toBeInTheDocument();
		expect(screen.getByText(/Arcane Signet.*1x/)).toBeInTheDocument();
	});

	it('displays first 4 matches and "+X more" when count is 5 or more', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_MANY_MATCHES } });
		expect(screen.getByText(/Sol Ring.*1x/)).toBeInTheDocument();
		expect(screen.getByText(/Mana Crypt.*1x/)).toBeInTheDocument();
		expect(screen.getByText(/Arcane Signet.*1x/)).toBeInTheDocument();
		expect(screen.getByText(/Command Tower.*1x/)).toBeInTheDocument();
		expect(screen.getByText(/\+2 more/i)).toBeInTheDocument();
	});

	it('does not display "+X more" when count is 4 or less', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_MULTIPLE_MATCHES } });
		expect(screen.queryByText(/\+.*more/i)).not.toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Navigation Links
// ---------------------------------------------------------------------------
describe('DecklistResult - Navigation Links', () => {
	it('renders commander name as a link', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		const link = screen.getByRole('link', { name: /Atraxa, Praetors' Voice/i });
		expect(link).toBeInTheDocument();
		expect(link).toHaveAttribute('href', '/metagame/edh/1');
	});

	it('renders "View Decklist" link', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		const link = screen.getByRole('link', { name: /View Decklist/i });
		expect(link).toBeInTheDocument();
		expect(link).toHaveAttribute('href', '/metagame/edh/1');
	});

	it('links use correct commander_id', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_MULTIPLE_MATCHES } });
		const links = screen.getAllByRole('link');
		links.forEach((link) => {
			expect(link).toHaveAttribute('href', '/metagame/edh/2');
		});
	});
});

// ---------------------------------------------------------------------------
// Tests: Layout and Styling
// ---------------------------------------------------------------------------
describe('DecklistResult - Layout', () => {
	it('renders with proper container class', () => {
		const { container } = render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		expect(container.querySelector('.decklist-result')).toBeInTheDocument();
	});

	it('has commander info section', () => {
		const { container } = render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		expect(container.querySelector('.commander-info')).toBeInTheDocument();
	});

	it('has card matches section', () => {
		const { container } = render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		expect(container.querySelector('.card-matches')).toBeInTheDocument();
	});
});

// ---------------------------------------------------------------------------
// Tests: Accessibility
// ---------------------------------------------------------------------------
describe('DecklistResult - Accessibility', () => {
	it('has accessible heading for commander name', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		const heading = screen.getByRole('heading', { name: /Atraxa, Praetors' Voice/i });
		expect(heading).toBeInTheDocument();
	});

	it('links have proper aria-labels', () => {
		render(DecklistResult, { props: { result: MOCK_RESULT_SINGLE_MATCH } });
		const commanderLink = screen.getByRole('link', { name: /Atraxa, Praetors' Voice/i });
		const viewLink = screen.getByRole('link', { name: /View Decklist/i });
		expect(commanderLink).toBeInTheDocument();
		expect(viewLink).toBeInTheDocument();
	});
});
