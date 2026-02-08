<script lang="ts">
	import { Navigation } from '@skeletonlabs/skeleton-svelte';
	import {
		House,
		Search,
		Medal,
		Layers,
		FileText,
		LayoutGrid,
		Menu,
		PanelLeftOpen,
		PanelLeftClose
	} from 'lucide-svelte';
	import { base } from '$app/paths';
	import { page } from '$app/stores';
	import type { ComponentType } from 'svelte';

	/**
	 * Props for the Sidebar component
	 */
	interface Props {
		/** Controls sidebar visibility on mobile. Bindable state. */
		open?: boolean;
		/** Layout mode: 'sidebar' (full width with labels) or 'rail' (compact with icons only) */
		mode?: 'sidebar' | 'rail';
		/** Callback function triggered when toggling between sidebar and rail modes */
		onToggleMode?: () => void;
	}

	let { open = $bindable(false), mode = 'sidebar', onToggleMode }: Props = $props();

	/**
	 * Represents a navigation item in the sidebar
	 */
	interface NavItem {
		/** Navigation route */
		href: string;
		/** Display label for the navigation item */
		label: string;
		/** Lucide icon component to display */
		icon: ComponentType;
	}

	/**
	 * Navigation items configuration
	 * Defines all sidebar navigation entries
	 */
	const navItems: NavItem[] = [
		{ href: `${base}/`, label: 'Home', icon: House },
		{ href: `${base}/search`, label: 'Search', icon: Search },
		{ href: `${base}/metagame`, label: 'Metagame', icon: Medal },
		{ href: `${base}/decks`, label: 'Decks', icon: Layers },
		{ href: `${base}/reports`, label: 'Reports', icon: FileText },
		{ href: `${base}/inventory`, label: 'Inventory', icon: LayoutGrid }
	];

	/**
	 * Current page path for determining active navigation state
	 * Derived from the SvelteKit page store to reactively track route changes
	 */
	const currentPath = $derived($page.url.pathname.replace(base, '') || '/');

	/**
	 * Toggles sidebar visibility on mobile devices
	 */
	function toggleSidebar(): void {
		open = !open;
	}

	/**
	 * Handles toggle mode button click
	 * Delegates to the onToggleMode callback if provided
	 */
	function handleToggleMode(): void {
		onToggleMode?.();
	}

	/**
	 * Determines if a navigation link represents the current active route
	 * @param href - The navigation link href to check
	 * @returns true if the href matches the current path
	 */
	function isActive(href: string): boolean {
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
		layout={mode}
		class="navigation-root navigation-{mode} {open ? 'navigation-open' : 'navigation-closed'}"
	>
		<Navigation.Content>
			<Navigation.Group>
				<Navigation.Menu>
					{#each navItems as item}
						{@const Icon = item.icon}
						<!-- Navigation link -->
						<Navigation.TriggerAnchor
							href={item.href}
							class="nav-item {isActive(item.href) ? 'active' : ''}"
							aria-current={isActive(item.href) ? 'page' : undefined}
						>
							<Icon class="h-5 w-5" />
							<Navigation.TriggerText>{item.label}</Navigation.TriggerText>
						</Navigation.TriggerAnchor>
					{/each}

					<!-- Sidebar/Rail mode toggle -->
					<div class="mode-toggle-wrapper">
						<Navigation.Trigger
							onclick={handleToggleMode}
							aria-label={mode === 'sidebar' ? 'Switch to rail mode' : 'Switch to sidebar mode'}
							class="nav-item mode-toggle"
						>
							{#if mode === 'sidebar'}
								<PanelLeftClose class="h-5 w-5" />
								<Navigation.TriggerText>Collapse</Navigation.TriggerText>
							{:else}
								<PanelLeftOpen class="h-5 w-5" />
								<Navigation.TriggerText>Expand</Navigation.TriggerText>
							{/if}
						</Navigation.Trigger>
					</div>
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
		height: 100vh;
		background: rgb(249 250 251);
		border-right: 1px solid rgb(229 231 235);
		transition: all 0.3s ease-in-out;
		display: flex;
		flex-direction: column;
		padding: 1rem;
	}

	:global(.navigation-sidebar) {
		width: 16rem;
	}

	:global(.navigation-rail) {
		width: 5rem;
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

	/* Rail mode: center icons and hide text */
	:global(.navigation-rail .nav-item) {
		justify-content: center;
		padding: 0.75rem;
	}

	:global(.navigation-rail .nav-item span) {
		display: none;
	}

	/* Make navigation stretch full height for proper bottom alignment */
	:global(.navigation-root > *),
	:global(.navigation-root nav),
	:global(.navigation-root [role='group']),
	:global(.navigation-root [role='menu']),
	:global(.navigation-root ul) {
		height: 100%;
		display: flex;
		flex-direction: column;
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

	.mode-toggle-wrapper {
		margin-top: auto;
		padding: 1rem 0 1rem 0;
		border-top: 1px solid rgb(229 231 235);
	}

	/* In rail mode, adjust padding for centered layout */
	:global(.navigation-rail) .mode-toggle-wrapper {
		padding: 1rem 0;
	}

	:global(.dark .mode-toggle-wrapper) {
		border-top-color: rgb(55 65 81);
	}

	:global(.mode-toggle) {
		opacity: 0.8;
	}

	:global(.mode-toggle:hover) {
		opacity: 1;
	}
</style>
