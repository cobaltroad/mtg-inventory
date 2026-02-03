import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

// ---------------------------------------------------------------------------
// Import the hook under test.  hooks.server.ts exports a named `handle` function.
// ---------------------------------------------------------------------------
import { handle } from './hooks.server';

// ---------------------------------------------------------------------------
// Helper: builds a minimal synthetic event that matches the shape the hook
// expects.  `search` defaults to '' so individual tests only set it when they
// need query-string behaviour.
// ---------------------------------------------------------------------------
function makeEvent({
	pathname,
	search = '',
	method = 'GET',
	headers = new Headers(),
	body = new ArrayBuffer(0)
}: {
	pathname: string;
	search?: string;
	method?: string;
	headers?: Headers;
	body?: ArrayBuffer;
}) {
	return {
		url: { pathname, search },
		request: {
			method,
			headers,
			arrayBuffer: () => Promise.resolve(body)
		}
	};
}

// ---------------------------------------------------------------------------
// Helper: builds a synthetic Response-like object returned by the stubbed
// globalThis.fetch so the hook can forward it.
// ---------------------------------------------------------------------------
function makeBackendResponse({
	status = 200,
	body = 'ok',
	headers = new Headers([['content-type', 'application/json']])
}: {
	status?: number;
	body?: string;
	headers?: Headers;
} = {}) {
	return new Response(body, { status, headers });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
describe('hooks.server – handle', () => {
	let originalFetch: typeof globalThis.fetch;

	beforeEach(() => {
		originalFetch = globalThis.fetch;
		process.env.VITE_API_URL = 'http://backend:3000';
		process.env.PUBLIC_BASE_PATH = '/projects/mtg';
	});

	afterEach(() => {
		globalThis.fetch = originalFetch;
		delete process.env.VITE_API_URL;
		delete process.env.PUBLIC_BASE_PATH;
		vi.restoreAllMocks();
	});

	// -----------------------------------------------------------------------
	// 1. GET /api/* is proxied to the backend with full path
	// -----------------------------------------------------------------------
	it('proxies GET /api/* requests to the backend with path and query string', async () => {
		const backendResponse = makeBackendResponse({ body: '{"cards":[]}' });
		const stubFetch = vi.fn().mockResolvedValue(backendResponse);
		globalThis.fetch = stubFetch;

		const resolve = vi.fn();
		const event = makeEvent({ pathname: '/api/cards/search', search: '?q=bolt' });

		const result = await handle({ event, resolve } as any);

		// fetch was called exactly once with the full pathname forwarded to backend
		expect(stubFetch).toHaveBeenCalledTimes(1);
		expect(stubFetch).toHaveBeenCalledWith(
			'http://backend:3000/api/cards/search?q=bolt',
			expect.objectContaining({ method: 'GET' })
		);

		// resolve was NOT called -- the hook short-circuits for /api/ paths
		expect(resolve).not.toHaveBeenCalled();

		// The hook returns the backend response directly
		expect(result.status).toBe(200);
		expect(await result.text()).toBe('{"cards":[]}');
	});

	// -----------------------------------------------------------------------
	// 2. POST /api/* is proxied with the request body forwarded
	// -----------------------------------------------------------------------
	it('proxies POST /api/* requests and forwards the request body', async () => {
		const backendResponse = makeBackendResponse({
			body: '{"card_id":"abc","quantity":1,"collection_type":"inventory"}'
		});
		const stubFetch = vi.fn().mockResolvedValue(backendResponse);
		globalThis.fetch = stubFetch;

		const resolve = vi.fn();
		const requestBody = new TextEncoder().encode(
			JSON.stringify({ card_id: 'abc', quantity: 1 })
		).buffer;
		const event = makeEvent({
			pathname: '/api/inventory',
			method: 'POST',
			headers: new Headers([['content-type', 'application/json']]),
			body: requestBody
		});

		const result = await handle({ event, resolve } as any);

		expect(stubFetch).toHaveBeenCalledTimes(1);
		expect(stubFetch).toHaveBeenCalledWith(
			'http://backend:3000/api/inventory',
			expect.objectContaining({
				method: 'POST',
				body: requestBody
			})
		);

		expect(resolve).not.toHaveBeenCalled();
		expect(result.status).toBe(200);
	});

	// -----------------------------------------------------------------------
	// 3. Non-API paths fall through to resolve()
	// -----------------------------------------------------------------------
	it('passes non-/api/ paths through to SvelteKit resolve', async () => {
		const stubFetch = vi.fn();
		globalThis.fetch = stubFetch;

		const sentinelResponse = makeBackendResponse({ body: '<html>page</html>' });
		const resolve = vi.fn().mockResolvedValue(sentinelResponse);
		const event = makeEvent({ pathname: '/search' });

		const result = await handle({ event, resolve } as any);

		// fetch was never called -- the hook did not attempt to proxy
		expect(stubFetch).not.toHaveBeenCalled();

		// resolve was called with the original event
		expect(resolve).toHaveBeenCalledTimes(1);
		expect(resolve).toHaveBeenCalledWith(event);

		// The hook returns whatever resolve returned
		expect(result).toBe(sentinelResponse);
	});

	// -----------------------------------------------------------------------
	// 4. Hop-by-hop headers are stripped; application headers are forwarded
	// -----------------------------------------------------------------------
	it('strips hop-by-hop headers from the backend response but keeps application headers', async () => {
		const backendHeaders = new Headers([
			['content-type', 'application/json'],
			['x-custom-app-header', 'hello'],
			['transfer-encoding', 'chunked'],
			['connection', 'keep-alive']
		]);
		const backendResponse = makeBackendResponse({ headers: backendHeaders, body: '{}' });
		const stubFetch = vi.fn().mockResolvedValue(backendResponse);
		globalThis.fetch = stubFetch;

		const resolve = vi.fn();
		const event = makeEvent({ pathname: '/api/status' });

		const result = await handle({ event, resolve } as any);

		// Application headers are present
		expect(result.headers.get('content-type')).toBe('application/json');
		expect(result.headers.get('x-custom-app-header')).toBe('hello');

		// Hop-by-hop headers are stripped
		expect(result.headers.get('transfer-encoding')).toBeNull();
		expect(result.headers.get('connection')).toBeNull();
	});

	// -----------------------------------------------------------------------
	// 5. Falls back to localhost:3000 when VITE_API_URL is not set
	// -----------------------------------------------------------------------
	it('falls back to http://localhost:3000 when VITE_API_URL is unset', async () => {
		delete process.env.VITE_API_URL;

		const backendResponse = makeBackendResponse();
		const stubFetch = vi.fn().mockResolvedValue(backendResponse);
		globalThis.fetch = stubFetch;

		const resolve = vi.fn();
		const event = makeEvent({ pathname: '/api/health' });

		await handle({ event, resolve } as any);

		expect(stubFetch).toHaveBeenCalledWith(
			'http://localhost:3000/api/health',
			expect.any(Object)
		);
	});

	// -----------------------------------------------------------------------
	// 6. Handles paths with base path prefix
	// -----------------------------------------------------------------------
	it('proxies requests with base path prefix (e.g., /projects/mtg/api/*)', async () => {
		const backendResponse = makeBackendResponse();
		const stubFetch = vi.fn().mockResolvedValue(backendResponse);
		globalThis.fetch = stubFetch;

		const resolve = vi.fn();
		const event = makeEvent({ pathname: '/projects/mtg/api/inventory' });

		await handle({ event, resolve } as any);

		// The full path including base is forwarded to the backend
		expect(stubFetch).toHaveBeenCalledWith(
			'http://backend:3000/projects/mtg/api/inventory',
			expect.any(Object)
		);
	});
});
