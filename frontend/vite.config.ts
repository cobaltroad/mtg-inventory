import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
	const env = loadEnv(mode, process.cwd(), '');

	return {
		plugins: [sveltekit()],
		server: {
			host: true,
			port: 5173,
			allowedHosts: env.APP_DOMAIN ? [env.APP_DOMAIN, `.${env.APP_DOMAIN}`] : [],
			hmr: { clientPort: 5173 }
		}
	};
});
