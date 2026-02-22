import type { Handle } from '@sveltejs/kit';

/** Headers that are meaningful only for a single TCP hop and must not be
 *  forwarded across the proxy boundary. */
const HOP_BY_HOP_HEADERS = new Set(['transfer-encoding', 'connection']);

/**
 * Strip hop-by-hop headers from an incoming Headers object and return a new
 * Headers instance containing only the headers that should be forwarded.
 */
function filterHeaders(source: Headers): Headers {
	const filtered = new Headers();
	source.forEach((value, name) => {
		if (!HOP_BY_HOP_HEADERS.has(name.toLowerCase())) {
			filtered.append(name, value);
		}
	});
	return filtered;
}

/**
 * SvelteKit server hook.
 *
 * Any request whose path starts with `/api/` or `/rails/` (or `${basePath}/api/`
 * or `${basePath}/rails/` when a base path is configured) is proxied to the Rails
 * backend (located at VITE_API_URL inside the Docker network). The full pathname
 * is forwarded unchanged so the backend can handle it at its configured paths.
 * All other requests pass through to SvelteKit's normal route resolution.
 */
export const handle: Handle = async ({ event, resolve }) => {
	const basePath = process.env.PUBLIC_BASE_PATH || '';

	// Match either /api/ or /rails/ paths (with or without base path)
	const isApiRequest =
		event.url.pathname.startsWith('/api/') ||
		event.url.pathname.startsWith('/rails/') ||
		(basePath && event.url.pathname.startsWith(`${basePath}/api/`)) ||
		(basePath && event.url.pathname.startsWith(`${basePath}/rails/`));

	if (!isApiRequest) {
		return resolve(event);
	}

	const backendBase = process.env.VITE_API_URL || 'http://localhost:3000';
	// Forward the full pathname unchanged to the backend
	const targetUrl = `${backendBase}${event.url.pathname}${event.url.search}`;

	// Forward request headers, stripping hop-by-hop headers that came in on
	// the client → SvelteKit leg (e.g. host, connection).
	const outgoingHeaders = filterHeaders(event.request.headers);

	// Debug: log cookies being forwarded
	if (event.url.pathname.includes('discord')) {
		console.log(`[QA-DEBUG] Proxying ${event.request.method} ${event.url.pathname}`);
		console.log(`[QA-DEBUG] Cookies sent to backend: ${outgoingHeaders.get('cookie')}`);
	}

	const proxyInit: RequestInit = {
		method: event.request.method,
		headers: outgoingHeaders,
		redirect: 'manual' // Don't follow redirects - let the browser handle them
	};

	// Only attach a body for methods that carry one.
	if (['POST', 'PATCH', 'PUT', 'DELETE'].includes(event.request.method)) {
		proxyInit.body = await event.request.arrayBuffer();
	}

	const backendResponse = await fetch(targetUrl, proxyInit);

	// Forward the backend's response headers, again stripping hop-by-hop
	// headers that are meaningless once we re-emit the response on a new TCP
	// connection back to the client.
	const responseHeaders = filterHeaders(backendResponse.headers);

	// [QA-DEBUG] Log proxy response details for redirect debugging
	if (backendResponse.status >= 300 && backendResponse.status < 400) {
		console.log(`[QA-DEBUG] Proxy redirect detected:`);
		console.log(`  Request: ${event.request.method} ${event.url.pathname}`);
		console.log(`  Backend URL: ${targetUrl}`);
		console.log(`  Status: ${backendResponse.status}`);
		console.log(`  Location: ${backendResponse.headers.get('location')}`);
		console.log(`  Content-Type: ${backendResponse.headers.get('content-type')}`);
		console.log(`  Content-Length: ${backendResponse.headers.get('content-length')}`);
		console.log(`  Content-Encoding: ${backendResponse.headers.get('content-encoding')}`);
		console.log(`  Forwarded headers:`);
		responseHeaders.forEach((v, k) => console.log(`    ${k}: ${v}`));
	}

	// When using redirect: 'manual', explicitly handle redirects by creating a new
	// Response with the Location header. This ensures browsers properly follow the redirect.
	// Also forward Set-Cookie headers for authentication.
	if (backendResponse.status === 301 || backendResponse.status === 302 || backendResponse.status === 303 || backendResponse.status === 307 || backendResponse.status === 308) {
		const location = backendResponse.headers.get('location');
		const setCookie = backendResponse.headers.get('set-cookie');
		
		console.log(`[QA-DEBUG] Creating explicit redirect response to: ${location}`);
		console.log(`[QA-DEBUG] Set-Cookie header: ${setCookie}`);
		
		const headers: Record<string, string> = {
			'Location': location ?? ''
		};
		
		if (setCookie) {
			headers['Set-Cookie'] = setCookie;
		}
		
		return new Response(null, {
			status: backendResponse.status,
			headers
		});
	}

	return new Response(backendResponse.body, {
		status: backendResponse.status,
		headers: responseHeaders
	});
};
