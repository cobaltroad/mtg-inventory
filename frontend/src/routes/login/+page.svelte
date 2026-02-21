<script lang="ts">
	import { login } from '$lib/services/authService.svelte';

	const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED === 'true';
</script>

<div class="login-page">
	<div class="login-card">
		<h1 class="title">MTG Inventory</h1>
		<p class="subtitle">Sign in to manage your collection</p>

		{#if AUTH_ENABLED}
			<button class="login-btn" onclick={login}> Login with Discord </button>
		{:else}
			<p class="dev-notice">Authentication is disabled in development</p>
		{/if}
	</div>
</div>

<style>
	.login-page {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: calc(100vh - 200px);
		padding: 2rem;
	}

	.login-card {
		background: white;
		border-radius: 1rem;
		box-shadow:
			0 4px 6px -1px rgba(0, 0, 0, 0.1),
			0 2px 4px -2px rgba(0, 0, 0, 0.1);
		padding: 3rem 2rem;
		text-align: center;
		max-width: 400px;
		width: 100%;
	}

	:global(.dark) .login-card {
		background: #1f2937;
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.3);
	}

	.title {
		font-size: 2rem;
		font-weight: 700;
		color: #111827;
		margin: 0 0 0.5rem;
	}

	:global(.dark) .title {
		color: #f9fafb;
	}

	.subtitle {
		font-size: 1rem;
		color: #6b7280;
		margin: 0 0 2rem;
	}

	:global(.dark) .subtitle {
		color: #9ca3af;
	}

	.login-btn {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		padding: 0.875rem 1.5rem;
		background: #5865f2;
		color: white;
		border: none;
		border-radius: 0.5rem;
		font-size: 1rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s;
		width: 100%;
	}

	.login-btn:hover {
		background: #4752c4;
		transform: translateY(-1px);
		box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
	}

	.login-btn:active {
		transform: translateY(0);
	}

	.dev-notice {
		color: #6b7280;
		font-size: 0.875rem;
	}

	:global(.dark) .dev-notice {
		color: #9ca3af;
	}
</style>
