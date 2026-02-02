import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import path from 'node:path';

export default defineConfig({
	plugins: [svelte()],
	resolve: {
		conditions: ['browser'],
		alias: {
			'$app/paths': path.resolve(__dirname, 'src/__mocks__/app/paths.ts')
		}
	},
	test: {
		environment: 'happy-dom',
		setupFiles: ['./src/test-setup.ts']
	}
});
