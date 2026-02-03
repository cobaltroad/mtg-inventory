<script lang="ts">
	import type { InventoryItem as InventoryItemType } from '$lib/types/inventory';

	interface Props {
		item: InventoryItemType;
	}

	let { item }: Props = $props();
	let imageLoaded = $state(false);
	let imageError = $state(false);

	function handleImageLoad() {
		imageLoaded = true;
	}

	function handleImageError() {
		imageError = true;
	}

	function formatPrice(cents: number | null | undefined): string {
		if (cents === null || cents === undefined) return 'N/A';
		return `$${(cents / 100).toFixed(2)}`;
	}
</script>

<div class="inventory-item">
	<div class="card-image">
		{#if !imageLoaded && !imageError}
			<div class="image-placeholder">Loading...</div>
		{/if}
		{#if imageError}
			<div class="image-placeholder error">Image unavailable</div>
		{/if}
		<img
			src={item.image_url}
			alt={item.card_name}
			loading="lazy"
			onload={handleImageLoad}
			onerror={handleImageError}
			style:display={imageLoaded ? 'block' : 'none'}
		/>
	</div>
	<div class="card-details">
		<h3 class="card-name">{item.card_name}</h3>
		<div class="card-info">
			<span class="set-info">{item.set_name} ({item.set.toUpperCase()})</span>
			<span class="collector-number">#{item.collector_number}</span>
		</div>
		<div class="quantity">Quantity: <strong>{item.quantity}</strong></div>
		{#if item.treatment || item.language}
			<div class="enhanced-info">
				{#if item.treatment}
					<span class="treatment">{item.treatment}</span>
				{/if}
				{#if item.language}
					<span class="language">{item.language}</span>
				{/if}
			</div>
		{/if}
		{#if item.acquired_date || item.acquired_price_cents}
			<div class="acquisition-info">
				{#if item.acquired_date}
					<span class="acquired-date">Acquired: {item.acquired_date}</span>
				{/if}
				{#if item.acquired_price_cents !== null && item.acquired_price_cents !== undefined}
					<span class="acquired-price">Price: {formatPrice(item.acquired_price_cents)}</span>
				{/if}
			</div>
		{/if}
	</div>
</div>

<style>
	.inventory-item {
		display: flex;
		gap: 1rem;
		padding: 1rem;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		background: white;
		transition: box-shadow 0.2s;
	}

	.inventory-item:hover {
		box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
	}

	.card-image {
		flex-shrink: 0;
		width: 146px;
		height: 204px;
		position: relative;
	}

	.card-image img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 8px;
	}

	.image-placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f3f4f6;
		border-radius: 8px;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.image-placeholder.error {
		background: #fee2e2;
		color: #991b1b;
	}

	.card-details {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.card-name {
		font-size: 1.25rem;
		font-weight: 700;
		margin: 0;
		color: #111827;
	}

	.card-info {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		color: #6b7280;
		font-size: 0.875rem;
	}

	.set-info {
		font-weight: 500;
	}

	.collector-number {
		color: #9ca3af;
	}

	.quantity {
		font-size: 0.875rem;
		color: #374151;
	}

	.quantity strong {
		color: #111827;
		font-size: 1rem;
	}

	.enhanced-info {
		display: flex;
		gap: 0.5rem;
		font-size: 0.75rem;
	}

	.treatment,
	.language {
		padding: 0.25rem 0.5rem;
		border-radius: 4px;
		background: #dbeafe;
		color: #1e40af;
	}

	.acquisition-info {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		font-size: 0.875rem;
		color: #6b7280;
		margin-top: auto;
	}

	.acquired-date,
	.acquired-price {
		display: block;
	}
</style>
