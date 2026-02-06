/**
 * Formats an ISO8601 timestamp as a human-readable datetime string.
 * Returns "Never" if the timestamp is null or undefined.
 *
 * @param timestamp - ISO8601 timestamp string or null
 * @returns Formatted datetime string (e.g., "Feb 6, 2026, 2:30 PM")
 *
 * @example
 * formatTimestamp('2026-02-06T14:30:00Z') // Returns "Feb 6, 2026, 2:30 PM"
 * formatTimestamp(null) // Returns "Never"
 */
export function formatTimestamp(timestamp: string | null): string {
	if (!timestamp) return 'Never';

	return new Date(timestamp).toLocaleString('en-US', {
		year: 'numeric',
		month: 'short',
		day: 'numeric',
		hour: '2-digit',
		minute: '2-digit'
	});
}
