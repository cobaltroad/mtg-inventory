<script lang="ts">
	import {
		Table,
		TableBody,
		TableBodyCell,
		TableBodyRow,
		TableHead,
		TableHeadCell
	} from 'flowbite-svelte';
	import type { InventoryItem } from '$lib/types/inventory';
	import { formatPrice } from '$lib/utils/format';

	interface Props {
		items: InventoryItem[];
		loading?: boolean;
	}

	let { items, loading = false }: Props = $props();

	/**
	 * Track image loading states for lazy-loaded card images
	 */
	let imageStates = $state<Record<number, { loaded: boolean; error: boolean }>>({});

	/**
	 * Handle successful image load
	 */
	function handleImageLoad(id: number) {
		imageStates[id] = { loaded: true, error: false };
	}

	/**
	 * Handle image load error
	 */
	function handleImageError(id: number) {
		imageStates[id] = { loaded: false, error: true };
	}
</script>

{#if loading}
	<div class="loading-container" data-testid="loading-state">
		<div class="spinner"></div>
		<p>Loading inventory...</p>
	</div>
{:else if items.length === 0}
	<div class="empty-container" data-testid="empty-state">
		<p>No items in your inventory</p>
	</div>
{:else}
	<div class="table-container">
		<Table hoverable={true}>
			<TableHead>
				<TableHeadCell>Image</TableHeadCell>
				<TableHeadCell>Card Name</TableHeadCell>
				<TableHeadCell>Set</TableHeadCell>
				<TableHeadCell>Quantity</TableHeadCell>
				<TableHeadCell>Price</TableHeadCell>
				<TableHeadCell>Details</TableHeadCell>
			</TableHead>
			<TableBody>
				{#each items as item (item.id)}
					<TableBodyRow>
						<TableBodyCell>
							<div class="image-cell">
								{#if !imageStates[item.id]?.loaded && !imageStates[item.id]?.error}
									<div class="image-placeholder">Loading...</div>
								{/if}
								{#if imageStates[item.id]?.error}
									<div class="image-placeholder error">No image</div>
								{/if}
								<img
									src={item.image_url}
									alt={item.card_name}
									loading="lazy"
									onload={() => handleImageLoad(item.id)}
									onerror={() => handleImageError(item.id)}
									style:display={imageStates[item.id]?.loaded ? 'block' : 'none'}
									class="card-thumbnail"
								/>
							</div>
						</TableBodyCell>
						<TableBodyCell>
							<div class="card-name-cell">
								<span class="card-name">{item.card_name}</span>
								<span class="collector-number">#{item.collector_number}</span>
							</div>
						</TableBodyCell>
						<TableBodyCell>
							<div class="set-cell">
								<span class="set-name">{item.set_name}</span>
								<span class="set-code">({item.set.toUpperCase()})</span>
							</div>
						</TableBodyCell>
						<TableBodyCell>
							<span class="quantity-badge">{item.quantity}</span>
						</TableBodyCell>
						<TableBodyCell>
							{formatPrice(item.acquired_price_cents)}
						</TableBodyCell>
						<TableBodyCell>
							<div class="details-cell">
								{#if item.treatment}
									<span class="detail-badge">{item.treatment}</span>
								{/if}
								{#if item.language}
									<span class="detail-badge">{item.language}</span>
								{/if}
								{#if item.acquired_date}
									<span class="detail-text">Acquired: {item.acquired_date}</span>
								{/if}
							</div>
						</TableBodyCell>
					</TableBodyRow>
				{/each}
			</TableBody>
		</Table>
	</div>
{/if}

<style>
	.loading-container,
	.empty-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 4rem 2rem;
		min-height: 400px;
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid #e5e7eb;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.loading-container p,
	.empty-container p {
		margin-top: 1rem;
		color: #6b7280;
		font-size: 1rem;
	}

	.table-container {
		overflow-x: auto;
		border-radius: 0.5rem;
		box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
	}

	.image-cell {
		width: 80px;
		height: 112px;
		position: relative;
	}

	.card-thumbnail {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 0.375rem;
	}

	.image-placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		background: #f3f4f6;
		border-radius: 0.375rem;
		color: #6b7280;
		font-size: 0.75rem;
		text-align: center;
		padding: 0.5rem;
	}

	.image-placeholder.error {
		background: #fee2e2;
		color: #991b1b;
	}

	.card-name-cell {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.card-name {
		font-weight: 600;
		color: #111827;
	}

	.collector-number {
		font-size: 0.875rem;
		color: #6b7280;
	}

	.set-cell {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.set-name {
		font-weight: 500;
	}

	.set-code {
		font-size: 0.875rem;
		color: #6b7280;
	}

	.quantity-badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-width: 2rem;
		padding: 0.25rem 0.5rem;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 9999px;
		font-weight: 600;
		font-size: 0.875rem;
	}

	.details-cell {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.detail-badge {
		display: inline-block;
		padding: 0.125rem 0.5rem;
		background: #dbeafe;
		color: #1e40af;
		border-radius: 0.25rem;
		font-size: 0.75rem;
		font-weight: 500;
	}

	.detail-text {
		font-size: 0.75rem;
		color: #6b7280;
	}

	@media (max-width: 768px) {
		.table-container {
			font-size: 0.875rem;
		}

		.image-cell {
			width: 60px;
			height: 84px;
		}
	}
</style>
