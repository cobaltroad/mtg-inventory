<script lang="ts">
	import { base } from '$app/paths';
	import { invalidate } from '$app/navigation';
	import {
		Dialog,
		Portal,
		Combobox,
		useListCollection,
		type ComboboxRootProps
	} from '@skeletonlabs/skeleton-svelte';
	import { X } from 'lucide-svelte';
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
		finishes?: string[];
	}

	interface Props {
		card: Card;
		open: boolean;
		onclose?: () => void;
	}

	type InventoryState = 'idle' | 'loading' | 'success' | 'error';

	// Finish options aligned with Scryfall API
	const FINISH_OPTIONS = ['nonfoil', 'foil', 'etched'];

	// Language options for enhanced tracking
	const LANGUAGE_OPTIONS = [
		{ label: 'English', value: 'English' },
		{ label: 'Japanese', value: 'Japanese' },
		{ label: 'German', value: 'German' },
		{ label: 'French', value: 'French' },
		{ label: 'Spanish', value: 'Spanish' },
		{ label: 'Italian', value: 'Italian' },
		{ label: 'Portuguese', value: 'Portuguese' },
		{ label: 'Russian', value: 'Russian' },
		{ label: 'Korean', value: 'Korean' },
		{ label: 'Chinese Simplified', value: 'Chinese Simplified' },
		{ label: 'Chinese Traditional', value: 'Chinese Traditional' }
	];

	// Combobox state and collection for language selection
	let languageItems = $state(LANGUAGE_OPTIONS);

	const languageCollection = $derived(
		useListCollection({
			items: languageItems,
			itemToString: (item) => item.label,
			itemToValue: (item) => item.value
		})
	);

	const onLanguageOpenChange = () => {
		languageItems = LANGUAGE_OPTIONS;
	};

	const onLanguageInputValueChange: ComboboxRootProps['onInputValueChange'] = (event) => {
		const inputValue = event.inputValue;
		const filtered = LANGUAGE_OPTIONS.filter((item) =>
			item.value.toLowerCase().includes(inputValue.toLowerCase())
		);
		if (filtered.length > 0) {
			languageItems = filtered;
			// If there's an exact match (case-insensitive), update the language
			const exactMatch = filtered.find(
				(item) => item.value.toLowerCase() === inputValue.toLowerCase()
			);
			if (exactMatch) {
				language = exactMatch.value;
			}
		} else {
			languageItems = LANGUAGE_OPTIONS;
		}
	};

	const onLanguageValueChange: ComboboxRootProps['onValueChange'] = (event) => {
		const selected = event.value[0];
		if (selected) {
			language = selected;
		}
	};

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
	let inventoryState: InventoryState = $state('idle');
	let inventoryQuantity = $state(0);
	let inventoryError = $state('');
	let toastMessage = $state('');
	let toastType = $state<'success' | 'error'>('success');
	let showToast = $state(false);

	// Enhanced tracking form fields
	let acquiredDate = $state(formatDateInTimeZone(userTimeZone));
	let price = $state(0.0);
	let finish = $state('nonfoil');
	let language = $state('English');

	// Validation state
	let invalidField = $state<string | null>(null);
	let validationToastMessage = $state('');
	let showValidationToast = $state(false);

	// Collapsible optional fields state
	let showOptionalFields = $state(true);

	// Issue #138: Filter finish options based on available finishes for selected printing
	// Derived value that returns available finishes for the selected printing
	// Falls back to all options if finishes data is missing/empty
	let availableFinishes = $derived.by(() => {
		if (!selectedPrinting) return FINISH_OPTIONS;
		if (!selectedPrinting.finishes || selectedPrinting.finishes.length === 0) {
			return FINISH_OPTIONS;
		}
		return selectedPrinting.finishes;
	});

	// Helper function to get the default finish based on priority: nonfoil > foil > etched
	function getDefaultFinish(finishes: string[]): string {
		if (finishes.includes('nonfoil')) return 'nonfoil';
		if (finishes.includes('foil')) return 'foil';
		if (finishes.includes('etched')) return 'etched';
		return 'nonfoil'; // Fallback
	}

	// Track previous printing to detect changes
	let previousPrintingId: string | null = $state(null);

	// Effect to reset finish selection when selected printing changes
	$effect(() => {
		if (selectedPrinting) {
			// If printing changed (new printing selected)
			if (previousPrintingId !== selectedPrinting.id) {
				// Always reset to default finish when changing printings
				finish = getDefaultFinish(availableFinishes);
				previousPrintingId = selectedPrinting.id;
			}
		}
	});

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
		selectedPrinting = null; // Reset selection for next open
		if (onclose) {
			onclose();
		}
	}

	function validateForm(): string | null {
		// Validate date not in future
		const today = formatDateInTimeZone(userTimeZone);
		if (acquiredDate > today) {
			invalidField = 'acquired-date';
			return 'Acquired date cannot be in the future';
		}

		// Validate price is numeric
		if (isNaN(price) || price === null || price === undefined || price.toString() === '') {
			invalidField = 'price';
			return 'Price must be a valid number';
		}

		// Validate price >= 0
		if (price < 0) {
			invalidField = 'price';
			return 'Price must be $0.00 or greater';
		}

		return null; // Valid
	}

	function clearValidationError(fieldId: string) {
		if (invalidField === fieldId) {
			invalidField = null;
		}
	}

	async function addToInventory() {
		if (!selectedPrinting) return;

		// Run validation before submitting
		const validationError = validateForm();
		if (validationError) {
			// Show validation error in toast
			validationToastMessage = validationError;
			showValidationToast = true;
			return;
		}

		// Clear any validation errors
		invalidField = null;

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
					price: parseFloat(price.toString()),
					finish: finish,
					language: language
				})
			});

			if (!res.ok) {
				const errorData = await res.json();
				inventoryState = 'error';
				inventoryError = errorData.errors
					? `Failed to add to inventory: ${errorData.errors.join(', ')}`
					: 'Failed to add to inventory';
				toastMessage = inventoryError;
				toastType = 'error';
				showToast = true;
				return;
			}

			const data = await res.json();
			inventoryState = 'success';
			inventoryQuantity = data.quantity;

			// Show toast notification with printing details
			toastMessage = `Added ${printingToAdd.name} (${printingToAdd.set.toUpperCase()} #${printingToAdd.collector_number}) to inventory`;
			toastType = 'success';
			showToast = true;

			// Refresh the inventory page to show the new item
			try {
				await invalidate(`${API_BASE}/api/inventory`);
			} catch (e) {
				// Silently fail if invalidate is not available (e.g., in tests)
				console.debug('Could not invalidate inventory cache:', e);
			}

			// Reset form to defaults after successful add
			selectedPrinting = null;
			acquiredDate = formatDateInTimeZone(userTimeZone);
			price = 0.0;
			finish = 'nonfoil';
			language = 'English';
			inventoryState = 'idle';

			// Close the modal after successful add
			open = false;
		} catch {
			inventoryState = 'error';
			inventoryError = 'Failed to add to inventory. Please check your connection and try again.';
			toastMessage = inventoryError;
			toastType = 'error';
			showToast = true;
		}
	}

	$effect(() => {
		if (open) {
			// Reset state to prevent stale data (fixes #129)
			selectedPrinting = null;
			printings = [];
			fetchPrintings();
			// Reset inventory state when opening drawer
			inventoryState = 'idle';
			inventoryError = '';
			inventoryQuantity = 0;
		}
	});

	// Auto-select the first printing when printings are loaded
	$effect(() => {
		if (printings.length > 0 && !selectedPrinting) {
			selectedPrinting = printings[0];
		}
	});
</script>

<Dialog
	{open}
	onOpenChange={(details) => {
		open = details.open;
		if (!details.open) {
			handleClose();
		}
	}}
	closeOnEscape={true}
	trapFocus={false}
	closeOnInteractOutside={false}
>
	<Portal>
		<Dialog.Backdrop
			class="data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-50 bg-black/50 transition-opacity"
		/>
		<Dialog.Positioner class="fixed inset-0 z-50 flex justify-start">
			<Dialog.Content
				class="drawer-container data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:slide-out-to-left data-[state=open]:slide-in-from-left flex h-screen w-full flex-col bg-white shadow-xl transition-transform md:w-[600px] dark:bg-gray-800"
				data-testid="modal-backdrop"
				role="dialog"
				aria-label="Card printings"
			>
				<div class="drawer-header">
					<Dialog.Title class="text-xl font-bold text-gray-900 dark:text-gray-100"
						>{card.name} - Printings</Dialog.Title
					>
					<Dialog.CloseTrigger
						class="rounded-md p-2 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-700 dark:hover:text-gray-100"
						aria-label="Close card printings drawer"
					>
						<X class="h-5 w-5" />
					</Dialog.CloseTrigger>
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
									onclick={(e) => {
										e.stopPropagation();
										selectedPrinting = printing;
									}}
									onkeydown={(e) => {
										if (e.key === 'Enter' || e.key === ' ') {
											e.preventDefault();
											e.stopPropagation();
											selectedPrinting = printing;
										}
									}}
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
									<!-- Finish Selection -->
									<div class="form-group">
										<label class="form-field-label">Finish</label>
										<div class="finish-options" onclick={(e) => e.stopPropagation()}>
											{#each availableFinishes as finishOption}
												<label class="finish-option">
													<input
														type="radio"
														name="finish"
														value={finishOption}
														bind:group={finish}
														checked={finish === finishOption}
													/>
													<span>{finishOption.charAt(0).toUpperCase() + finishOption.slice(1)}</span>
												</label>
											{/each}
										</div>
									</div>

									<!-- Optional Fields Toggle -->
									<button
										type="button"
										class="optional-fields-toggle"
										onclick={(e) => {
											e.stopPropagation();
											showOptionalFields = !showOptionalFields;
										}}
									>
										{showOptionalFields ? '▼' : '▶'} Additional Details
									</button>

									{#if showOptionalFields}
										<div class="optional-fields">
											<div class="form-field">
												<label for="acquired-date">Acquired Date</label>
												<input
													id="acquired-date"
													type="date"
													bind:value={acquiredDate}
													class="form-input {invalidField === 'acquired-date' ? 'invalid' : ''}"
													oninput={() => clearValidationError('acquired-date')}
													onclick={(e) => e.stopPropagation()}
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
													class="form-input {invalidField === 'price' ? 'invalid' : ''}"
													oninput={() => clearValidationError('price')}
													onclick={(e) => e.stopPropagation()}
												/>
											</div>

											<div class="form-field" style="position: relative; z-index: 9999;">
												<label class="form-field-label" for="language-select">Language</label>
												<select
													id="language-select"
													bind:value={language}
													class="form-select"
													style="position: relative; z-index: 9999;"
													onclick={(e) => e.stopPropagation()}
													onmousedown={(e) => e.stopPropagation()}
												>
													{#each LANGUAGE_OPTIONS as option}
														<option value={option.value}>{option.label}</option>
													{/each}
												</select>
											</div>
										</div>
									{/if}

									<button
										type="button"
										class="inventory-button"
										onclick={(e) => {
											e.stopPropagation();
											addToInventory();
										}}
										disabled={inventoryState === 'loading'}
									>
										{inventoryState === 'loading' ? 'Adding...' : 'Add to Inventory'}
									</button>
								</div>
							</div>
						{/if}
					</div>
				{/if}
			</Dialog.Content>
		</Dialog.Positioner>
	</Portal>
</Dialog>

{#if showToast}
	<Toast
		message={toastMessage}
		type={toastType}
		onDismiss={() => {
			showToast = false;
		}}
	/>
{/if}

{#if showValidationToast}
	<Toast
		message={validationToastMessage}
		type="error"
		onDismiss={() => {
			showValidationToast = false;
		}}
	/>
{/if}

<style>
	.drawer-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1rem;
		border-bottom: 1px solid #e5e7eb;
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
		min-height: 0; /* Allow flex child to shrink */
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
		color: #787b84;
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
		flex: 1;
		width: 300px;
		min-height: 0; /* Allow flex child to shrink */
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
		max-height: 400px;
		object-fit: contain;
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

	.form-field {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.form-field label,
	.form-field-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
	}

	.form-input {
		width: 100%;
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		font-size: 0.875rem;
		background: white;
		color: #111827;
		transition: border-color 0.2s;
	}

	.form-input:focus {
		outline: none;
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.form-input.invalid {
		border-color: #dc2626;
		outline: 2px solid rgba(220, 38, 38, 0.2);
	}

	/* Combobox Styling */
	:global(.language-combobox) {
		width: 100%;
	}

	:global(.combobox-control) {
		display: flex;
		align-items: center;
		gap: 0.25rem;
		width: 100%;
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		background: white;
		transition: border-color 0.2s;
	}

	:global(.combobox-control:focus-within) {
		border-color: #3b82f6;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	:global(.combobox-input) {
		flex: 1;
		border: none;
		outline: none;
		font-size: 0.875rem;
		color: #111827;
		background: transparent;
	}

	:global(.combobox-trigger) {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.25rem;
		cursor: pointer;
		color: #6b7280;
	}

	:global(.combobox-positioner) {
		z-index: 1000;
	}

	:global(.combobox-content) {
		max-height: 300px;
		overflow-y: auto;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		background: white;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
	}

	:global(.combobox-item) {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.5rem 0.75rem;
		cursor: pointer;
		font-size: 0.875rem;
		color: #374151;
		transition: background 0.2s;
	}

	:global(.combobox-item:hover),
	:global(.combobox-item[data-highlighted]) {
		background: #f3f4f6;
	}

	:global(.combobox-item[data-state='checked']) {
		background: #eff6ff;
		color: #1e40af;
		font-weight: 500;
	}

	/* Optional Fields Toggle */
	.optional-fields-toggle {
		width: 100%;
		padding: 0.5rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		background: white;
		color: #6b7280;
		font-size: 0.875rem;
		font-weight: 500;
		text-align: left;
		cursor: pointer;
		transition:
			background 0.2s,
			border-color 0.2s;
	}

	.optional-fields-toggle:hover {
		background: #f9fafb;
		border-color: #9ca3af;
	}

	.optional-fields {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	/* Form Group Styles */
	.form-group {
		width: 100%;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	/* Finish Options (Radio Group styled as Segmented Control) */
	.finish-options {
		display: flex;
		gap: 0.5rem;
		width: 100%;
	}

	.finish-option {
		flex: 1;
		position: relative;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.5rem 1rem;
		border: 1px solid #d1d5db;
		border-radius: 4px;
		background: white;
		transition:
			background 0.2s,
			border-color 0.2s,
			color 0.2s;
	}

	.finish-option input[type='radio'] {
		position: absolute;
		opacity: 0;
		width: 0;
		height: 0;
	}

	.finish-option span {
		font-size: 0.875rem;
		font-weight: 500;
		color: #374151;
		user-select: none;
	}

	.finish-option:hover {
		background: #f9fafb;
		border-color: #3b82f6;
	}

	.finish-option input[type='radio']:checked + span {
		color: white;
	}

	.finish-option:has(input[type='radio']:checked) {
		background: #3b82f6;
		border-color: #3b82f6;
	}

	.finish-option input[type='radio']:focus + span {
		outline: 2px solid #3b82f6;
		outline-offset: 2px;
		border-radius: 4px;
	}

	:global(.dark) .drawer-header {
		border-bottom-color: #374151;
	}

	:global(.dark) .image-preview-area {
		background: #374151;
	}

	:global(.dark) .form-field label,
	:global(.dark) .form-field-label {
		color: #d1d5db;
	}

	:global(.dark) .form-input {
		background: #1f2937;
		border-color: #4b5563;
		color: #f9fafb;
	}

	:global(.dark) .finish-option {
		background: #1f2937;
		border-color: #4b5563;
	}

	:global(.dark) .finish-option span {
		color: #d1d5db;
	}

	:global(.dark) .finish-option:hover {
		background: #374151;
		border-color: #3b82f6;
	}

	:global(.dark) .finish-option:has(input[type='radio']:checked) {
		background: #3b82f6;
		border-color: #3b82f6;
	}

	:global(.dark) .finish-option input[type='radio']:checked + span {
		color: white;
	}

	:global(.dark) .optional-fields-toggle {
		background: #1f2937;
		border-color: #4b5563;
		color: #9ca3af;
	}

	:global(.dark) .optional-fields-toggle:hover {
		background: #374151;
		border-color: #6b7280;
	}

	/* Combobox Dark Mode */
	:global(.dark .combobox-control) {
		background: #1f2937;
		border-color: #4b5563;
	}

	:global(.dark .combobox-input) {
		color: #f9fafb;
	}

	:global(.dark .combobox-trigger) {
		color: #9ca3af;
	}

	:global(.dark .combobox-content) {
		background: #1f2937;
		border-color: #4b5563;
	}

	:global(.dark .combobox-item) {
		color: #d1d5db;
	}

	:global(.dark .combobox-item:hover),
	:global(.dark .combobox-item[data-highlighted]) {
		background: #374151;
	}

	:global(.dark .combobox-item[data-state='checked']) {
		background: #1e3a8a;
		color: #93c5fd;
	}

	@media (max-width: 768px) {
		.modal-body {
			flex-direction: column;
		}

		.image-preview-area {
			width: 100%;
		}
	}
</style>
