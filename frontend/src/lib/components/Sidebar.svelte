<script lang="ts">
	import { Navigation } from '@skeletonlabs/skeleton-svelte';
	import { House, Search, FolderOpen, Layers, FileText, LayoutGrid, Menu } from 'lucide-svelte';
	import { base } from '$app/paths';
	import type { ComponentType } from 'svelte';

	/**
	 * Props for the Sidebar component
	 */
	interface Props {
		/** Controls sidebar visibility on mobile. Bindable state. */
		open?: boolean;
		/** Callback function triggered when the Search navigation item is clicked */
		onSearchClick?: () => void;
	}

	let { open = $bindable(false), onSearchClick }: Props = $props();

	/**
	 * Represents a navigation item in the sidebar
	 */
	interface NavItem {
		/** Navigation route. Omit for non-navigational triggers like Search */
		href?: string;
		/** Display label for the navigation item */
		label: string;
		/** Lucide icon component to display */
		icon: ComponentType;
		/** Whether this item is a button trigger instead of a navigation link */
		isButton?: boolean;
	}

	/**
	 * Navigation items configuration
	 * Defines all sidebar navigation entries including links and action triggers
	 */
	const navItems: NavItem[] = [
		{ href: `${base}/`, label: 'Home', icon: House },
		{ label: 'Search', icon: Search, isButton: true },
		{ href: `${base}/collections`, label: 'Collections', icon: FolderOpen },
		{ href: `${base}/decks`, label: 'Decks', icon: Layers },
		{ href: `${base}/reports`, label: 'Reports', icon: FileText },
		{ href: `${base}/inventory`, label: 'Inventory', icon: LayoutGrid }
	];

	/**
	 * Current page path for determining active navigation state
	 */
	const currentPath: string =
		typeof window !== 'undefined' ? window.location.pathname.replace(base, '') || '/' : '/';

	/**
	 * Toggles sidebar visibility on mobile devices
	 */
	function toggleSidebar(): void {
		open = !open;
	}

	/**
	 * Handles Search navigation item click
	 * Delegates to the onSearchClick callback if provided
	 */
	function handleSearchClick(): void {
		onSearchClick?.();
	}

	/**
	 * Determines if a navigation link represents the current active route
	 * @param href - The navigation link href to check
	 * @returns true if the href matches the current path
	 */
	function isActive(href?: string): boolean {
		if (!href) return false;
		const normalizedHref = href.replace(base, '') || '/';
		return currentPath === normalizedHref;
	}
</script>

<aside aria-label="Navigation sidebar" class="sidebar-wrapper">
	<!-- Mobile toggle button -->
	<button
		type="button"
		onclick={toggleSidebar}
		class="toggle-button md:hidden"
		aria-label="Toggle navigation menu"
		aria-expanded={open}
	>
		<Menu class="h-6 w-6" />
	</button>

	<!-- Skeleton UI Navigation Component -->
	<Navigation
		layout="sidebar"
		class="navigation-root {open ? 'navigation-open' : 'navigation-closed'}"
	>
		<Navigation.Content>
			<Navigation.Group>
				<Navigation.Menu>
					{#each navItems as item}
						{@const Icon = item.icon}
						{#if item.isButton}
							<!-- Search trigger button -->
							<Navigation.Trigger
								onclick={handleSearchClick}
								aria-label="{item.label} - Open search drawer"
								class="nav-item"
							>
								<Icon class="h-5 w-5" />
								<Navigation.TriggerText>{item.label}</Navigation.TriggerText>
							</Navigation.Trigger>
						{:else}
							<!-- Navigation link -->
							<Navigation.TriggerAnchor
								href={item.href}
								class="nav-item {isActive(item.href) ? 'active' : ''}"
								aria-current={isActive(item.href) ? 'page' : undefined}
							>
								<Icon class="h-5 w-5" />
								<Navigation.TriggerText>{item.label}</Navigation.TriggerText>
							</Navigation.TriggerAnchor>
						{/if}
					{/each}
				</Navigation.Menu>
			</Navigation.Group>
		</Navigation.Content>
	</Navigation>
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
		background: rgb(31 41 55);
		color: white;
		border: none;
		border-radius: 0.375rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	.toggle-button:hover {
		background: rgb(55 65 81);
	}

	:global(.navigation-root) {
		position: fixed;
		top: 0;
		left: 0;
		z-index: 40;
		width: 16rem;
		height: 100vh;
		background: rgb(249 250 251);
		border-right: 1px solid rgb(229 231 235);
		transition: transform 0.3s ease-in-out;
	}

	:global(.navigation-closed) {
		transform: translateX(-100%);
	}

	:global(.navigation-open) {
		transform: translateX(0);
	}

	@media (min-width: 768px) {
		:global(.navigation-root) {
			transform: translateX(0) !important;
		}
	}

	:global(.nav-item) {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		color: rgb(17 24 39);
		text-decoration: none;
		border-radius: 0.5rem;
		transition: background 0.2s;
		font-weight: 500;
		width: 100%;
		border: none;
		background: transparent;
		cursor: pointer;
		text-align: left;
	}

	:global(.nav-item:hover) {
		background: rgb(229 231 235);
	}

	:global(.nav-item.active) {
		background: rgb(219 234 254);
		color: rgb(30 64 175);
	}

	:global(.dark .navigation-root) {
		background: rgb(31 41 55);
		border-right-color: rgb(55 65 81);
	}

	:global(.dark .nav-item) {
		color: rgb(229 231 235);
	}

	:global(.dark .nav-item:hover) {
		background: rgb(55 65 81);
	}

	:global(.dark .nav-item.active) {
		background: rgb(30 58 138);
		color: rgb(219 234 254);
	}
</style>
