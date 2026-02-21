import { base } from '$app/paths';

class ApiClient {
	private baseUrl: string;

	constructor() {
		this.baseUrl = base;
	}

	private async request<T>(method: string, endpoint: string, body?: unknown): Promise<T> {
		const url = `${this.baseUrl}${endpoint}`;
		const options: RequestInit = {
			method,
			headers: {
				'Content-Type': 'application/json'
			},
			credentials: 'include'
		};

		if (body) {
			options.body = JSON.stringify(body);
		}

		const response = await fetch(url, options);

		if (!response.ok) {
			const errorText = await response.text();
			throw new Error(
				`${method} ${endpoint} failed: ${response.status} ${response.statusText} - ${errorText}`
			);
		}

		if (response.status === 204) {
			return undefined as T;
		}

		return response.json();
	}

	async get<T>(endpoint: string): Promise<T> {
		return this.request<T>('GET', endpoint);
	}

	async post<T>(endpoint: string, body?: unknown): Promise<T> {
		return this.request<T>('POST', endpoint, body);
	}

	async put<T>(endpoint: string, body?: unknown): Promise<T> {
		return this.request<T>('PUT', endpoint, body);
	}

	async delete<T>(endpoint: string): Promise<T> {
		return this.request<T>('DELETE', endpoint);
	}
}

export const apiClient = new ApiClient();
