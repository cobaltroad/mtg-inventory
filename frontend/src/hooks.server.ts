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
 * Any request whose path starts with `/api/` is proxied to the Rails backend
 * (located at VITE_API_URL inside the Docker network).  All other requests
 * pass through to SvelteKit's normal route resolution.
 */
export const handle: Handle = async ({ event, resolve }) => {
	if (!event.url.pathname.startsWith('/api/')) {
		return resolve(event);
	}

	const backendBase = process.env.VITE_API_URL || 'http://localhost:3000';
	const targetUrl = `${backendBase}${event.url.pathname}${event.url.search}`;

	// Forward request headers, stripping hop-by-hop headers that came in on
	// the client → SvelteKit leg (e.g. host, connection).
	const outgoingHeaders = filterHeaders(event.request.headers);

	const proxyInit: RequestInit = {
		method: event.request.method,
		headers: outgoingHeaders
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

	return new Response(backendResponse.body, {
		status: backendResponse.status,
		headers: responseHeaders
	});
};
