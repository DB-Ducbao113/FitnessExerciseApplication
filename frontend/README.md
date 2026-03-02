# Fitness Tracker Frontend

Production-grade authentication system built with React, TypeScript, and
Supabase.

## Setup

1. Install dependencies:

```bash
npm install
```

2. Create `.env` file from template:

```bash
cp .env.example .env
```

3. Add your Supabase credentials to `.env`:

```
VITE_SUPABASE_URL=your_supabase_project_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

## Development

Start the development server:

```bash
npm run dev
```

The app will open at `http://localhost:3000`

## Build

Create production build:

```bash
npm run build
```

Preview production build:

```bash
npm run preview
```

## Features

- ✅ Email/Password authentication
- ✅ Session persistence across page reloads
- ✅ Protected routes with auth guards
- ✅ Automatic session refresh
- ✅ Auth state synchronization
- ✅ Clean error handling
- ✅ Loading states
- ✅ TypeScript type safety

## Architecture

- **Auth Service** (`src/services/auth.service.ts`) - Clean wrapper around
  Supabase Auth
- **useAuth Hook** (`src/hooks/useAuth.ts`) - Reactive auth state management
- **Route Guards** (`src/components/`) - Protected and public route components
- **Supabase Client** (`src/lib/supabase.ts`) - Single source of truth for
  Supabase instance

## Security

- Uses Supabase anon key only (no service role key)
- No manual JWT storage or handling
- Session managed entirely by Supabase SDK
- No user_id passed from frontend to backend
- Environment variables not committed to git
