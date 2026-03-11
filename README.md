# FlowFit - Fitness Exercise Application

An enterprise-grade Flutter application for comprehensive fitness tracking. Designed with an Offline-First architecture, robust Riverpod state management, a Supabase backend, and local SQLite for seamless offline capabilities.

## 🌟 Key Features

### 🔐 Authentication & Profiles
- Email/Password login and registration powered by **Supabase Auth**.
- Secure, persistent user sessions.
- **User Profiles**: Manage personal information (Age, Weight, Height) and set progressive **Fitness Goals** (Distance, Frequency, Calories).
- Avatars and metric tracking.

### 🏃‍♂️ Comprehensive Workout Tracking
- **Multi-Activity Support**: Track various activities including Running, Cycling, Walking, Swimming, Yoga, and Weights.
- **Indoor Activities**: Integrates with the device's pedometer (`pedometer` plugin) to measure steps and estimate distance/calories for indoor routines.
- **Outdoor Activities**: High-precision **GPS tracking** (`flutter_map`, `geolocator`, `latlong2`). Records real-time polyline routes, calculates accurate pace, total distance, and time.
- **Live Metrics**: Foreground tracking with precise UI updates and wakelocks to prevent the OS from killing ongoing sessions.
- **Review & Playback**: View your completed GPS routes drawn precisely on an interactive map, along with summary statistics.

### 📊 Statistics & History
- **Interactive Charts**: Visualizations (`fl_chart`) of burned calories, distances covered, and goal progress.
- **Workout History**: Interactive Calendar (`table_calendar`) logging all daily activities and completed routines, automatically adjusted to local timezones.

### � Offline-First Synchronization
- **Zero Latency**: Rapid local reads/writes using SQLite (`sqflite`).
- **Background Sync**: Automatic queue-based synchronization pushing local changes to Supabase Postgres databases and Edge Functions when the internet is restored.
- **Conflict Management**: Ensures remote and local state remain perfectly aligned without user intervention.

## 🏗️ Enterprise Architecture

The codebase is structured using an **Enterprise Feature-First** pattern. This ensures maximum scalability, maintainability, and isolated domains for large development teams.

```text
lib/
├── config/              # Environments, Themes, Routes, Constants
├── core/                # Core abstractions, Error handling, Base clients
├── features/            # Feature-first modules (Isolated UI & logic)
│   ├── auth/            # Authentication flows
│   ├── history/         # Calendar and past workout logs
│   ├── home/            # Main dashboard and recent activities
│   ├── profile/         # User profile, settings, and goal definitions
│   ├── settings/        # Application preferences
│   ├── statistics/      # Charts and metric analysis
│   └── workout/         # Live tracking, maps, and pedometer services
├── models/              # Shared data definitions and Serialization (Freezed)
├── providers/           # Global dependency injection via Riverpod
├── services/            # Infrastructure: Supabase, local DB, APIs
├── utils/               # Formatters, Extensions, Validators
└── widgets/             # Reusable, stateless UI components
```

## 🛠️ Technology Stack

- **Framework:** Flutter 3.10+
- **State Management:** Riverpod 2.4+
- **Local Database:** SQLite (`sqflite`)
- **Backend:** Supabase (PostgreSQL, Auth, Edge Functions)
- **Edge Functions (Deno):** Handles complex backend validations (`workouts-start`, `workouts-end`, `gps-track`).
- **Code Generation:** Freezed, JSON Serializable, Riverpod Generator
- **Sensors & Maps:** Geolocator, Pedometer, Wakelock Plus, Latlong2, Flutter Map

## 🚀 Setup Instructions

### Prerequisites
- Flutter SDK 3.10+
- A Supabase Project ([supabase.com](https://supabase.com))

### 1. Clone & Install dependencies
```bash
git clone <repository-url>
cd fitness_exercise_application
flutter pub get
```

### 2. Connect to Supabase
Create a `.env` file in the root directory:
```env
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_anon_key
```

### 3. Database Schema Setup
Run the provided SQL initialization scripts found in `backend/database/` (or wherever your migration scripts are located) inside your Supabase Project's SQL Editor:
- `users.sql`
- `workouts.sql`
- `gps_tracks.sql`
- `user_metrics.sql`

### 4. Deploy Deno Edge Functions
The backend relies on Deno-based edge functions to process operations reliably. Navigate to the `backend/supabase` folder and deploy:
```bash
cd backend
supabase functions deploy workouts-start
supabase functions deploy workouts-end
supabase functions deploy gps-track
```

### 5. Code Generation
Because Riverpod and Freezed rely heavily on generated code, you must run build_runner:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 6. Run the App
```bash
flutter run
```

## 👨‍💻 Development Guidelines

- **Component Isolation:** Ensure new screens/logic are placed inside their respective `features/` directory.
- **Dependency Injection:** Expose services and repositories via `providers/` instead of creating strict Singleton instances.
- **Auto code-gen:** Whenever modifying `.freezed`, `.g.dart` mappings, or Annotated Riverpod providers, execute `dart run build_runner watch` in a secondary terminal.
- **Validation:** Always run `flutter format .` and `flutter analyze` before creating a pull request.

## 📄 License
[Your License Details]
