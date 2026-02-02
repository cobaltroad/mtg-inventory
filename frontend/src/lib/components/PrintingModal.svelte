<script lang="ts">
	import { base } from '$app/paths';

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

	let { card, open = $bindable(false), onclose }: Props = $props();

	let printings: Printing[] = $state([]);
	let loading = $state(false);
	let error = $state(false);
	let hoveredPrinting: Printing | null = $state(null);
	let dialogElement = $state<HTMLDialogElement>();

	async function fetchPrintings() {
		loading = true;
		error = false;
		try {
			const res = await fetch(`${API_BASE}/api/cards/${card.id}/printings`);
			if (!res.ok) {
				throw new Error('Failed to fetch printings');
			}
			const data = await res.json();
			printings = data.printings || [];
		} catch (err) {
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

	$effect(() => {
		if (open && dialogElement) {
			dialogElement.showModal();
			fetchPrintings();
		} else if (dialogElement) {
			dialogElement.close();
		}
	});
</script>

<svelte:window on:keydown={handleKeyDown} />

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<dialog bind:this={dialogElement} aria-labelledby="modal-title" onclick={handleBackdropClick} data-testid="modal-backdrop">
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
						{#each printings as printing}
							<div
								class="printing-item"
								data-testid="printing-item"
								role="button"
								tabindex="0"
								onmouseenter={() => (hoveredPrinting = printing)}
								onmouseleave={() => (hoveredPrinting = null)}
								onfocus={() => (hoveredPrinting = printing)}
								onblur={() => (hoveredPrinting = null)}
							>
								<div class="printing-info">
									<span class="set-name">{printing.set_name}</span>
									<span class="set-code">({printing.set.toUpperCase()})</span>
									<span class="collector-number">#{printing.collector_number}</span>
								</div>
								{#if hoveredPrinting === printing && printing.image_url}
									<div class="card-preview">
										<img src={printing.image_url} alt="{printing.name} from {printing.set_name}" />
									</div>
								{/if}
							</div>
						{/each}
					</div>

					{#if hoveredPrinting && hoveredPrinting.image_url}
						<div class="image-preview-area">
							<img src={hoveredPrinting.image_url} alt="{hoveredPrinting.name} from {hoveredPrinting.set_name}" />
						</div>
					{/if}
				</div>
			{/if}
		</div>
	</dialog>
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
		transition: background 0.2s, color 0.2s;
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
		transition: background 0.2s, color 0.2s;
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
		transition: background 0.2s, border-color 0.2s;
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

	.card-preview {
		position: absolute;
		left: 100%;
		top: 0;
		margin-left: 1rem;
		z-index: 100;
		pointer-events: none;
	}

	.card-preview img {
		width: 250px;
		border-radius: 8px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}

	.image-preview-area {
		position: sticky;
		top: 0;
		width: 300px;
		height: fit-content;
		display: flex;
		align-items: flex-start;
		justify-content: center;
		padding: 1rem;
		background: #f9fafb;
		border-radius: 8px;
	}

	.image-preview-area img {
		width: 100%;
		border-radius: 8px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
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

		.card-preview {
			display: none;
		}
	}
</style>
