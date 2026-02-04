<script lang="ts">
	import { House, Search, LayoutGrid, Menu } from 'lucide-svelte';
	import { base } from '$app/paths';
	import type { ComponentType } from 'svelte';

	interface Props {
		open?: boolean;
		onSearchClick?: () => void;
	}

	let { open = $bindable(false), onSearchClick }: Props = $props();

	function toggleSidebar() {
		open = !open;
	}

	function handleSearchClick() {
		if (onSearchClick) {
			onSearchClick();
		}
	}

	interface NavItem {
		href?: string;
		label: string;
		icon: ComponentType;
		isButton?: boolean;
	}

	const navItems: NavItem[] = [
		{ href: `${base}/`, label: 'Home', icon: House },
		{ label: 'Search', icon: Search, isButton: true },
		{ href: `${base}/inventory`, label: 'Inventory', icon: LayoutGrid }
	];

	const currentPath =
		typeof window !== 'undefined' ? window.location.pathname.replace(base, '') || '/' : '/';
</script>

<aside aria-label="Navigation sidebar" class="sidebar-wrapper">
	<button
		type="button"
		onclick={toggleSidebar}
		class="toggle-button md:hidden"
		aria-label="Toggle navigation menu"
		aria-expanded={open}
	>
		<Menu class="h-6 w-6" />
	</button>

	<div
		class="sidebar-content {open ? 'sidebar-open' : 'sidebar-closed'}"
		data-testid="sidebar-content"
	>
		<nav class="sidebar-nav">
			<ul class="space-y-2">
				{#each navItems as item}
					{@const Icon = item.icon}
					<li>
						{#if item.isButton}
							<button
								type="button"
								onclick={handleSearchClick}
								class="nav-link nav-button"
								aria-label="Search - Open search drawer"
							>
								<Icon class="h-5 w-5" />
								<span class="nav-label">{item.label}</span>
							</button>
						{:else}
							<a
								href={item.href}
								class="nav-link {currentPath === item.href?.replace(base, '') || '/'
									? 'active'
									: ''}"
								aria-current={currentPath === item.href?.replace(base, '') || '/'
									? 'page'
									: undefined}
							>
								<Icon class="h-5 w-5" />
								<span class="nav-label">{item.label}</span>
							</a>
						{/if}
					</li>
				{/each}
			</ul>
		</nav>
	</div>
</aside>

<style>
	.sidebar-wrapper {
		position: relative;
	}

	.toggle-button {
		position: fixed;
		top: 1rem;
		left: 1rem;
		z-index: 50;
		padding: 0.5rem;
		background: #1f2937;
		color: white;
		border: none;
		border-radius: 0.375rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.toggle-button:hover {
		background: #374151;
	}

	.sidebar-content {
		position: fixed;
		top: 0;
		left: 0;
		z-index: 40;
		width: 16rem;
		height: 100vh;
		background: #f9fafb;
		border-right: 1px solid #e5e7eb;
		transition: transform 0.3s ease-in-out;
	}

	.sidebar-closed {
		transform: translateX(-100%);
	}

	.sidebar-open {
		transform: translateX(0);
	}

	@media (min-width: 768px) {
		.sidebar-content {
			transform: translateX(0) !important;
		}
	}

	.sidebar-nav {
		padding: 1rem;
		overflow-y: auto;
		height: 100%;
	}

	.nav-link {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		color: #111827;
		text-decoration: none;
		border-radius: 0.5rem;
		transition: background 0.2s;
		font-weight: 500;
	}

	.nav-button {
		width: 100%;
		background: transparent;
		border: none;
		cursor: pointer;
		text-align: left;
	}

	.nav-link:hover {
		background: #e5e7eb;
	}

	.nav-link.active {
		background: #dbeafe;
		color: #1e40af;
	}

	.nav-label {
		flex: 1;
	}

	:global(.dark) .sidebar-content {
		background: #1f2937;
		border-right-color: #374151;
	}

	:global(.dark) .nav-link {
		color: #e5e7eb;
	}

	:global(.dark) .nav-link:hover {
		background: #374151;
	}

	:global(.dark) .nav-link.active {
		background: #1e3a8a;
		color: #dbeafe;
	}
</style>
