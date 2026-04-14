# Future Backend + AI Architecture

## Goal

Move from:

- `Mobile App -> Supabase DB`

to:

- `Mobile App -> Backend Ingestion -> Processing -> Supabase DB`
- `AI/ML -> enrich processed workouts asynchronously`

This makes workout data cleaner, more reliable, easier to debug, and easier to evolve later.

## Why Change

Current direct-write style is simple, but it has clear limits:

- mobile sends already-computed metrics that may be noisy
- GPS spikes and sensor anomalies can pollute final workout data
- business rules are duplicated in app code
- hard to recompute historical metrics if formulas improve later
- AI features become awkward because raw inputs are not modeled cleanly

## Recommended Target Architecture

```text
Flutter App
  ->
Backend Ingestion API
  ->
Deterministic Processing Layer
  ->
Supabase/Postgres
  ->
Async AI/ML Enrichment
  ->
Derived insights / improved metrics
```

## Recommended Responsibilities

### Mobile App

The app should:

- authenticate the user
- start and stop workout recording
- collect raw GPS and step data
- send raw or lightly normalized sensor batches
- render live estimates locally for UX only

The app should not be the final source of truth for:

- final distance
- final calorie burn
- anomaly filtering
- route cleanup

## Backend Layers

### 1. Ingestion Layer

Purpose:

- receive data from mobile safely
- validate payload shape
- reject malformed data early
- write raw data or staging data

Typical tasks:

- auth check
- request schema validation
- batch size validation
- timestamp sanity checks
- device/session ownership validation

### 2. Deterministic Processing Layer

Purpose:

- produce canonical workout data using rule-based logic
- keep this layer explainable and testable

Typical tasks:

- deduplicate GPS points
- remove impossible jumps
- smooth route noise
- reject impossible speed values
- normalize timestamps
- compute distance, duration, pace, speed, steps, calories baseline
- finalize `workout_sessions`

This layer should exist even if AI is never added.

### 3. AI/ML Enrichment Layer

Purpose:

- improve data quality or produce advanced insight
- run asynchronously after canonical data exists

Examples:

- anomaly detection
- route quality scoring
- calorie estimation enhancement
- workout classification refinement
- effort/fatigue scoring
- personalized recommendation

Important:

- AI should not block saving a workout in phase 1
- AI output should be additive or versioned, not overwrite raw truth blindly

## Recommended Database Design

Use separate table groups for raw, canonical, and derived data.

### Canonical Tables

These are the main tables the app reads most of the time.

#### `workout_sessions`

One final row per workout.

Suggested role:

- workout metadata
- finalized metrics
- processing status
- source quality flags

Suggested important columns:

- `id`
- `user_id`
- `activity_type`
- `mode`
- `started_at`
- `ended_at`
- `duration_sec`
- `distance_km`
- `steps`
- `avg_speed_kmh`
- `calories_kcal`
- `lap_splits`
- `processing_status`
- `data_quality_score`
- `metrics_version`
- `created_at`
- `updated_at`

Suggested processing status vocabulary:

- `client_recording`
- `client_finished_pending_processing`
- `client_finalized`

### Raw / Staging Tables

These keep the original input needed for recomputation.

#### `raw_gps_points`

Use for original GPS batches from device.

Suggested columns:

- `id`
- `workout_id`
- `timestamp`
- `latitude`
- `longitude`
- `altitude`
- `speed`
- `accuracy`
- `heading`
- `device_source`
- `ingested_at`

#### `raw_step_intervals`

Use for original step or pedometer batch input.

Suggested columns:

- `id`
- `workout_id`
- `interval_start`
- `interval_end`
- `steps_count`
- `device_source`
- `ingested_at`

### Cleaned Tables

These are optional but very useful.

#### `gps_points`

Canonical cleaned GPS points used for map display and analytics.

Suggested rule:

- raw data stays in `raw_gps_points`
- cleaned usable points live in `gps_points`

#### `step_sessions` or `step_intervals`

Canonical cleaned step intervals for indoor processing.

## Schema Cleanup Principles

The future backend design should also absorb the database refactoring work so
there is only one long-term schema direction.

### Naming and unit rules

Prefer one naming style consistently:

- heights use `height_cm`, not `height_m`
- durations use `duration_sec`, not `duration_min`
- calories use `calories_kcal`, not generic `calories`
- step interval tables should use `step_intervals` naming rather than
  `step_sessions` when the rows represent time windows rather than full workouts

### Data integrity rules

Prefer explicit constraints on canonical tables:

- `weight_kg > 0`
- `height_cm > 0`
- `duration_sec >= 0`
- `distance_km >= 0`
- `steps >= 0`
- `calories_kcal >= 0`

Prefer foreign keys with `ON DELETE CASCADE` for workout-owned child tables:

- `raw_gps_points`
- `raw_step_intervals`
- `gps_points`
- `step_intervals`
- `workout_processing_jobs`
- `workout_processing_logs`

### Legacy table policy

Legacy tables should not remain part of the long-term architecture.

Current legacy candidates include:

- `users`
- `workouts`
- `gps_tracks`

Keep them only as temporary compatibility surfaces during migration.

### Canonical table roles

Use these roles consistently:

- `workout_sessions` is the canonical workout summary table
- `raw_gps_points` and `raw_step_intervals` store original device input
- `gps_points` and `step_intervals` are optional cleaned/canonical tracking tables
- `workout_processing_jobs` and `workout_processing_logs` track deterministic processing

### Profile modeling rule

Do not store mutable age as a source-of-truth profile field.

Prefer:

- `date_of_birth`

Avoid:

- `age`

Age can always be derived at read time when needed.

### Processing Tables

These make the system professional and debuggable.

#### `workout_processing_jobs`

Track processing state per workout.

Suggested columns:

- `id`
- `workout_id`
- `job_type`
- `status`
- `attempt_count`
- `started_at`
- `finished_at`
- `error_message`
- `created_at`

Recommended initial vocabulary:

- `job_type = deterministic_finalize`
- `status = queued`

#### `workout_processing_logs`

Optional audit log of important processing decisions.

Examples:

- "dropped 12 GPS outliers"
- "route smoothing applied"
- "fallback to step-based distance"

### AI Tables

These should be additive, not tightly coupled to the first rollout.

#### `workout_ai_insights`

Suggested columns:

- `id`
- `workout_id`
- `model_name`
- `model_version`
- `insight_type`
- `score`
- `payload`
- `created_at`

#### `workout_metric_revisions`

Optional versioned metrics if you want improved formulas over time.

Suggested columns:

- `id`
- `workout_id`
- `revision_type`
- `metrics_version`
- `distance_km`
- `calories_kcal`
- `avg_speed_kmh`
- `payload`
- `created_at`

## Recommended API Design

Avoid one giant endpoint that does everything.

Use a workflow like this:

### Workout Lifecycle

1. `POST /workouts/start`
2. `POST /workouts/{id}/gps-batch`
3. `POST /workouts/{id}/step-batch`
4. `POST /workouts/{id}/finish`
5. `POST /workouts/{id}/process` or automatic background trigger

Current app-aligned Supabase lifecycle:

1. create `workout_sessions` shell with `processing_status = client_recording`
2. append `raw_gps_points` / `raw_step_intervals` during recording
3. on stop, upsert canonical session summary with `processing_status = client_finished_pending_processing`
4. enqueue `workout_processing_jobs` with `job_type = deterministic_finalize` and `status = queued`
5. deterministic backend/worker later marks the workout processed/finalized

### Suggested Endpoint Responsibilities

#### `POST /workouts/start`

- create workout shell
- return `workout_id`

#### `POST /workouts/{id}/gps-batch`

- append raw GPS points
- validate batch ownership and timestamp order

#### `POST /workouts/{id}/step-batch`

- append raw step intervals
- validate step values

#### `POST /workouts/{id}/finish`

- mark recording finished
- queue processing job

#### `GET /workouts/{id}`

- return canonical session
- optionally include cleaned route and AI insights

## Processing Strategy

### Phase 1

Synchronous or near-synchronous deterministic processing only.

Store:

- raw sensor data
- canonical workout summary

Do not block on AI.

### Phase 2

Add async job processing.

Examples:

- process workout after finish
- recompute metrics in worker
- store logs and quality scores

### Phase 3

Add AI enrichment.

Examples:

- detect anomalies
- improve calorie estimates
- produce coaching insight

## Recommended Roadmap

### Phase A: Stabilize Current Supabase Schema

Do first:

- finish current profile migration
- keep canonical `workout_sessions`
- keep compatibility tables only where necessary
- add processing-ready metadata to `workout_sessions`
  - `processing_status`
  - `data_quality_score`
  - `metrics_version`
- normalize naming and units across canonical tables
  - `height_cm`
  - `duration_sec`
  - `calories_kcal`
- add missing non-negative and positive constraints
- ensure child workout tables use `ON DELETE CASCADE`
- move profile modeling from mutable `age` to `date_of_birth`

Migration policy in this phase:

- new app code reads and writes only canonical tables
- legacy tables remain read-only compatibility surfaces where needed
- do not delete old tables until at least one stable migration window has passed

### Phase B: Introduce Backend Ingestion

Do next:

- create a backend service in `Node.js` or `FastAPI`
- move final metric computation off the client
- keep mobile app sending raw sensor batches

### Phase C: Add Raw Tables

Add:

- `raw_gps_points`
- `raw_step_intervals`
- processing status columns or job tables

Current implementation status:

- `workout_sessions` processing metadata added
- `raw_gps_points` added
- `raw_step_intervals` added
- `workout_processing_jobs` added
- `workout_processing_logs` added
- app creates `workout_sessions` shell at start
- app batches raw tracking data during recording
- app enqueues deterministic processing intent at finish

### Phase D: Deterministic Processing

Implement:

- outlier filtering
- GPS smoothing
- final distance computation
- finalized calorie baseline
- generation of cleaned `gps_points` / `step_intervals` if needed
- transition from `client_finished_pending_processing` to finalized status

### Phase E: Legacy Cleanup

Only after canonical reads, raw ingestion, and deterministic processing are stable:

- remove code paths that still reference `users`
- remove code paths that still reference `workouts`
- remove code paths that still reference `gps_tracks`
- drop legacy tables after verification and backup

### Phase E: AI Enrichment

Only after the deterministic system is stable:

- anomaly detection
- calorie enhancement
- route quality scoring

## Tech Recommendation

### Good First Production Version

- Supabase Auth
- Supabase Postgres
- small backend service with `FastAPI` or `Node.js`
- async worker or cron/background job

### Why This Is Better Than “DB Only”

- cleaner data
- fewer impossible workouts
- easier debugging
- reproducible calculations
- future AI becomes much easier
- better separation of concerns

## Final Recommendation

The best target is not:

- `Mobile -> DB`

and also not simply:

- `Mobile -> Backend + AI -> DB`

The best target is:

- `Mobile -> Backend Ingestion -> Deterministic Processing -> DB`
- `AI -> async enrichment on top of canonical data`

That gives you a system that is practical now, scalable later, and much safer than putting final metric truth inside the mobile app.
