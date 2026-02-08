<script lang="ts">
	import type { InventoryResult } from '$lib/types/search';
	import { formatPrice } from '$lib/utils/priceFormatter';

	interface Props {
		result: InventoryResult;
		onViewDetails: (result: InventoryResult) => void;
	}

	let { result, onViewDetails }: Props = $props();

	const handleViewDetails = () => {
		onViewDetails(result);
	};

	// Fallback for missing image
	const hasImage = $derived(!!result.image_url);
</script>

<div class="inventory-result">
	<div class="card-image-container">
		{#if hasImage}
			<img
				src={result.image_url}
				alt="{result.card_name} from {result.set_name}"
				class="card-image"
			/>
		{:else}
			<div class="card-image-placeholder">
				<span class="card-name-text">{result.card_name}</span>
			</div>
		{/if}
	</div>

	<div class="card-details">
		<h3 class="card-name">{result.card_name}</h3>
		<div class="set-info">
			<span class="set-name">{result.set_name}</span>
			<span class="set-code">({result.set.toUpperCase()})</span>
			<span class="collector-number">#{result.collector_number}</span>
		</div>

		<div class="quantity-treatment">
			<span class="quantity">Qty: {result.quantity}</span>
			{#if result.treatment}
				<span class="treatment">{result.treatment}</span>
			{/if}
		</div>

		<div class="price-info">
			<div class="price-item">
				<span class="price-label">Unit:</span>
				<span class="price-value">{formatPrice(result.unit_price_cents)}</span>
			</div>
			<div class="price-item">
				<span class="price-label">Total:</span>
				<span class="price-value">{formatPrice(result.total_price_cents)}</span>
			</div>
		</div>

		<button onclick={handleViewDetails} class="view-details-btn">View Details</button>
	</div>
</div>

<style>
	.inventory-result {
		display: flex;
		gap: 1rem;
		padding: 1rem;
		background: white;
		border: 1px solid rgb(229 231 235);
		border-radius: 0.5rem;
		transition:
			box-shadow 0.2s,
			border-color 0.2s;
	}

	.inventory-result:hover {
		border-color: rgb(59 130 246);
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}

	:global(.dark) .inventory-result {
		background: rgb(31 41 55);
		border-color: rgb(55 65 81);
	}

	:global(.dark) .inventory-result:hover {
		border-color: rgb(96 165 250);
	}

	.card-image-container {
		flex-shrink: 0;
		width: 120px;
		height: 168px;
	}

	.card-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 0.375rem;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.card-image-placeholder {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgb(243 244 246);
		border: 2px dashed rgb(209 213 219);
		border-radius: 0.375rem;
		padding: 0.5rem;
		text-align: center;
	}

	:global(.dark) .card-image-placeholder {
		background: rgb(55 65 81);
		border-color: rgb(75 85 99);
	}

	.card-name-text {
		font-size: 0.875rem;
		font-weight: 600;
		color: rgb(107 114 128);
		word-wrap: break-word;
	}

	:global(.dark) .card-name-text {
		color: rgb(156 163 175);
	}

	.card-details {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.card-name {
		font-size: 1.125rem;
		font-weight: 700;
		color: rgb(17 24 39);
		margin: 0;
	}

	:global(.dark) .card-name {
		color: rgb(229 231 235);
	}

	.set-info {
		display: flex;
		gap: 0.5rem;
		align-items: center;
		flex-wrap: wrap;
		font-size: 0.875rem;
	}

	.set-name {
		color: rgb(55 65 81);
		font-weight: 500;
	}

	:global(.dark) .set-name {
		color: rgb(209 213 219);
	}

	.set-code {
		color: rgb(107 114 128);
		font-weight: 600;
		text-transform: uppercase;
	}

	:global(.dark) .set-code {
		color: rgb(156 163 175);
	}

	.collector-number {
		color: rgb(107 114 128);
	}

	:global(.dark) .collector-number {
		color: rgb(156 163 175);
	}

	.quantity-treatment {
		display: flex;
		gap: 1rem;
		font-size: 0.875rem;
	}

	.quantity {
		font-weight: 600;
		color: rgb(17 24 39);
	}

	:global(.dark) .quantity {
		color: rgb(229 231 235);
	}

	.treatment {
		padding: 0.125rem 0.5rem;
		background: rgb(219 234 254);
		color: rgb(29 78 216);
		border-radius: 0.25rem;
		font-weight: 500;
		font-size: 0.75rem;
	}

	:global(.dark) .treatment {
		background: rgb(30 58 138);
		color: rgb(191 219 254);
	}

	.price-info {
		display: flex;
		gap: 1.5rem;
		font-size: 0.875rem;
	}

	.price-item {
		display: flex;
		gap: 0.25rem;
	}

	.price-label {
		color: rgb(107 114 128);
	}

	:global(.dark) .price-label {
		color: rgb(156 163 175);
	}

	.price-value {
		font-weight: 600;
		color: rgb(17 24 39);
	}

	:global(.dark) .price-value {
		color: rgb(229 231 235);
	}

	.view-details-btn {
		align-self: flex-start;
		padding: 0.5rem 1rem;
		font-size: 0.875rem;
		font-weight: 600;
		color: white;
		background: rgb(59 130 246);
		border: none;
		border-radius: 0.375rem;
		cursor: pointer;
		transition: background 0.2s;
		margin-top: auto;
	}

	.view-details-btn:hover {
		background: rgb(37 99 235);
	}

	.view-details-btn:active {
		background: rgb(29 78 216);
	}

	/* Responsive design for mobile */
	@media (max-width: 768px) {
		.inventory-result {
			flex-direction: column;
		}

		.card-image-container {
			width: 100%;
			max-width: 200px;
			height: 280px;
			align-self: center;
		}

		.view-details-btn {
			width: 100%;
		}
	}
</style>
