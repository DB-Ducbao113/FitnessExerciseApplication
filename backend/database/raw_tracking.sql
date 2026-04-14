-- ================================================================
-- raw_tracking.sql
-- Raw sensor ingestion tables for future backend-owned processing.
-- These tables store the original device input before deterministic cleanup.
-- ================================================================

create table if not exists public.raw_gps_points (
  id             bigint generated always as identity primary key,
  workout_id     uuid not null references public.workout_sessions(id) on delete cascade,
  timestamp      timestamptz not null,
  latitude       double precision not null,
  longitude      double precision not null,
  altitude       float8,
  speed          float8,
  accuracy       float8,
  heading        float8,
  device_source  text,
  ingested_at    timestamptz not null default now()
);

comment on table public.raw_gps_points is
  'Raw GPS points as received from the client or ingestion backend before cleanup and smoothing.';

create index if not exists idx_raw_gps_points_workout
  on public.raw_gps_points (workout_id);

create index if not exists idx_raw_gps_points_workout_timestamp
  on public.raw_gps_points (workout_id, timestamp);

alter table public.raw_gps_points enable row level security;

drop policy if exists "raw_gps_points: select own" on public.raw_gps_points;
create policy "raw_gps_points: select own"
  on public.raw_gps_points for select
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = raw_gps_points.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "raw_gps_points: insert own" on public.raw_gps_points;
create policy "raw_gps_points: insert own"
  on public.raw_gps_points for insert
  to authenticated
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = raw_gps_points.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "raw_gps_points: delete own" on public.raw_gps_points;
create policy "raw_gps_points: delete own"
  on public.raw_gps_points for delete
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = raw_gps_points.workout_id
        and ws.user_id = auth.uid()
    )
  );

create table if not exists public.raw_step_intervals (
  id             bigint generated always as identity primary key,
  workout_id     uuid not null references public.workout_sessions(id) on delete cascade,
  interval_start timestamptz not null,
  interval_end   timestamptz not null,
  steps_count    int not null check (steps_count >= 0),
  device_source  text,
  ingested_at    timestamptz not null default now()
);

comment on table public.raw_step_intervals is
  'Raw pedometer or step interval batches as received from the client before processing.';

create index if not exists idx_raw_step_intervals_workout
  on public.raw_step_intervals (workout_id);

create index if not exists idx_raw_step_intervals_workout_start
  on public.raw_step_intervals (workout_id, interval_start);

alter table public.raw_step_intervals enable row level security;

drop policy if exists "raw_step_intervals: select own" on public.raw_step_intervals;
create policy "raw_step_intervals: select own"
  on public.raw_step_intervals for select
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = raw_step_intervals.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "raw_step_intervals: insert own" on public.raw_step_intervals;
create policy "raw_step_intervals: insert own"
  on public.raw_step_intervals for insert
  to authenticated
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = raw_step_intervals.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "raw_step_intervals: delete own" on public.raw_step_intervals;
create policy "raw_step_intervals: delete own"
  on public.raw_step_intervals for delete
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = raw_step_intervals.workout_id
        and ws.user_id = auth.uid()
    )
  );
