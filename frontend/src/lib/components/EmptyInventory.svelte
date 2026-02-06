<script lang="ts">
	import { getContext } from 'svelte';

	const openSearchDrawer = getContext<() => void>('openSearchDrawer');

	function handleSearchClick() {
		openSearchDrawer();
	}
</script>

<div class="empty-state">
	<div class="empty-icon">📦</div>
	<h2>Your inventory is empty</h2>
	<p>Start building your collection by searching for cards and adding them to your inventory.</p>
	<button class="cta-button" onclick={handleSearchClick}>Search for Cards</button>
</div>

<style>
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		text-align: center;
		min-height: 400px;
	}

	.empty-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
		opacity: 0.6;
	}

	h2 {
		font-size: 1.5rem;
		font-weight: 700;
		color: #111827;
		margin: 0 0 0.5rem;
	}

	p {
		color: #6b7280;
		font-size: 1rem;
		margin: 0 0 1.5rem;
		max-width: 500px;
	}

	.cta-button {
		display: inline-block;
		padding: 0.75rem 1.5rem;
		background: #3b82f6;
		color: white;
		text-decoration: none;
		border: none;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		cursor: pointer;
		transition: background 0.2s;
	}

	.cta-button:hover {
		background: #2563eb;
	}

	:global(.dark) .empty-state h2 {
		color: #f9fafb;
	}

	:global(.dark) .empty-state p {
		color: #9ca3af;
	}
</style>
