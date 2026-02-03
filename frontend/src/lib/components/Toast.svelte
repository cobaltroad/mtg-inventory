<script lang="ts">
	interface Props {
		message: string;
		type?: 'success' | 'error';
		duration?: number;
		onDismiss?: () => void;
	}

	let { message, type = 'success', duration = 3000, onDismiss }: Props = $props();

	let visible = $state(true);

	$effect(() => {
		if (duration > 0) {
			const timer = setTimeout(() => {
				visible = false;
				if (onDismiss) {
					onDismiss();
				}
			}, duration);

			return () => clearTimeout(timer);
		}
	});
</script>

{#if visible}
	<div class="toast {type}" role="status" aria-live="polite">
		{message}
	</div>
{/if}

<style>
	.toast {
		position: fixed;
		top: 1rem;
		right: 1rem;
		padding: 1rem 1.5rem;
		border-radius: 8px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
		font-weight: 500;
		font-size: 0.875rem;
		z-index: 1000;
		max-width: 400px;
		animation: slideIn 0.3s ease-out;
	}

	.toast.success {
		background: #16a34a;
		color: white;
	}

	.toast.error {
		background: #dc2626;
		color: white;
	}

	@keyframes slideIn {
		from {
			transform: translateX(100%);
			opacity: 0;
		}
		to {
			transform: translateX(0);
			opacity: 1;
		}
	}
</style>
