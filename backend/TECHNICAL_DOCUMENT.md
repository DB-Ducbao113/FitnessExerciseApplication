# Backend Technical Document

## Scope

This document summarizes the current backend architecture implemented for `FitnessExerciseApplication`, the production-facing data flow used by the Flutter app today, and the next work items required to harden the platform.

The backend stack is centered on Supabase:

- Postgres as the primary system of record
- Row Level Security for per-user isolation
- PostGIS for canonical GPS point storage
- Supabase Storage for avatars
- Supabase Edge Functions scaffolded for workout ingestion
- Flutter app currently writing most workout data directly to Supabase tables

## Current Architecture

### 1. Canonical data model

The main workout record is `public.workout_sessions`.

It stores:

- workout identity and ownership
- activity type and tracking mode
- start/end times and duration
- distance, speed, calories, steps
- lap splits
- processing metadata:
  - `processing_status`
  - `data_quality_score`
  - `metrics_version`

Compatibility tables still exist and are intentionally retained during migration:

- `public.workouts`
- `public.gps_tracks`
- `public.users`
- `public.step_sessions`

New code should prefer:

- `public.workout_sessions`
- `public.gps_points`
- `public.user_profiles`
- `public.user_goals`

### 2. Sensor ingestion model

The backend now supports a two-layer tracking pipeline:

1. Finalized workout data
   - written into `workout_sessions`
2. Raw sensor data
   - written into `raw_gps_points`
   - written into `raw_step_intervals`

This is important because the app no longer relies only on client-side filtered metrics. The backend schema is prepared for future deterministic processing and auditability.

### 3. Processing and audit model

The backend includes:

- `workout_processing_jobs`
- `workout_processing_logs`

These tables support:

- deferred deterministic processing
- future AI-assisted processing
- audit trails for fallback selection, dropped points, smoothing, and validation
- operational debugging for GPS health and tracking reliability

Recent client work now sends GPS health events into `workout_processing_logs`, including:

- `gps_stream_error`
- `gps_stream_done`
- `gps_stream_stalled`
- `gps_recovery_started`
- `gps_recovery_succeeded`
- `gps_recovery_failed`

### 4. User and profile model

User body/profile data is stored in `public.user_profiles`.

Canonical fields:

- `weight_kg`
- `height_cm`
- `date_of_birth`
- `gender`
- `avatar_url`

Legacy compatibility remains during rollout:

- `height_m`
- `age`

Goals are stored in `public.user_goals`, one row per user.

### 5. Reporting model

Derived views are already present:

- `v_user_stats`
- `v_weekly_stats`
- `v_monthly_sessions`

These support dashboard and history-style summaries without forcing the app to aggregate everything client-side.

## Database Modules

### `database/schema.sql`

Bootstrap entrypoint. It enables required extensions:

- `uuid-ossp`
- `pgcrypto`
- `postgis`

It also defines the SQL application order for all table modules and migrations.

### `database/users.sql`

Legacy public mirror of auth users.

Status:

- retained for compatibility only
- not the preferred source of truth

### `database/user_metrics.sql`

Defines `user_profiles`.

Status:

- active and canonical for profile/body metrics
- supports compatibility migration from older app builds

### `database/workouts.sql`

Defines `workout_sessions` and legacy `workouts`.

Status:

- `workout_sessions` is the canonical table for current app logic
- includes processing metadata and lap split support

### `database/gps_tracks.sql`

Defines:

- `gps_tracks` for legacy compatibility
- `gps_points` as canonical GPS storage
- `step_sessions` for legacy-compatible indoor intervals

Status:

- `gps_points` is the preferred canonical GPS representation
- uses `geography(point, 4326)` with a GiST index

### `database/raw_tracking.sql`

Defines:

- `raw_gps_points`
- `raw_step_intervals`

Status:

- active and aligned with the current recording coordinator in the app
- intended for backend-owned cleanup and validation in the future

### `database/processing.sql`

Defines:

- `workout_processing_jobs`
- `workout_processing_logs`

Status:

- active and already used by the app for deterministic enqueue logging
- now also used for GPS health observability

### `database/views.sql`

Derived statistics views for reporting.

Status:

- implemented
- useful for dashboard/history read models

## Migrations Already Implemented

### `20260311_user_goals.sql`

- adds `user_goals`
- includes RLS

### `20260311_add_avatar_url.sql`

- adds `avatar_url` support
- creates/uses `avatars` storage bucket
- adds storage policies

### `20260324_add_workout_lap_splits.sql`

- adds `lap_splits` to `workout_sessions`

### `20260413_user_profiles_compatibility.sql`

- adds `height_cm`
- adds `date_of_birth`
- backfills `height_cm` from `height_m`
- adds compatibility constraints and index

### `20260413_workout_processing_metadata.sql`

- adds `processing_status`
- adds `data_quality_score`
- adds `metrics_version`
- adds processing status index

### `20260413_raw_tracking_tables.sql`

- adds raw sensor ingestion tables and policies

### `20260413_workout_processing_jobs.sql`

- adds processing job queue table and policies

### `20260413_workout_processing_logs.sql`

- adds processing log table and policies

## Security Model

RLS is consistently applied across the main domain tables.

Pattern used:

- authenticated users can only see their own rows
- inserts are constrained using `auth.uid()`
- linked workout child tables validate ownership through `workout_sessions`

This is implemented for:

- `user_profiles`
- `user_goals`
- `workout_sessions`
- `gps_points`
- `raw_gps_points`
- `raw_step_intervals`
- `workout_processing_jobs`
- `workout_processing_logs`
- storage objects in the `avatars` bucket

## Runtime Data Flow Used By The App Today

The current Flutter production path is table-first, not edge-function-first.

### Workout start

The app creates a remote workout shell directly in `workout_sessions` through `WorkoutRemoteDataSource.createSessionShell(...)`.

Initial values include:

- client-generated session id
- user id
- activity type
- mode
- `processing_status = client_recording`
- `metrics_version = 1`

### During recording

The app buffers and flushes:

- raw GPS batches to `raw_gps_points`
- raw step batches to `raw_step_intervals`

The app now also watches GPS health and logs recovery-related telemetry to `workout_processing_logs`.

### Workout stop

The app finalizes and upserts the completed `workout_sessions` row, then enqueues a deterministic processing job in `workout_processing_jobs`, and writes the enqueue payload into `workout_processing_logs`.

The payload already includes:

- workout summary metrics
- raw buffer counts
- activity consistency assessment

## Supabase Edge Functions

Three functions are scaffolded:

- `workouts-start`
- `gps-track`
- `workouts-end`

Current status:

- they validate auth correctly
- they insert/update canonical tables
- they are usable as backend endpoints
- but they are not the primary ingestion path used by the Flutter app today

This means the backend currently has two ingestion styles available:

1. direct table writes from the client
2. edge-function mediated writes

That is workable short term, but should be unified to avoid duplicate maintenance.

## Tooling and Local Operations

### SQL apply workflow

`backend/run_sql.ps1` applies schema and migrations in the correct order using `psql`.

Default local DB target:

- `postgresql://postgres:postgres@127.0.0.1:54322/postgres`

### Local Supabase project

`backend/supabase/config.toml` is present and configured.

Current local ports include:

- API `54321`
- DB `54322`
- Studio `54323`
- Inbucket `54324`

### Local tooling status on this machine

Installed in user space:

- `supabase` CLI
- `psql`
- `docker` client

Current blocker:

- Docker daemon/runtime is not running on this machine, so `supabase start` and `supabase status` cannot work yet

## Backend Readiness Assessment

### What is already solid

- canonical workout schema exists
- raw sensor ingestion tables exist
- processing queue and audit tables exist
- RLS is broadly implemented
- profile/goals/storage schema exists
- compatibility migrations were planned, not improvised
- app now emits GPS observability logs to the backend plan

### What is still transitional

- legacy compatibility tables still remain
- edge functions exist but are not the single source of ingestion
- local Supabase stack is not yet runnable on this machine because Docker daemon is missing
- deterministic backend worker is not yet implemented to consume `workout_processing_jobs`

## Recommended Next Work

### Priority 1: operational correctness

1. Make sure the remote Supabase project has all SQL applied in the documented order.
2. Verify `workout_processing_logs` receives GPS health events from real device sessions.
3. Add dashboards or SQL queries for stalled stream rate, recovery success rate, and per-device error frequency.

### Priority 2: processing pipeline completion

1. Implement the backend worker that consumes `workout_processing_jobs`.
2. Move deterministic cleanup into backend-owned logic:
   - GPS outlier rejection
   - smoothing
   - step/GPS reconciliation
   - data quality scoring
   - final `processing_status` updates
3. Persist processing outputs and not only logs.

### Priority 3: architecture cleanup

1. Choose one ingestion path as the long-term standard:
   - direct client-to-table writes
   - or edge-function ingestion
2. If edge functions become canonical, migrate the app to call them consistently.
3. If direct writes remain canonical, keep edge functions only for admin/internal workflows or remove them.

### Priority 4: data model hardening

1. Plan retirement of legacy tables:
   - `users`
   - `workouts`
   - `gps_tracks`
   - `step_sessions`
2. Add explicit migration notes and cutover conditions.
3. Consider stronger enum/check enforcement on `activity_type` and `mode` in `workout_sessions`.

### Priority 5: developer operations

1. Finish local Docker runtime setup so `supabase start` works.
2. Add a macOS setup guide for:
   - Docker runtime
   - Supabase CLI
   - psql
3. Add a reproducible backend validation checklist for every schema change.

## Recommended Validation Checklist

For every backend release or schema change:

1. Apply SQL to a clean environment.
2. Confirm RLS for read/write on all modified tables.
3. Record one outdoor GPS workout and one indoor fallback workout.
4. Confirm:
   - `workout_sessions` row created
   - `raw_gps_points` and/or `raw_step_intervals` inserted
   - `workout_processing_jobs` row inserted
   - `workout_processing_logs` contains finish and GPS health events
5. Confirm excluded workouts are still saved but do not count toward goals.

## Final Recommendation

The backend is no longer just a simple storage layer. It has already evolved into a processing-ready workout telemetry platform.

The highest-value next move is not adding more tables. It is finishing the deterministic processing worker and unifying the ingestion path so the backend becomes the authoritative place for workout quality, auditability, and result acceptance.
