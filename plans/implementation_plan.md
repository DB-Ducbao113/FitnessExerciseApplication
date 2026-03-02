# Authentication System Implementation Plan

Production-grade authentication flow using Supabase Auth for fitness tracking
application frontend.

## User Review Required

> [!IMPORTANT]
> **Project Structure Decision**
>
> I will create a standalone React + TypeScript web frontend in
> `c:\IU\PreW2\fitness_exercise_application\frontend\` directory. This will be
> separate from the Flutter mobile app but can share the same Supabase backend.
>
> **Alternative**: If you prefer to work within Flutter web, please let me know
> and I'll adjust the approach.

> [!WARNING]
> **Environment Variables Required**
>
> You will need to provide:
>
> - `VITE_SUPABASE_URL` - Your Supabase project URL
> - `VITE_SUPABASE_ANON_KEY` - Your Supabase anonymous/public key
>
> These will be configured in `.env` file (not committed to git).

## Proposed Changes

### Frontend Application Structure

Creating a new React + TypeScript application with Vite as the build tool for
optimal development experience and production performance.

---

#### [NEW] [package.json](file:///c:/IU/PreW2/fitness_exercise_application/frontend/package.json)

Dependencies:

- `react` + `react-dom` - UI framework
- `@supabase/supabase-js` - Supabase client SDK
- `react-router-dom` - Routing with auth guards
- `vite` - Build tool and dev server
- TypeScript tooling

#### [NEW] [tsconfig.json](file:///c:/IU/PreW2/fitness_exercise_application/frontend/tsconfig.json)

Strict TypeScript configuration for type safety.

#### [NEW] [vite.config.ts](file:///c:/IU/PreW2/fitness_exercise_application/frontend/vite.config.ts)

Vite configuration with React plugin.

#### [NEW] [.env.example](file:///c:/IU/PreW2/fitness_exercise_application/frontend/.env.example)

Template for required environment variables.

---

### Core Authentication Layer

#### [NEW] [src/lib/supabase.ts](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/lib/supabase.ts)

Supabase client initialization with anon key only. Single source of truth for
the client instance.

#### [NEW] [src/services/auth.service.ts](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/services/auth.service.ts)

Clean auth service wrapper providing:

- `signIn(email, password)` - Email/password authentication
- `signUp(email, password)` - User registration
- `signOut()` - Session termination
- `getSession()` - Current session retrieval
- `onAuthStateChange(callback)` - Auth state listener

All methods return typed responses with proper error handling.

#### [NEW] [src/hooks/useAuth.ts](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/hooks/useAuth.ts)

React hook for auth state management:

- Subscribes to auth state changes
- Provides current user and session
- Exposes loading state
- Auto-cleanup on unmount

---

### Routing Infrastructure

#### [NEW] [src/components/ProtectedRoute.tsx](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/components/ProtectedRoute.tsx)

Route guard component:

- Blocks unauthenticated access to protected routes
- Redirects to login when no session
- Shows loading state during session check

#### [NEW] [src/components/PublicRoute.tsx](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/components/PublicRoute.tsx)

Inverse guard for auth pages:

- Redirects authenticated users away from login/register
- Prevents logged-in users from accessing auth screens

#### [NEW] [src/router/index.tsx](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/router/index.tsx)

Application routing configuration with guards applied.

---

### Authentication UI

#### [NEW] [src/pages/Login.tsx](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/pages/Login.tsx)

Login screen with:

- Email and password inputs
- Form validation
- Loading state during submission
- Error display
- Link to registration

#### [NEW] [src/pages/Register.tsx](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/pages/Register.tsx)

Registration screen with:

- Email and password inputs
- Password confirmation
- Client-side validation
- Loading state
- Error handling
- Link to login

#### [NEW] [src/pages/Dashboard.tsx](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/pages/Dashboard.tsx)

Protected main app screen:

- Displays authenticated user info
- Sign out functionality
- Placeholder for workout features

---

### Application Entry

#### [NEW] [src/App.tsx](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/App.tsx)

Root component with router provider.

#### [NEW] [src/main.tsx](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/main.tsx)

Application entry point with React 18 root API.

#### [NEW] [index.html](file:///c:/IU/PreW2/fitness_exercise_application/frontend/index.html)

HTML shell for the SPA.

---

### Styling

#### [NEW] [src/styles/global.css](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/styles/global.css)

Clean, minimal global styles with:

- CSS custom properties for theming
- Responsive form layouts
- Loading states
- Error message styling

---

### Type Definitions

#### [NEW] [src/types/auth.types.ts](file:///c:/IU/PreW2/fitness_exercise_application/frontend/src/types/auth.types.ts)

TypeScript interfaces for auth-related types ensuring type safety across the
application.

## Verification Plan

### Automated Tests

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build
```

### Manual Verification

1. **Registration Flow**
   - Navigate to `/register`
   - Create account with email/password
   - Verify redirect to dashboard on success
   - Verify error handling for duplicate email

2. **Login Flow**
   - Navigate to `/login`
   - Sign in with credentials
   - Verify redirect to dashboard
   - Verify error handling for invalid credentials

3. **Session Persistence**
   - Login successfully
   - Refresh the page
   - Verify user remains authenticated
   - Verify no flash of login screen

4. **Route Protection**
   - While logged out, attempt to access `/dashboard`
   - Verify redirect to `/login`
   - While logged in, attempt to access `/login`
   - Verify redirect to `/dashboard`

5. **Sign Out**
   - Click sign out button
   - Verify redirect to login
   - Verify session cleared
   - Verify cannot access protected routes

6. **Auth State Reactivity**
   - Open app in two tabs
   - Sign out in one tab
   - Verify other tab reacts to auth state change
