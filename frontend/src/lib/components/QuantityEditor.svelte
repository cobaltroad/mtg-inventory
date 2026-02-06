<script lang="ts">
	import { Check, X, Pencil } from 'lucide-svelte';

	interface Props {
		initialQuantity: number;
		onSave: (newQuantity: number) => Promise<void>;
		onCancel?: () => void;
	}

	let { initialQuantity, onSave, onCancel }: Props = $props();

	let isEditing = $state(false);
	let currentValue = $state('');
	let error = $state<string | null>(null);
	let isSaving = $state(false);

	$effect(() => {
		currentValue = initialQuantity.toString();
		if (!isEditing) {
			error = null;
		}
	});

	function startEditing() {
		isEditing = true;
		currentValue = initialQuantity.toString();
		error = null;
	}

	function validateQuantity(value: string): boolean {
		const num = parseInt(value, 10);

		if (isNaN(num)) {
			error = 'Quantity must be a number';
			return false;
		}

		if (num < 1) {
			error = 'Quantity must be between 1 and 999';
			return false;
		}

		if (num > 999) {
			error = 'Quantity must be between 1 and 999';
			return false;
		}

		error = null;
		return true;
	}

	function handleInput(e: Event) {
		const input = e.target as HTMLInputElement;
		currentValue = input.value;
		validateQuantity(currentValue);
	}

	async function handleSave() {
		if (!validateQuantity(currentValue)) {
			return;
		}

		const newQuantity = parseInt(currentValue, 10);
		if (newQuantity === initialQuantity) {
			cancel();
			return;
		}

		isSaving = true;
		try {
			await onSave(newQuantity);
			isEditing = false;
		} catch (err) {
			error = 'Failed to update quantity';
		} finally {
			isSaving = false;
		}
	}

	function cancel() {
		isEditing = false;
		error = null;
		if (onCancel) {
			onCancel();
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			e.preventDefault();
			handleSave();
		} else if (e.key === 'Escape') {
			e.preventDefault();
			cancel();
		}
	}
</script>

{#if isEditing}
	<div class="quantity-editor" data-testid="quantity-editor">
		<div class="editor-wrapper">
			<input
				type="number"
				class="quantity-input"
				class:error={error !== null}
				value={currentValue}
				oninput={handleInput}
				onkeydown={handleKeydown}
				min="1"
				max="999"
				disabled={isSaving}
				data-testid="quantity-input"
			/>
			<div class="button-group">
				<button
					class="icon-btn save-btn"
					onclick={handleSave}
					disabled={error !== null || isSaving}
					data-testid="save-btn"
					title="Save"
				>
					<Check size={16} />
				</button>
				<button
					class="icon-btn cancel-btn"
					onclick={cancel}
					disabled={isSaving}
					data-testid="cancel-btn"
					title="Cancel"
				>
					<X size={16} />
				</button>
			</div>
		</div>
		{#if error}
			<div class="error-message" data-testid="error-message">{error}</div>
		{/if}
	</div>
{:else}
	<button class="quantity-display" onclick={startEditing} data-testid="quantity-display">
		<span class="quantity-value">{initialQuantity}x</span>
		<Pencil size={14} class="edit-icon" />
	</button>
{/if}

<style>
	.quantity-display {
		display: inline-flex;
		align-items: center;
		gap: 0.5rem;
		min-width: 4rem;
		padding: 0.25rem 0.75rem;
		background: #dbeafe;
		color: #1e40af;
		border: 1px solid transparent;
		border-radius: 9999px;
		font-weight: 600;
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.quantity-display:hover {
		background: #bfdbfe;
		border-color: #3b82f6;
	}

	.quantity-display :global(.edit-icon) {
		opacity: 0;
		transition: opacity 0.2s;
	}

	.quantity-display:hover :global(.edit-icon) {
		opacity: 1;
	}

	.quantity-editor {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
	}

	.editor-wrapper {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.quantity-input {
		width: 4rem;
		padding: 0.25rem 0.5rem;
		border: 2px solid #3b82f6;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		text-align: center;
	}

	.quantity-input:focus {
		outline: none;
		border-color: #2563eb;
		box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
	}

	.quantity-input.error {
		border-color: #ef4444;
	}

	.quantity-input:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.button-group {
		display: flex;
		gap: 0.25rem;
	}

	.icon-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 1.75rem;
		height: 1.75rem;
		padding: 0;
		border: none;
		border-radius: 0.375rem;
		cursor: pointer;
		transition: all 0.2s;
	}

	.save-btn {
		background: #22c55e;
		color: white;
	}

	.save-btn:hover:not(:disabled) {
		background: #16a34a;
	}

	.save-btn:disabled {
		background: #9ca3af;
		cursor: not-allowed;
	}

	.cancel-btn {
		background: #ef4444;
		color: white;
	}

	.cancel-btn:hover:not(:disabled) {
		background: #dc2626;
	}

	.error-message {
		font-size: 0.75rem;
		color: #ef4444;
		margin-top: 0.125rem;
	}

	:global(.dark) .quantity-display {
		background: #1e3a8a;
		color: #93c5fd;
	}

	:global(.dark) .quantity-display:hover {
		background: #1e40af;
		border-color: #60a5fa;
	}

	:global(.dark) .quantity-input {
		background: #1f2937;
		border-color: #3b82f6;
		color: #e5e7eb;
	}

	:global(.dark) .quantity-input:focus {
		border-color: #60a5fa;
	}

	/* Remove spinner arrows in number input */
	.quantity-input::-webkit-outer-spin-button,
	.quantity-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	.quantity-input[type='number'] {
		appearance: textfield;
		-moz-appearance: textfield;
	}
</style>
