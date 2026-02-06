<script lang="ts">
	import type { InventoryItem } from '$lib/types/inventory';
	import { formatPrice } from '$lib/utils/format';
	import QuantityEditor from './QuantityEditor.svelte';
	import RemoveConfirmation from './RemoveConfirmation.svelte';
	import Toast from './Toast.svelte';
	import { Trash2 } from 'lucide-svelte';

	interface Props {
		items: InventoryItem[];
		loading?: boolean;
		onItemsChange?: (items: InventoryItem[]) => void;
	}

	let { items, loading = false, onItemsChange }: Props = $props();

	// Optimistic updates state
	let localItems = $state<InventoryItem[]>(items);
	let removingItemId = $state<number | null>(null);
	let toast = $state<{ message: string; type: 'success' | 'error' } | null>(null);

	// Update local items when props change
	$effect(() => {
		localItems = items;
	});

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

	/**
	 * Update quantity for an item
	 */
	async function handleQuantityUpdate(item: InventoryItem, newQuantity: number) {
		const originalQuantity = item.quantity;

		// Optimistic update
		localItems = localItems.map((i) => (i.id === item.id ? { ...i, quantity: newQuantity } : i));

		try {
			const response = await fetch(`/api/inventory/${item.id}`, {
				method: 'PATCH',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ quantity: newQuantity })
			});

			if (!response.ok) {
				throw new Error('Failed to update quantity');
			}

			const updatedItem = await response.json();

			// Update with server response
			localItems = localItems.map((i) => (i.id === item.id ? updatedItem : i));

			if (onItemsChange) {
				onItemsChange(localItems);
			}

			toast = { message: 'Quantity updated', type: 'success' };
		} catch (err) {
			// Rollback on failure
			localItems = localItems.map((i) => (i.id === item.id ? { ...i, quantity: originalQuantity } : i));

			toast = { message: 'Failed to update quantity', type: 'error' };
		}
	}

	/**
	 * Remove an item from inventory
	 */
	async function handleRemove(item: InventoryItem) {
		const originalItems = [...localItems];

		// Optimistic removal
		localItems = localItems.filter((i) => i.id !== item.id);

		try {
			const response = await fetch(`/api/inventory/${item.id}`, {
				method: 'DELETE'
			});

			if (!response.ok) {
				throw new Error('Failed to remove item');
			}

			if (onItemsChange) {
				onItemsChange(localItems);
			}

			toast = { message: `Removed ${item.card_name} from inventory`, type: 'success' };
		} catch (err) {
			// Rollback on failure
			localItems = originalItems;

			toast = { message: 'Failed to remove item', type: 'error' };
		} finally {
			removingItemId = null;
		}
	}

	function showRemoveConfirmation(itemId: number) {
		removingItemId = itemId;
	}

	function hideRemoveConfirmation() {
		removingItemId = null;
	}

	function dismissToast() {
		toast = null;
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
					<th>Actions</th>
				</tr>
			</thead>
			<tbody>
				{#each localItems as item (item.id)}
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
								<span class="font-beleren card-name">{item.card_name}</span>
								<span class="collector-number"
									>{item.set.toUpperCase()} {item.collector_number}</span
								>
							</div>
						</td>
						<td>
							<QuantityEditor
								initialQuantity={item.quantity}
								onSave={(newQuantity) => handleQuantityUpdate(item, newQuantity)}
							/>
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
						<td>
							<button
								class="remove-btn"
								onclick={() => showRemoveConfirmation(item.id)}
								title="Remove from inventory"
								data-testid="remove-btn-{item.id}"
							>
								<Trash2 size={18} />
							</button>
						</td>
					</tr>

					{#if removingItemId === item.id}
						<RemoveConfirmation
							cardName={item.card_name}
							setCode={item.set}
							collectorNumber={item.collector_number}
							onConfirm={() => handleRemove(item)}
							onCancel={hideRemoveConfirmation}
							show={true}
						/>
					{/if}
				{/each}
			</tbody>
		</table>
	</div>
{/if}

{#if toast}
	<Toast message={toast.message} type={toast.type} onDismiss={dismissToast} />
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

	.remove-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.5rem;
		background: transparent;
		border: none;
		border-radius: 0.375rem;
		color: #6b7280;
		cursor: pointer;
		transition: all 0.2s;
	}

	.remove-btn:hover {
		background: #fee2e2;
		color: #dc2626;
	}

	:global(.dark) .remove-btn {
		color: #9ca3af;
	}

	:global(.dark) .remove-btn:hover {
		background: #7f1d1d;
		color: #fca5a5;
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
