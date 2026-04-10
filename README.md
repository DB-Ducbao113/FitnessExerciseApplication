<div align="center">
  <img src="assets/logo.png" alt="Aetron logo" width="120" />
</div>

<div align="center">

# Aetron

### A modern fitness tracking app built with Flutter

Track workouts, monitor progress, set goals, and keep your fitness journey organized in one clean mobile experience.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-State%20Management-0E7490?style=for-the-badge)

</div>

## Overview

Aetron is a Flutter fitness application designed to help users build consistent workout habits. The app combines workout tracking, personal goals, history, and analytics into a single product-focused experience.

It supports both indoor and outdoor activities, uses local persistence for a smoother offline experience, and syncs important user data through Supabase.

## What The App Does

- Lets users register and sign in with Supabase Authentication
- Supports personal profile setup and avatar management
- Tracks workout sessions with live metrics
- Records outdoor activity with GPS-based location tracking
- Tracks step-based movement for supported workout flows
- Stores workout history for later review
- Visualizes progress through analytics and summary screens
- Helps users stay consistent with goal tracking

## Experience Highlights

- Clean fitness-first mobile interface
- Feature-first Flutter architecture for easier scaling
- Offline-capable local storage for smoother day-to-day usage
- Remote sync with Supabase for account and workout data
- Modular state management powered by Riverpod

## Tech Stack

- `Flutter` for cross-platform application development
- `Riverpod` and `riverpod_generator` for state management
- `Supabase` for auth, backend data, storage, and server integration
- `Isar` for workout persistence
- `sqflite` for local profile-related persistence
- `Freezed` and `json_serializable` for immutable models and code generation
- `Geolocator`, `flutter_map`, and `pedometer` for tracking features
- `fl_chart` and `table_calendar` for analytics and history UI

## Project Structure

```text
lib/
  app/        App bootstrap and app-level wiring
  core/       Shared services, providers, constants, storage, and utilities
  features/   Feature modules organized by domain/data/presentation
  shared/     Reusable helpers and formatters
```

More architecture notes are available in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Backend Structure

```text
backend/
  database/   SQL reference files
  migrations/ Database migrations
  seed/       Seed data
  supabase/   Supabase functions and related configuration
```

Current Supabase Edge Functions:

- `workouts-start`
- `workouts-end`
- `gps-track`

## Quick Start

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure environment

Run the app with Supabase credentials:

```bash
flutter run ^
  --dart-define=SUPABASE_URL=your_project_url ^
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

### 3. Generate code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Launch the app

```bash
flutter run
```

### 5. Local helper scripts

- Windows run app: `.\run.bat`
- Windows build release APK: `.\build_release.bat`
- macOS build iOS release: `zsh ./build_ios_release.sh`

## Development Notes

- Keep feature-specific code inside its own module under `lib/features/`
- Use `core/` only for truly shared infrastructure
- Regenerate code after changing Riverpod, Freezed, Isar, or JSON models
- Run formatting and static analysis before pushing changes

```bash
dart format lib docs
dart analyze
```

## Deployment Notes

To deploy Supabase functions from the backend folder:

```bash
cd backend
supabase functions deploy workouts-start
supabase functions deploy workouts-end
supabase functions deploy gps-track
```

## Repository Goal

This repository is not just a Flutter codebase. It is the foundation of a fitness product focused on helping users:

- move consistently
- understand workout progress
- stay motivated through goals and history
- keep their data available across sessions

## Status

The project is actively evolving, with continued work around workout flow, tracking reliability, local persistence, and overall product polish.
