# Aetron - Fitness Exercise Application

A Flutter mobile fitness app with Supabase authentication, indoor and outdoor workout tracking, offline-capable local storage, and a feature-first architecture.

## Core Features

- Email/password authentication with Supabase Auth
- User profile setup, avatars, and personal goal tracking
- Indoor workouts with pedometer-based step tracking
- Outdoor workouts with GPS route capture and live metrics
- Workout history, calendar view, and analytics dashboards
- Offline-first local caching with sync back to Supabase

## Project Layout

### Mobile App

```text
lib/
  app/        # App bootstrap and root widget wiring
  core/       # Shared infrastructure: constants, providers, services, storage, utils
  features/   # Feature-first modules with domain/data/presentation
  shared/     # Reusable helpers such as formatters
```

Architecture notes live in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Backend

```text
backend/
  database/   # SQL reference files
  migrations/ # SQL migrations
  seed/       # Seed data
  supabase/   # Supabase config, snippets, and Edge Functions
```

Current Edge Functions:

- `backend/supabase/functions/workouts-start`
- `backend/supabase/functions/workouts-end`
- `backend/supabase/functions/gps-track`

## Technology Stack

- Flutter
- Riverpod
- Supabase
- Isar
- SQLite (`sqflite`)
- Freezed / JSON Serializable / Riverpod Generator
- Geolocator / Flutter Map / Pedometer

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

Provide credentials with Dart defines:

```bash
flutter run ^
  --dart-define=SUPABASE_URL=your_project_url ^
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

### 3. Generate code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the app

```bash
flutter run
```

## Backend Deployment

If you need to deploy Supabase functions:

```bash
cd backend
supabase functions deploy workouts-start
supabase functions deploy workouts-end
supabase functions deploy gps-track
```

## Development Notes

- Keep feature-owned code inside its feature folder.
- Put only truly shared infrastructure in `core/`.
- Run `dart format lib docs` and `dart analyze` before committing.
- Regenerate code after changing Riverpod, Freezed, or JSON-serializable sources.
