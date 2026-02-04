# MTG Inventory - Frontend

SvelteKit frontend for the MTG (Magic: The Gathering) inventory management system.

## Tech Stack

- **Framework**: SvelteKit 2 with TypeScript
- **UI Framework**: Svelte 5 (with runes)
- **UI Library**: Skeleton UI v4
- **Styling**: Tailwind CSS v4
- **Icons**: Lucide Svelte
- **Testing**: Vitest + @testing-library/svelte
- **Build**: Vite 7

## Development

Install dependencies:

```sh
npm install
```

Start development server:

```sh
npm run dev
```

The development server will run on `http://localhost:5173` (or `http://localhost:3001` in Docker).

## Testing

Run tests:

```sh
npm run test          # Run all tests once
npm run test:watch    # Run tests in watch mode
```

Type checking:

```sh
npm run check         # TypeScript type checking
```

Linting and formatting:

```sh
npm run lint          # Check code style
npm run format        # Auto-format code
```

## Building

Create a production build:

```sh
npm run build
```

Preview the production build:

```sh
npm run preview
```

## Architecture

- **Routes**: File-based routing in `src/routes/`
- **Components**: Shared components in `src/lib/components/`
- **Utilities**: Helper functions in `src/lib/utils/`
- **Types**: TypeScript interfaces in `src/lib/types/`

## UI Components

This project uses a utility-first approach with native HTML elements styled using Tailwind CSS and Skeleton UI utilities:

- **Buttons**: Native `<button>` with Tailwind classes
- **Inputs**: Native `<input>` with Tailwind classes
- **Cards**: Native `<div>` with card styling
- **Tables**: Native `<table>` with responsive utilities
- **Icons**: Lucide Svelte icon components

## Theme

- **Skeleton Theme**: Crimson
- **Dark Mode**: Supported via `class` strategy
- All components have dark mode styling

## API Integration

The frontend connects to the Rails backend API. API calls are proxied through `hooks.server.ts` to handle CORS and path configuration.

## Deployment

This project uses `@sveltejs/adapter-node` for production deployment. The adapter is configured in `svelte.config.js`.

## More Information

See the main project README and CLAUDE.md for architecture details and development guidelines.
