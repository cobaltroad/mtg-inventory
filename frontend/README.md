# MTG Inventory - Frontend

SvelteKit 2 frontend for the MTG inventory management system with TypeScript, Skeleton UI, and Tailwind CSS.

See the [main README](../README.md) for Docker Compose setup and full-stack integration.

## Tech Stack

- **Framework**: SvelteKit 2 with TypeScript
- **UI Framework**: Svelte 5 (with runes)
- **UI Library**: Skeleton UI v4
- **Styling**: Tailwind CSS v4
- **Icons**: Lucide Svelte
- **Testing**: Vitest + @testing-library/svelte
- **Build**: Vite 7
- **Adapter**: Node.js adapter for production

## Local Development Setup

### Prerequisites

- Node.js 20+
- npm or pnpm

### Installation

```bash
cd frontend
npm install
```

### Running the Dev Server

```bash
npm run dev
```

The development server runs on:

- **Local**: `http://localhost:5173`
- **Docker**: `http://localhost:3001`

## Project Structure

```
frontend/
├── src/
│   ├── routes/              # File-based routing
│   │   ├── +page.svelte     # Homepage
│   │   ├── inventory/       # Inventory pages
│   │   ├── commanders/      # Commander pages
│   │   └── api/             # API proxy handlers
│   │
│   ├── lib/
│   │   ├── components/      # Reusable UI components
│   │   ├── utils/           # Utility functions
│   │   ├── types/           # TypeScript interfaces
│   │   └── stores/          # Svelte stores (if needed)
│   │
│   ├── app.html             # HTML template
│   ├── app.css              # Global styles
│   └── hooks.server.ts      # Server hooks (API proxy)
│
├── static/                  # Static assets
├── tests/                   # Test files
└── build/                   # Production build output
```

## Routing

SvelteKit uses file-based routing:

- `src/routes/+page.svelte` → `/`
- `src/routes/inventory/+page.svelte` → `/inventory`
- `src/routes/commanders/[id]/+page.svelte` → `/commanders/:id`

### Page Types

- `+page.svelte` - Page component
- `+page.ts` - Page load function (client-side)
- `+page.server.ts` - Page load function (server-side)
- `+layout.svelte` - Layout component
- `+error.svelte` - Error page

## API Integration

### API Proxy Configuration

The frontend proxies API requests through `hooks.server.ts` to handle CORS and environment configuration:

```typescript
// hooks.server.ts
export async function handle({ event, resolve }) {
	if (event.url.pathname.startsWith('/api')) {
		// Proxy to backend
	}
	return resolve(event);
}
```

### Making API Calls

**Always use the `base` import for correct routing:**

```typescript
import { base } from '$app/paths';

// ✅ Correct - works in all environments
const response = await fetch(`${base}/api/inventory`);

// ❌ Wrong - hardcoded URLs break in Docker/production
const response = await fetch('http://localhost:3000/api/inventory');
```

### Handling Race Conditions

When multiple widgets load simultaneously (e.g., dashboard), append `?uu` to skip backend memoization:

```typescript
// For concurrent requests (prevents race conditions)
const [inventory, alerts] = await Promise.all([
	fetch(`${base}/api/inventory?uu`),
	fetch(`${base}/api/price_alerts?uu`)
]);

// With existing query params, use &uu
const response = await fetch(`${base}/api/inventory/value_timeline?period=30&uu`);
```

### Error Handling

Always handle errors with user-friendly messages:

```typescript
try {
	const response = await fetch(`${base}/api/inventory`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(data)
	});

	if (!response.ok) {
		throw new Error('Failed to add item');
	}

	const result = await response.json();
	// Handle success
} catch (err) {
	console.error('Error:', err);
	// Show user-friendly error message
}
```

## UI Components & Styling

### Component Library

This project uses a **utility-first approach** with Skeleton UI v4 and Tailwind CSS:

```svelte
<!-- Native HTML with Tailwind classes -->
<button class="variant-filled-primary btn"> Click Me </button>

<div class="card p-4">
	<h2 class="h2">Card Title</h2>
	<p>Card content</p>
</div>
```

### Theme

- **Skeleton Theme**: Crimson
- **Dark Mode**: Supported via `class` strategy
- **Configuration**: `tailwind.config.ts`

### Icon Library

Using **Lucide Svelte** for icons:

```svelte
<script lang="ts">
	import { Plus, Trash2, Edit } from 'lucide-svelte';
</script>

<button>
	<Plus size={16} />
	Add Item
</button>
```

### Import Patterns

Use SvelteKit path aliases for clean imports:

```typescript
// Components
import MyComponent from '$lib/components/MyComponent.svelte';

// Utilities
import { formatPrice } from '$lib/utils/format';

// Types
import type { Card } from '$lib/types/card';

// Stores
import { userPreferences } from '$lib/stores/preferences';
```

## State Management

### Svelte 5 Runes

This project uses **Svelte 5 runes** for reactivity:

```typescript
// Reactive state
let count = $state(0);

// Derived state
let doubled = $derived(count * 2);

// Effects
$effect(() => {
	console.log('Count changed:', count);
});

// Props (in components)
let { title, items = [] } = $props();
```

### Component State

```svelte
<script lang="ts">
	// Local component state
	let isLoading = $state(false);
	let items = $state<Card[]>([]);

	// Derived values
	let totalValue = $derived(items.reduce((sum, item) => sum + item.price, 0));

	// Load data
	async function loadItems() {
		isLoading = true;
		try {
			const response = await fetch(`${base}/api/inventory?uu`);
			items = await response.json();
		} finally {
			isLoading = false;
		}
	}
</script>
```

### Stores (When Needed)

For shared state across components, use Svelte stores:

```typescript
// lib/stores/inventory.ts
import { writable } from 'svelte/store';

export const inventoryItems = writable<Card[]>([]);
```

## Testing

### Run Tests

```bash
# Run all tests
npm run test

# Watch mode
npm run test:watch

# With coverage
npm run test:coverage
```

### Test Structure

```typescript
import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import MyComponent from './MyComponent.svelte';

describe('MyComponent', () => {
	it('renders correctly', () => {
		render(MyComponent, { props: { title: 'Test' } });
		expect(screen.getByText('Test')).toBeInTheDocument();
	});
});
```

### Testing Best Practices

- Test user-facing behavior, not implementation details
- Use `data-testid` for elements without semantic selectors
- Mock API calls with Vitest mocks
- Test error states and loading states

## Type Checking

```bash
# Run TypeScript type checker
npm run check

# Watch mode
npm run check:watch
```

### TypeScript Conventions

```typescript
// Define interfaces in lib/types/
export interface Card {
	id: string;
	name: string;
	price: number;
}

// Use in components
import type { Card } from '$lib/types/card';

let card: Card = $state({
	id: '1',
	name: 'Black Lotus',
	price: 10000
});
```

## Linting & Formatting

### Run Linting

```bash
# Check code style
npm run lint

# Auto-format code
npm run format
```

### Code Style

- **Prettier**: Auto-formatting
- **ESLint**: Code quality rules
- **TypeScript**: Type safety

Configuration files:

- `.prettierrc` - Prettier config
- `eslint.config.js` - ESLint config
- `tsconfig.json` - TypeScript config

## Building for Production

### Create Production Build

```bash
npm run build
```

Output is generated in `build/` directory.

### Preview Production Build

```bash
npm run preview
```

### Adapter Configuration

Using `@sveltejs/adapter-node` for Node.js deployment:

```javascript
// svelte.config.js
import adapter from '@sveltejs/adapter-node';

export default {
	kit: {
		adapter: adapter()
	}
};
```

## Accessibility

### Best Practices

- Use semantic HTML elements (`<button>`, `<nav>`, `<main>`)
- Provide `alt` text for images
- Ensure keyboard navigation works
- Use ARIA labels when needed
- Maintain color contrast ratios
- Test with screen readers

### Example

```svelte
<!-- Good accessibility -->
<button class="btn" aria-label="Delete card from inventory" onclick={handleDelete}>
	<Trash2 size={16} aria-hidden="true" />
	<span class="sr-only">Delete</span>
</button>
```

## Performance Optimization

### Lazy Loading

```svelte
<script lang="ts">
	// Dynamic imports for code splitting
	const HeavyComponent = import('./HeavyComponent.svelte');
</script>

{#await HeavyComponent}
	<p>Loading...</p>
{:then Component}
	<Component.default />
{/await}
```

### Image Optimization

- Use appropriate image formats (WebP, AVIF)
- Set explicit width/height to prevent layout shift
- Lazy load images below the fold
- Use responsive images with `srcset`

## Troubleshooting

### Common Issues

**Vite HMR not working:**

- Check that the dev server is running
- Clear browser cache
- Restart dev server

**TypeScript errors:**

```bash
npm run check
```

**Build failures:**

- Check `package.json` dependencies
- Clear `node_modules` and reinstall: `rm -rf node_modules && npm install`

**API proxy not working:**

- Verify backend is running on port 3000
- Check `hooks.server.ts` configuration
- Inspect network tab in browser DevTools

## Contributing

- Follow TypeScript strict mode conventions
- Write tests for new components
- Use Prettier for formatting: `npm run format`
- Ensure type checking passes: `npm run check`
- Follow Skeleton UI and Tailwind patterns
- Document complex components with JSDoc

## Additional Resources

- [SvelteKit Documentation](https://kit.svelte.dev/)
- [Svelte 5 Runes](https://svelte.dev/docs/svelte/what-are-runes)
- [Skeleton UI Documentation](https://www.skeleton.dev/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)
- [Lucide Icons](https://lucide.dev/)
- [Main Project README](../README.md)
