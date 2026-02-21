import { base } from '$app/paths';
import { redirect } from '@sveltejs/kit';
import type { PageLoad } from './$types';

const AUTH_ENABLED = import.meta.env.VITE_AUTH_ENABLED === 'true';

export const load: PageLoad = async ({ fetch }) => {
	if (AUTH_ENABLED) {
		try {
			const authRes = await fetch(`${base}/api/auth/status`);
			const authData = await authRes.json();

			if (!authData.authenticated) {
				throw redirect(302, `${base}/login`);
			}
		} catch (e) {
			if (e.status === 302) throw e;
			throw redirect(302, `${base}/login`);
		}
	}

	return {};
};
