import { base } from '$app/paths';
import { goto } from '$app/navigation';
import { apiClient } from './apiClient';

interface User {
	id: number;
	email: string;
	name: string;
}

interface AuthState {
	user: User | null;
	isAuthenticated: boolean;
	loading: boolean;
}

let user = $state<User | null>(null);
let isAuthenticated = $state<boolean>(false);
let loading = $state<boolean>(true);

export function getAuthState(): AuthState {
	return {
		user,
		isAuthenticated,
		loading
	};
}

export async function checkAuthStatus(): Promise<void> {
	loading = true;
	try {
		const data = await apiClient.get<{ authenticated: boolean; user: User | null }>(
			'/api/auth/status'
		);

		if (data.authenticated && data.user) {
			user = data.user;
			isAuthenticated = true;
		} else {
			user = null;
			isAuthenticated = false;
		}
	} catch {
		user = null;
		isAuthenticated = false;
	} finally {
		loading = false;
	}
}

export function login(): void {
	// eslint-disable-next-line svelte/no-navigation-without-resolve
	goto(`${base}/api/auth/discord`);
}

export async function logout(): Promise<void> {
	try {
		await apiClient.delete('/api/auth/logout');
	} catch (error) {
		console.error('Logout request failed:', error);
	} finally {
		user = null;
		isAuthenticated = false;
		loading = false;
		// eslint-disable-next-line svelte/no-navigation-without-resolve
		goto(`${base}/login`);
	}
}
