# Fitness Exercise Application

Flutter application for tracking fitness activities with offline-first
architecture using Clean Architecture, Riverpod state management, and Supabase
backend.

## Features

- ✅ **Authentication** - Email/password login and registration with Supabase
  Auth
- ✅ **Offline-First** - SQLite local database with automatic background sync
- ✅ **Clean Architecture** - Separation of domain, data, and presentation
  layers
- ✅ **State Management** - Riverpod with code generation
- 🚧 **Workout Tracking** - Start, track, and end workout sessions (in progress)
- 🚧 **GPS Tracking** - Real-time location tracking during workouts (in
  progress)

## Architecture

### Project Structure

```
lib/
├── domain/              # Business logic layer
│   ├── entities/        # Domain models (Workout, GPSTrack)
│   └── repositories/    # Repository interfaces
├── data/                # Data layer
│   ├── models/          # Data models with JSON/SQLite serialization
│   ├── datasources/     # Local (SQLite) and Remote (Supabase) data sources
│   └── repositories/    # Repository implementations
└── presentation/        # UI layer
    ├── providers/       # Riverpod providers for DI and state
    ├── screens/         # App screens (auth, home, workout)
    └── widgets/         # Reusable UI components
```

### Technology Stack

- **Framework:** Flutter 3.x
- **State Management:** Riverpod 2.4.0 with code generation
- **Local Database:** SQLite (sqflite)
- **Backend:** Supabase (Auth + PostgreSQL + Edge Functions)
- **Code Generation:** Freezed, JSON Serializable, Riverpod Generator

## Setup Instructions

### Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- A Supabase account and project

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd fitness_exercise_application
flutter pub get
```

### 2. Configure Supabase

1. Create a Supabase project at https://supabase.com
2. Go to **Settings → API** in your Supabase dashboard
3. Copy your **Project URL** and **anon public key**
4. Create a `.env` file in the project root:

```env
SUPABASE_URL=your_project_url_here
SUPABASE_ANON_KEY=your_anon_key_here
```

### 3. Set Up Database Schema

Run the SQL scripts in `backend/sql/` to create the required tables:

```sql
-- Run these in Supabase SQL Editor
backend/sql/users.sql
backend/sql/workouts.sql
backend/sql/gps_tracks.sql
backend/sql/user_metrics.sql
```

### 4. Deploy Edge Functions (Optional)

If you want to use the backend Edge Functions:

```bash
cd backend
supabase functions deploy workouts-start
supabase functions deploy workouts-end
supabase functions deploy gps-track
```

### 5. Run Code Generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 6. Run the App

```bash
# With environment variables
flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key

# Or configure in your IDE's run configuration
```

## Development

### Running Tests

```bash
flutter test
flutter test --coverage
```

### Code Generation

When you modify Freezed models or Riverpod providers:

```bash
dart run build_runner watch
```

### Linting

```bash
flutter analyze
```

## Backend Security

All Edge Functions use JWT authentication:

- Extract `user_id` from JWT token, not from request body
- Validate Authorization header on every request
- Use `SUPABASE_ANON_KEY` (not service role key) for client operations

## Offline-First Strategy

1. **Write operations:** Save to local SQLite first, then sync to Supabase
2. **Read operations:** Return local data immediately, sync in background
3. **Conflict resolution:** Last-write-wins (can be customized)
4. **Sync status:** Track `synced` flag in local database

## Project Status

### ✅ Completed (Phase 1)

- Clean Architecture foundation
- Riverpod state management setup
- SQLite offline database
- Supabase integration
- Backend security fixes
- Authentication screens

### 🚧 In Progress (Phase 2)

- Workout tracking flows
- GPS tracking implementation
- Workout history display
- Testing infrastructure

### 📋 Planned

- User profile management
- Workout statistics and analytics
- Social features
- Health platform integration

## Contributing

1. Follow Clean Architecture principles
2. Use Riverpod for state management
3. Write tests for new features
4. Run `flutter analyze` before committing
5. Use conventional commits

## License

[Your License Here]
