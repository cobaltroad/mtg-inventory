<script lang="ts">
	import { base } from '$app/paths';
	import Toast from './Toast.svelte';

	const API_BASE = base;

	interface Card {
		id: string;
		name: string;
	}

	interface Printing {
		id: string;
		name: string;
		set: string;
		set_name: string;
		collector_number: string;
		image_url?: string;
		released_at: string;
	}

	interface Props {
		card: Card;
		open: boolean;
		onclose?: () => void;
	}

	type InventoryState = 'idle' | 'loading' | 'success' | 'error';

	// Treatment options for enhanced tracking
	const TREATMENT_OPTIONS = [
		'Normal',
		'Foil',
		'Etched',
		'Showcase',
		'Extended Art',
		'Borderless',
		'Full Art',
		'Retro Frame',
		'Textured Foil'
	];

	// Language options for enhanced tracking
	const LANGUAGE_OPTIONS = [
		'English',
		'Japanese',
		'German',
		'French',
		'Spanish',
		'Italian',
		'Portuguese',
		'Russian',
		'Korean',
		'Chinese Simplified',
		'Chinese Traditional'
	];

	// Helper function to format date in user's timezone
	function formatDateInTimeZone(timeZone: string, date = new Date()): string {
		const formatter = new Intl.DateTimeFormat('en-CA', {
			timeZone,
			year: 'numeric',
			month: '2-digit',
			day: '2-digit'
		});
		// "en-CA" with these options yields "YYYY-MM-DD"
		return formatter.format(date);
	}

	const userTimeZone = 'America/Detroit';

	let { card, open = $bindable(false), onclose }: Props = $props();

	let printings: Printing[] = $state([]);
	let loading = $state(false);
	let error = $state(false);
	let selectedPrinting: Printing | null = $state(null);
	let dialogElement = $state<HTMLDialogElement>();
	let inventoryState: InventoryState = $state('idle');
	let inventoryQuantity = $state(0);
	let inventoryError = $state('');
	let toastMessage = $state('');
	let showToast = $state(false);

	// Enhanced tracking form fields
	let acquiredDate = $state(formatDateInTimeZone(userTimeZone));
	let price = $state(0.0);
	let treatment = $state('Normal');
	let language = $state('English');

	function isResponseSuccessful(response: Response): boolean {
		// 304 Not Modified is considered successful - browser returns cached data automatically
		return response.ok || response.status === 304;
	}

	async function fetchPrintings() {
		loading = true;
		error = false;
		try {
			const res = await fetch(`${API_BASE}/api/cards/${card.id}/printings`);
			if (!isResponseSuccessful(res)) {
				throw new Error('Failed to fetch printings');
			}
			const data = await res.json();
			printings = data.printings || [];
		} catch {
			error = true;
			printings = [];
		} finally {
			loading = false;
		}
	}

	function handleClose() {
		open = false;
		if (onclose) {
			onclose();
		}
	}

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === dialogElement) {
			handleClose();
		}
	}

	function handleKeyDown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			handleClose();
		}
	}

	async function addToInventory() {
		if (!selectedPrinting) return;

		inventoryState = 'loading';
		inventoryError = '';

		const printingToAdd = selectedPrinting;

		try {
			const res = await fetch(`${API_BASE}/api/inventory`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					card_id: printingToAdd.id,
					quantity: 1,
					acquired_date: acquiredDate,
					price: price,
					treatment: treatment,
					language: language
				})
			});

			if (!res.ok) {
				inventoryState = 'error';
				inventoryError = 'Failed to add to inventory';
				return;
			}

			const data = await res.json();
			inventoryState = 'success';
			inventoryQuantity = data.quantity;

			// Show toast notification with printing details
			toastMessage = `Added ${printingToAdd.name} (${printingToAdd.set.toUpperCase()} #${printingToAdd.collector_number}) to inventory`;
			showToast = true;

			// Clear selection after successful add
			selectedPrinting = null;
			inventoryState = 'idle';
		} catch {
			inventoryState = 'error';
			inventoryError = 'Failed to add to inventory';
		}
	}

	$effect(() => {
		if (open && dialogElement) {
			dialogElement.showModal();
			fetchPrintings();
			// Reset inventory state when opening modal
			inventoryState = 'idle';
			inventoryError = '';
			inventoryQuantity = 0;
		} else if (dialogElement) {
			dialogElement.close();
		}
	});
</script>

<svelte:window on:keydown={handleKeyDown} />

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<dialog
		bind:this={dialogElement}
		aria-labelledby="modal-title"
		onclick={handleBackdropClick}
		data-testid="modal-backdrop"
	>
		<div class="modal-content" onclick={(e) => e.stopPropagation()} role="document">
			<div class="modal-header">
				<h2 id="modal-title">{card.name} - Printings</h2>
				<button class="close-button" onclick={handleClose} aria-label="Close">✕</button>
			</div>

			{#if loading}
				<div class="loading-container">
					<p>Loading printings...</p>
				</div>
			{:else if error}
				<div class="error-container">
					<p>Unable to load printings. Please try again.</p>
					<button onclick={fetchPrintings}>Retry</button>
				</div>
			{:else}
				<div class="modal-body">
					<div class="printings-list" data-testid="printings-list">
						{#each printings as printing (printing.id)}
							<div
								class="printing-item"
								data-testid="printing-item"
								role="button"
								tabindex="0"
								onmouseenter={() => (selectedPrinting = printing)}
								onfocus={() => (selectedPrinting = printing)}
							>
								<div class="printing-info">
									<span class="set-name">{printing.set_name}</span>
									<span class="set-code">({printing.set.toUpperCase()})</span>
									<span class="collector-number">#{printing.collector_number}</span>
								</div>
							</div>
						{/each}
					</div>

					{#if selectedPrinting && selectedPrinting.image_url}
						<div class="image-preview-area">
							<img
								src={selectedPrinting.image_url}
								alt="{selectedPrinting.name} from {selectedPrinting.set_name}"
							/>
							<div class="inventory-actions">
								<div class="form-field">
									<label for="acquired-date">Acquired Date</label>
									<input
										id="acquired-date"
										type="date"
										bind:value={acquiredDate}
										class="form-input"
									/>
								</div>

								<div class="form-field">
									<label for="price">Price</label>
									<input
										id="price"
										type="number"
										step="0.01"
										min="0"
										bind:value={price}
										class="form-input"
									/>
								</div>

								<div class="form-field">
									<label for="treatment">Treatment</label>
									<select id="treatment" bind:value={treatment} class="form-select">
										{#each TREATMENT_OPTIONS as option}
											<option value={option}>{option}</option>
										{/each}
									</select>
								</div>

								<div class="form-field">
									<label for="language">Language</label>
									<select id="language" bind:value={language} class="form-select">
										{#each LANGUAGE_OPTIONS as option}
											<option value={option}>{option}</option>
										{/each}
									</select>
								</div>

								{#if inventoryState === 'error'}
									<p class="error-message">{inventoryError}</p>
									<button class="inventory-button" onclick={addToInventory}>Retry</button>
								{:else}
									<button
										class="inventory-button"
										onclick={addToInventory}
										disabled={inventoryState === 'loading'}
									>
										{inventoryState === 'loading' ? 'Adding...' : 'Add to Inventory'}
									</button>
								{/if}
							</div>
						</div>
					{/if}
				</div>
			{/if}
		</div>
	</dialog>
{/if}

{#if showToast}
	<Toast
		message={toastMessage}
		type="success"
		onDismiss={() => {
			showToast = false;
		}}
	/>
{/if}

<style>
	dialog {
		border: none;
		border-radius: 12px;
		padding: 0;
		max-width: 90vw;
		width: 800px;
		max-height: 90vh;
		box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
		background: white;
	}

	dialog::backdrop {
		background: rgba(0, 0, 0, 0.5);
	}

	.modal-content {
		display: flex;
		flex-direction: column;
		height: 100%;
		max-height: 90vh;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem;
		border-bottom: 1px solid #e5e7eb;
		position: sticky;
		top: 0;
		background: white;
		z-index: 10;
	}

	.modal-header h2 {
		margin: 0;
		font-size: 1.5rem;
		font-weight: 600;
		color: #111827;
	}

	.close-button {
		background: none;
		border: none;
		font-size: 1.5rem;
		cursor: pointer;
		color: #6b7280;
		padding: 0.25rem 0.5rem;
		line-height: 1;
		border-radius: 4px;
		transition:
			background 0.2s,
			color 0.2s;
	}

	.close-button:hover {
		background: #f3f4f6;
		color: #111827;
	}

	.loading-container,
	.error-container {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 3rem;
		gap: 1rem;
	}

	.error-container p {
		color: #dc2626;
		font-weight: 500;
	}

	.error-container button {
		padding: 0.5rem 1rem;
		border: 1px solid #3b82f6;
		border-radius: 4px;
		background: white;
		color: #3b82f6;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 500;
		transition:
			background 0.2s,
			color 0.2s;
	}

	.error-container button:hover {
		background: #3b82f6;
		color: white;
	}

	.modal-body {
		display: flex;
		gap: 1rem;
		padding: 1rem;
		overflow: hidden;
		flex: 1;
	}

	.printings-list {
		flex: 1;
		overflow-y: auto;
		padding: 0.5rem;
		max-height: calc(90vh - 120px);
	}

	.printing-item {
		position: relative;
		padding: 0.75rem 1rem;
		border: 1px solid #e5e7eb;
		border-radius: 6px;
		margin-bottom: 0.5rem;
		cursor: pointer;
		transition:
			background 0.2s,
			border-color 0.2s;
	}

	.printing-item:hover {
		background: #f9fafb;
		border-color: #3b82f6;
	}

	.printing-info {
		display: flex;
		gap: 0.5rem;
		align-items: center;
	}

	.set-name {
		font-weight: 600;
		color: #111827;
		flex: 1;
	}

	.set-code {
		color: #6b7280;
		font-size: 0.875rem;
		text-transform: uppercase;
	}

	.collector-number {
		color: #6b7280;
		font-size: 0.875rem;
	}

	.image-preview-area {
		position: sticky;
		top: 0;
		width: 300px;
		max-height: calc(90vh - 120px);
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
		padding: 1rem;
		background: #f9fafb;
		border-radius: 8px;
	}

	.image-preview-area img {
		width: 100%;
		border-radius: 8px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.inventory-actions {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		align-items: center;
	}

	.inventory-button {
		width: 100%;
		padding: 0.75rem 1rem;
		border: 1px solid #3b82f6;
		border-radius: 6px;
		background: #3b82f6;
		color: white;
		cursor: pointer;
		font-size: 0.875rem;
		font-weight: 600;
		transition:
			background 0.2s,
			border-color 0.2s;
	}

	.inventory-button:hover:not(:disabled) {
		background: #2563eb;
		border-color: #2563eb;
	}

	.inventory-button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.error-message {
		color: #dc2626;
		font-weight: 500;
		font-size: 0.875rem;
		text-align: center;
		margin: 0;
	}

	.form-field {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.form-field label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.form-input,
	.form-select {
		width: 100%;
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 0.875rem;
		background: white;
		color: #111827;
		transition: border-color 0.2s;
	}

	.form-input:focus,
	.form-select:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-select {
		cursor: pointer;
	}

	@media (max-width: 768px) {
		dialog {
			width: 95vw;
			max-width: 95vw;
		}

		.modal-body {
			flex-direction: column;
		}

		.image-preview-area {
			width: 100%;
		}
	}
</style>
