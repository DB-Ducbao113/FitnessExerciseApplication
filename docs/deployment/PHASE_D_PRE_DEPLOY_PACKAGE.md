# Phase D Pre-Deploy Package

This checklist groups the current local changes before deploying the Phase D
backend processing flow. It is a packaging guide only; deployment should happen
after the commit set is clean.

## Package Goal

Prepare one deployable Phase D package for:

- canonical workout shell creation
- raw GPS and step ingestion
- deterministic finalize job enqueue
- deterministic worker finalization
- segment-level anti-cheat audit evidence
- route correction worker deployment readiness

Do not include AI enrichment, legacy table cleanup, or unrelated profile/home
changes in this package unless they are intentionally committed separately.

## Commit Group 1: Phase D Backend And Docs

Include these files in the Phase D backend commit:

- `README.md`
- `backend/database/schema.sql`
- `backend/database/workouts.sql`
- `backend/seed/dev_seed.sql`
- `backend/run_sql.ps1`
- `backend/migrations/`
- `backend/supabase/migrations/`
- `backend/supabase/functions/workouts-start/index.ts`
- `backend/supabase/functions/workouts-end/index.ts`
- `backend/supabase/functions/gps-track/index.ts`
- `backend/supabase/functions/deterministic-finalize-worker/`
- `backend/supabase/functions/route-correction-worker/index.ts`
- `docs/api/api_contract.md`
- `docs/database/FUTURE_BACKEND_AI_ARCHITECTURE.md`
- `docs/deployment/PHASE_D_PRE_DEPLOY_PACKAGE.md`

Expected behavior:

- `workouts-start` creates `workout_sessions` with `client_recording`.
- `gps-track` writes batches into `raw_gps_points`.
- `workouts-end` stores provisional metrics and queues `deterministic_finalize`.
- `deterministic-finalize-worker` recomputes canonical metrics and sets `client_finalized`.
- `deterministic-finalize-worker` writes `workout_segment_audits` and excludes suspicious/invalid segments from canonical metrics.
- `route-correction-worker` type-checks and is ready to deploy for async route enrichment.

Migration source of truth:

- `backend/supabase/migrations` is the deploy source for `supabase db push`.
- Supabase CLI migration filenames must use unique version prefixes, for
  example `202604260001_workout_segment_audits.sql`.
- `backend/migrations` remains the legacy/manual SQL reference path for now.
- Keep the two migration folders in sync until the legacy path is retired.
- `backend/run_sql.ps1` is the manual apply helper and must include the same Phase D migrations.

## Commit Group 2: Flutter Workout Integration

Include these files with the Phase D app integration commit:

- `lib/features/workout/data/datasources/remote/workout_remote_datasource.dart`
- `lib/features/workout/data/local/local_db.dart`
- `lib/features/workout/data/local/schema/local_workout.dart`
- `lib/features/workout/data/local/schema/local_workout.g.dart`
- `lib/features/workout/data/models/workout_session_model.dart`
- `lib/features/workout/data/models/workout_session_model.freezed.dart`
- `lib/features/workout/data/models/workout_session_model.g.dart`
- `lib/features/workout/domain/entities/workout_session.dart`
- `lib/features/workout/domain/entities/workout_session.freezed.dart`
- `lib/features/workout/presentation/providers/workout_providers.dart`
- `lib/features/workout/presentation/providers/workout_providers.g.dart`
- `lib/features/workout/presentation/screens/record/record_providers.dart`
- `lib/features/workout/presentation/screens/record/record_screen.dart`
- `lib/features/workout/presentation/screens/record/workout_recording_coordinator.dart`
- `lib/features/workout/presentation/screens/record/workout_session_finalizer.dart`
- `lib/features/workout/presentation/screens/summary/workout_summary_screen.dart`
- `lib/features/workout/presentation/screens/details/workout_details_screen.dart`
- `lib/features/history/presentation/widgets/daily_workout_list.dart`
- `lib/shared/formatters/workout_formatters.dart`

Expected behavior:

- app writes `moving_time_sec` through workout models and local cache
- app periodically flushes raw tracking buffers
- app saves live `filtered_route_json` snapshots for route correction
- summary/details screens use the moved details screen path and moving pace data

## Keep Out Of The Phase D Package

Do not include these in the Phase D package unless committing separately:

- `backend/supabase/.temp/cli-latest`
- `lib/core/storage/database_helper.dart`
- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/profile/**`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `pubspec.lock`

Notes:

- `backend/supabase/.temp/cli-latest` is already ignored by `.gitignore`, but
  it is currently tracked and modified. Exclude it from the Phase D commit.
- The profile files appear to belong to the `date_of_birth` / `height_cm`
  compatibility work and should be reviewed as a separate package.
- `pubspec.lock` currently changes transitive test packages; keep it out unless
  dependency resolution was intentional.

## Pre-Deploy Verification

Run from the repository root:

```bash
deno check backend/supabase/functions/workouts-start/index.ts backend/supabase/functions/workouts-end/index.ts backend/supabase/functions/gps-track/index.ts
deno check backend/supabase/functions/deterministic-finalize-worker/index.ts backend/supabase/functions/deterministic-finalize-worker/index_test.ts
deno test backend/supabase/functions/deterministic-finalize-worker/index_test.ts
deno check backend/supabase/functions/route-correction-worker/index.ts
flutter analyze
flutter test
```

## Deploy Checklist

Run only after the package is clean and committed:

```bash
cd backend
supabase db push
supabase functions deploy workouts-start
supabase functions deploy workouts-end
supabase functions deploy gps-track
supabase functions deploy deterministic-finalize-worker
supabase functions deploy route-correction-worker
```

Before running `supabase db push`, confirm `backend/supabase/migrations`
contains the complete ordered migration set through
`202604260001_workout_segment_audits.sql`.

Smoke test one short outdoor workout:

- start creates a shell row with `processing_status = client_recording`
- GPS upload inserts rows into `raw_gps_points`
- step tracking inserts rows into `raw_step_intervals` when available
- stop sets `client_finished_pending_processing`
- a `deterministic_finalize` job is queued
- deterministic worker updates `processing_status = client_finalized`
- finalized row has `data_quality_score`, `metrics_version = 2`, and valid `filtered_route_json`
- `workout_segment_audits` contains valid/suspicious/invalid segment rows
- cycling at `2:00/km` followed by idle time remains flagged and excluded from canonical distance
