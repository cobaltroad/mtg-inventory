<script lang="ts">
	interface Props {
		message?: string;
		size?: 'sm' | 'md' | 'lg';
	}

	let { message = 'Loading...', size = 'md' }: Props = $props();

	const sizeClasses = {
		sm: 'h-8 w-8',
		md: 'h-12 w-12',
		lg: 'h-16 w-16'
	};
</script>

<div class="loading-container">
	<div class="spinner-wrapper">
		<svg
			class="spinner {sizeClasses[size]}"
			xmlns="http://www.w3.org/2000/svg"
			fill="none"
			viewBox="0 0 24 24"
		>
			<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"
			></circle>
			<path
				class="opacity-75"
				fill="currentColor"
				d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
			></path>
		</svg>
		{#if message}
			<p class="loading-message">{message}</p>
		{/if}
	</div>
</div>

<style>
	.loading-container {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 400px;
		padding: 4rem 2rem;
	}

	.spinner-wrapper {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1rem;
	}

	.spinner {
		color: #3b82f6;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		from {
			transform: rotate(0deg);
		}
		to {
			transform: rotate(360deg);
		}
	}

	.loading-message {
		font-size: 1rem;
		color: #6b7280;
		margin: 0;
	}

	:global(.dark) .loading-message {
		color: #9ca3af;
	}

	:global(.dark) .spinner {
		color: #60a5fa;
	}
</style>
