<script lang="ts">
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
		<table class="inventory-table">
			<thead>
				<tr>
					<th>Image</th>
					<th>Card Name</th>
					<th>Quantity</th>
					<th>Value</th>
					<th>Details</th>
				</tr>
			</thead>
			<tbody>
				{#each items as item (item.id)}
					<tr>
						<td>
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
						</td>
						<td>
							<div class="card-name-cell">
								<span class="card-name">{item.card_name}</span>
								<span class="collector-number"
									>{item.set.toUpperCase()} {item.collector_number}</span
								>
							</div>
						</td>
						<td>
							<span class="quantity-badge">{item.quantity}x</span>
						</td>
						<td> TBD </td>
						<td>
							<div class="details-cell">
								{#if item.treatment}
									<span class="detail-badge">{item.treatment}</span>
								{/if}
								{#if item.language}
									<span class="detail-badge">{item.language}</span>
								{/if}
								{#if item.acquired_date}
									<span class="detail-text">Acquired: {item.acquired_date}</span>
									<span class="detail-text">@ {formatPrice(item.acquired_price_cents)}</span>
								{/if}
							</div>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
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

	.inventory-table {
		width: 100%;
		border-collapse: collapse;
		background: white;
	}

	.inventory-table thead {
		background: #f9fafb;
		border-bottom: 2px solid #e5e7eb;
	}

	.inventory-table th {
		padding: 0.75rem 1rem;
		text-align: left;
		font-weight: 600;
		color: #374151;
		font-size: 0.875rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.inventory-table tbody tr {
		border-bottom: 1px solid #e5e7eb;
		transition: background 0.2s;
	}

	.inventory-table tbody tr:hover {
		background: #f9fafb;
	}

	.inventory-table td {
		padding: 1rem;
		vertical-align: middle;
	}

	:global(.dark) .inventory-table {
		background: #1f2937;
	}

	:global(.dark) .inventory-table thead {
		background: #374151;
		border-bottom-color: #4b5563;
	}

	:global(.dark) .inventory-table th {
		color: #e5e7eb;
	}

	:global(.dark) .inventory-table tbody tr {
		border-bottom-color: #374151;
	}

	:global(.dark) .inventory-table tbody tr:hover {
		background: #374151;
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

	:global(.dark) .card-name {
		color: #e5e7eb;
	}

	.collector-number {
		font-size: 0.875rem;
		color: #6b7280;
	}

	:global(.dark) .collector-number {
		color: #9ca3af;
	}

	.set-cell {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.set-name {
		font-weight: 500;
	}

	:global(.dark) .set-name {
		color: #e5e7eb;
	}

	.set-code {
		font-size: 0.875rem;
		color: #6b7280;
	}

	:global(.dark) .set-code {
		color: #9ca3af;
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
