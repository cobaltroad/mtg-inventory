<script lang="ts">
	import { X, Trash2 } from 'lucide-svelte';

	interface Props {
		cardName: string;
		setCode: string;
		collectorNumber: string;
		onConfirm: () => Promise<void>;
		onCancel: () => void;
		show: boolean;
	}

	let { cardName, setCode, collectorNumber, onConfirm, onCancel, show }: Props = $props();

	let isRemoving = $state(false);

	async function handleConfirm() {
		isRemoving = true;
		try {
			await onConfirm();
		} finally {
			isRemoving = false;
		}
	}

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === e.currentTarget) {
			onCancel();
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape' && !isRemoving) {
			onCancel();
		}
	}
</script>

{#if show}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div
		class="modal-backdrop"
		onclick={handleBackdropClick}
		onkeydown={handleKeydown}
		role="dialog"
		aria-modal="true"
		aria-labelledby="modal-title"
		tabindex="-1"
		data-testid="remove-confirmation-modal"
	>
		<div class="modal-content">
			<div class="modal-header">
				<div class="header-icon">
					<Trash2 size={24} />
				</div>
				<button
					class="close-btn"
					onclick={onCancel}
					disabled={isRemoving}
					aria-label="Close dialog"
					data-testid="close-btn"
				>
					<X size={20} />
				</button>
			</div>

			<div class="modal-body">
				<h2 id="modal-title" class="modal-title">Remove Card from Inventory</h2>
				<p class="modal-message">
					Are you sure you want to remove <strong>{cardName}</strong>
					<span class="card-details">({setCode.toUpperCase()} #{collectorNumber})</span> from your inventory?
				</p>
				<p class="warning-text">This action cannot be undone.</p>
			</div>

			<div class="modal-footer">
				<button
					class="btn-cancel btn"
					onclick={onCancel}
					disabled={isRemoving}
					data-testid="cancel-btn"
				>
					Cancel
				</button>
				<button
					class="btn-remove btn"
					onclick={handleConfirm}
					disabled={isRemoving}
					data-testid="confirm-btn"
				>
					{#if isRemoving}
						Removing...
					{:else}
						Remove
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.modal-backdrop {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.5);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 50;
		padding: 1rem;
		animation: fadeIn 0.2s ease-out;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
		}
		to {
			opacity: 1;
		}
	}

	.modal-content {
		background: white;
		border-radius: 0.75rem;
		box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1);
		max-width: 28rem;
		width: 100%;
		animation: slideIn 0.2s ease-out;
	}

	@keyframes slideIn {
		from {
			transform: translateY(-1rem);
			opacity: 0;
		}
		to {
			transform: translateY(0);
			opacity: 1;
		}
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 1.5rem 1.5rem 0;
	}

	.header-icon {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 3rem;
		height: 3rem;
		background: #fee2e2;
		color: #dc2626;
		border-radius: 50%;
	}

	.close-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 2rem;
		height: 2rem;
		padding: 0;
		background: transparent;
		border: none;
		border-radius: 0.375rem;
		color: #6b7280;
		cursor: pointer;
		transition: all 0.2s;
	}

	.close-btn:hover:not(:disabled) {
		background: #f3f4f6;
		color: #111827;
	}

	.close-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.modal-body {
		padding: 1.5rem;
	}

	.modal-title {
		font-size: 1.25rem;
		font-weight: 700;
		color: #111827;
		margin: 0 0 1rem;
	}

	.modal-message {
		font-size: 0.875rem;
		color: #4b5563;
		line-height: 1.5;
		margin: 0 0 0.75rem;
	}

	.modal-message strong {
		color: #111827;
		font-weight: 600;
	}

	.card-details {
		color: #6b7280;
		font-size: 0.8125rem;
	}

	.warning-text {
		font-size: 0.8125rem;
		color: #dc2626;
		margin: 0;
	}

	.modal-footer {
		display: flex;
		gap: 0.75rem;
		padding: 0 1.5rem 1.5rem;
		justify-content: flex-end;
	}

	.btn {
		padding: 0.5rem 1rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.2s;
	}

	.btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn-cancel {
		background: #f3f4f6;
		color: #374151;
	}

	.btn-cancel:hover:not(:disabled) {
		background: #e5e7eb;
	}

	.btn-remove {
		background: #dc2626;
		color: white;
	}

	.btn-remove:hover:not(:disabled) {
		background: #b91c1c;
	}

	:global(.dark) .modal-content {
		background: #1f2937;
	}

	:global(.dark) .modal-title {
		color: #e5e7eb;
	}

	:global(.dark) .modal-message {
		color: #9ca3af;
	}

	:global(.dark) .modal-message strong {
		color: #e5e7eb;
	}

	:global(.dark) .card-details {
		color: #6b7280;
	}

	:global(.dark) .header-icon {
		background: #7f1d1d;
		color: #fca5a5;
	}

	:global(.dark) .close-btn {
		color: #9ca3af;
	}

	:global(.dark) .close-btn:hover:not(:disabled) {
		background: #374151;
		color: #e5e7eb;
	}

	:global(.dark) .btn-cancel {
		background: #374151;
		color: #e5e7eb;
	}

	:global(.dark) .btn-cancel:hover:not(:disabled) {
		background: #4b5563;
	}

	@media (max-width: 640px) {
		.modal-content {
			margin: 1rem;
		}

		.modal-footer {
			flex-direction: column-reverse;
		}

		.btn {
			width: 100%;
		}
	}
</style>
