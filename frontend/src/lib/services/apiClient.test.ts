import { describe, it, expect, vi, beforeEach } from 'vitest';
import { apiClient } from './apiClient';

global.fetch = vi.fn();

describe('apiClient', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	describe('credentials', () => {
		it('includes credentials in GET requests', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 200,
				json: async () => ({ data: 'test' })
			} as Response);

			await apiClient.get('/api/test');

			expect(fetch).toHaveBeenCalledWith(
				'/api/test',
				expect.objectContaining({
					credentials: 'include'
				})
			);
		});

		it('includes credentials in POST requests', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 200,
				json: async () => ({ data: 'test' })
			} as Response);

			await apiClient.post('/api/test', { key: 'value' });

			expect(fetch).toHaveBeenCalledWith(
				'/api/test',
				expect.objectContaining({
					credentials: 'include'
				})
			);
		});

		it('includes credentials in PUT requests', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 200,
				json: async () => ({ data: 'test' })
			} as Response);

			await apiClient.put('/api/test', { key: 'value' });

			expect(fetch).toHaveBeenCalledWith(
				'/api/test',
				expect.objectContaining({
					credentials: 'include'
				})
			);
		});

		it('includes credentials in DELETE requests', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 200,
				json: async () => ({ data: 'test' })
			} as Response);

			await apiClient.delete('/api/test');

			expect(fetch).toHaveBeenCalledWith(
				'/api/test',
				expect.objectContaining({
					credentials: 'include'
				})
			);
		});
	});

	describe('GET requests', () => {
		it('makes GET requests with correct method', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 200,
				json: async () => ({ data: 'test' })
			} as Response);

			const result = await apiClient.get<{ data: string }>('/api/test');

			expect(fetch).toHaveBeenCalledWith(
				'/api/test',
				expect.objectContaining({
					method: 'GET'
				})
			);
			expect(result).toEqual({ data: 'test' });
		});
	});

	describe('DELETE requests', () => {
		it('makes DELETE requests with correct method', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 200,
				json: async () => ({ success: true })
			} as Response);

			const result = await apiClient.delete<{ success: boolean }>('/api/test');

			expect(fetch).toHaveBeenCalledWith(
				'/api/test',
				expect.objectContaining({
					method: 'DELETE'
				})
			);
			expect(result).toEqual({ success: true });
		});
	});

	describe('error handling', () => {
		it('throws error on failed response', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: false,
				status: 404,
				statusText: 'Not Found',
				text: async () => 'Resource not found'
			} as Response);

			await expect(apiClient.get('/api/test')).rejects.toThrow(
				'GET /api/test failed: 404 Not Found - Resource not found'
			);
		});

		it('throws error on server error', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: false,
				status: 500,
				statusText: 'Internal Server Error',
				text: async () => 'Server error'
			} as Response);

			await expect(apiClient.get('/api/test')).rejects.toThrow(
				'GET /api/test failed: 500 Internal Server Error - Server error'
			);
		});

		it('throws error on network failure', async () => {
			vi.mocked(fetch).mockRejectedValue(new Error('Network error'));

			await expect(apiClient.get('/api/test')).rejects.toThrow('Network error');
		});
	});

	describe('POST requests', () => {
		it('sends body as JSON', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 201,
				json: async () => ({ id: 1 })
			} as Response);

			const body = { name: 'test', value: 123 };
			await apiClient.post<{ id: number }>('/api/test', body);

			expect(fetch).toHaveBeenCalledWith(
				'/api/test',
				expect.objectContaining({
					method: 'POST',
					body: JSON.stringify(body),
					headers: expect.objectContaining({
						'Content-Type': 'application/json'
					})
				})
			);
		});
	});

	describe('PUT requests', () => {
		it('sends body as JSON', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 200,
				json: async () => ({ updated: true })
			} as Response);

			const body = { name: 'updated' };
			await apiClient.put<{ updated: boolean }>('/api/test', body);

			expect(fetch).toHaveBeenCalledWith(
				'/api/test',
				expect.objectContaining({
					method: 'PUT',
					body: JSON.stringify(body)
				})
			);
		});
	});

	describe('204 No Content', () => {
		it('returns undefined for 204 responses', async () => {
			vi.mocked(fetch).mockResolvedValue({
				ok: true,
				status: 204,
				json: async () => {
					throw new Error('Should not call json');
				}
			} as Response);

			const result = await apiClient.delete('/api/test');
			expect(result).toBeUndefined();
		});
	});
});
