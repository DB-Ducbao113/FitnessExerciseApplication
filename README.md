<div align="center">
  <img src="assets/logo.png" alt="Aetron logo" width="120" />

  # Aetron

  ### A modern fitness tracking app built with Flutter

  Track workouts, monitor progress, set goals, and keep your fitness journey organized in one clean mobile experience.

  ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
  ![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
  ![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
  ![Riverpod](https://img.shields.io/badge/Riverpod-State%20Management-0E7490?style=for-the-badge)
</div>

---

## Overview

Aetron is a Flutter‑based fitness application designed to help users build consistent workout habits by combining workout tracking, goals, history, and analytics into a single product‑focused experience.  
It supports both indoor and outdoor activities, offers offline‑friendly local persistence, and synchronizes important user data through Supabase.

## Features

- Email/password authentication and account management via Supabase Auth  
- Personal profile setup with avatar management  
- Workout session tracking with live metrics  
- GPS‑based tracking for outdoor activities  
- Step‑based tracking for supported workout flows  
- Workout history and detail screens for later review  
- Progress visualization through analytics and summary views  
- Goal tracking to help users stay consistent

## User Experience

- Clean, fitness‑first mobile interface focused on workout flows  
- Feature‑first Flutter architecture for easier scaling and maintenance  
- Offline‑capable local storage for smoother day‑to‑day usage  
- Remote sync with Supabase for account and workout data  
- Modular state management powered by Riverpod

## Tech Stack

- **Flutter** for cross‑platform mobile app development  
- **Riverpod** + `riverpod_generator` for state management  
- **Supabase** for authentication, database, storage, and edge functions  
- **Isar** for local workout persistence  
- **sqflite** for local profile‑related storage  
- **Freezed** + `json_serializable` for immutable models and code generation  
- **Geolocator**, **flutter_map**, **pedometer** for tracking/location features  
- **fl_chart**, **table_calendar** for analytics and history UI

## Project Structure

```text
lib/
  app/        App bootstrap and app-level wiring
  core/       Shared services, providers, constants, storage, and utilities
  features/   Feature modules organized by domain/data/presentation
  shared/     Reusable helpers, widgets, and formatters

backend/
  database/   SQL reference files
  migrations/ Database migrations
  seed/       Seed data
  supabase/   Supabase functions and related configuration
```

More details are available in:

- `docs/architecture/ARCHITECTURE.md`  
- `docs/api/api_contract.md`

## Core Workflow

Aetron is designed around treating each workout as a well‑defined data pipeline, from recording on device to deterministic processing on the backend.

### 1. Create workout session (client)

- The app creates an initial “shell” workout on the backend.  
- Processing status is set to indicate the session is in client‑side recording.

### 2. Capture realtime tracking data (client)

- GPS: capture GPS points in realtime for outdoor activities.  
- Steps: record step‑based movement for supported workouts.  
- All realtime tracking is stored as raw samples for later deterministic computation.

### 3. End workout session (client)

- The app ends the session and sends a provisional snapshot of key metrics.  
- The backend enqueues a job to compute deterministic canonical metrics.

### 4. Deterministic processing & quality checks (backend)

- Backend reads raw tracking data and recomputes metrics based on valid segments.  
- The system records audit/quality evidence at the segment level.  
- Processing status is updated so the UI can distinguish “provisional” vs “finalized” workouts.

### 5. Display history (client)

- UI reads canonical data from workout session tables by default.  
- The `processing_status` field indicates whether a workout is still processing or fully finalized.

For the current API contract, see `docs/api/api_contract.md`.

## Architecture Overview

### Feature‑first + core/shared

- `lib/features/`: each feature owns its domain, data layer, and presentation.  
- `lib/core/`: infrastructure shared across features (providers, constants, platform services, storage helpers, utilities).  
- `lib/shared/`: reusable UI components and formatting logic shared between features.

More details: `docs/architecture/ARCHITECTURE.md`.

### MVVM for workout recording

The workout recording flow showcases the app’s MVVM‑style separation of concerns:

- **View**: renders UI and sends user intents (start/pause/resume/stop) to the ViewModel.  
- **ViewModel**: manages `WorkoutSessionState`, consumes callbacks from sensors/classifiers, coordinates helper classes.  
- **Controllers**: handle GPS/step lifecycle and environment classification.  
- **Domain services**: apply rules for filtering and evaluating GPS/step updates.  
- **Coordinator**: orchestrates raw data buffering, upload, and enqueueing of processing jobs.

Detailed documentation: `docs/architecture/MVVM_WORKOUT_RECORDING.md`.

## Project Goal

This repository is intended to be more than a Flutter codebase: it is the foundation for a fitness product that helps users:

- move consistently  
- understand workout progress  
- stay motivated via goals and history  
- keep their data available and consistent across sessions and devices  

## Status

The project is actively evolving, with ongoing work on workout flows, tracking reliability, local persistence, and overall product polish.

## Getting Started

```bash
# Clone the repository
git clone https://github.com/DB-Ducbao113/FitnessExerciseApplication.git
cd FitnessExerciseApplication

# Install Flutter dependencies
flutter pub get

# (Optional) Set up Supabase and environment config
# See docs/backend/setup.md (coming soon)

# Run the app
flutter run
```

---

Feel free to open issues or pull requests as the project evolves.
