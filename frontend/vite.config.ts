import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
	const env = loadEnv(mode, process.cwd(), '');

	// HMR Configuration:
	// For local development, access directly via http://localhost:3001/projects/mtg
	// Accessing through Traefik domain (cobaltroad.com) will disable HMR to avoid
	// slow WebSocket connection attempts to unreachable ports
	const hmrConfig = env.APP_DOMAIN
		? false // Disable HMR when accessed through production domain
		: {
				// Local development - HMR works when accessing localhost:3001
				clientPort: 3001
			};

	return {
		plugins: [sveltekit()],
		server: {
			host: true,
			port: 5173,
			allowedHosts: env.APP_DOMAIN ? [env.APP_DOMAIN, `.${env.APP_DOMAIN}`] : [],
			hmr: hmrConfig
		}
	};
});
