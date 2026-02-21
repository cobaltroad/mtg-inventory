import { base } from '$app/paths';
import type { LayoutLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { getAuthState, checkAuthStatus } from '$lib/services/authService.svelte';

const PROTECTED_ROUTES = ['/inventory', '/wishlist', '/reports'];
const PUBLIC_ROUTES = ['/login', '/auth/callback'];

export const load: LayoutLoad = async ({ url }) => {
	const path = url.pathname;
	const isPublicRoute = PUBLIC_ROUTES.some((route) => path === route || path.startsWith(route));
	const isProtectedRoute = PROTECTED_ROUTES.some((route) => path.startsWith(route));

	if (isProtectedRoute && !isPublicRoute) {
		const authState = getAuthState();

		if (!authState.isAuthenticated && !authState.loading) {
			await checkAuthStatus();
		}

		const currentState = getAuthState();
		if (!currentState.isAuthenticated) {
			throw redirect(302, `${base}/login`);
		}
	}

	return {};
};
