-- ================================================================
-- gps_tracks.sql
-- Tracking data tables for workout_sessions.
-- Canonical GPS table: public.gps_points
-- Legacy compatibility table: public.gps_tracks
-- Indoor interval table: public.step_sessions
-- ================================================================

create extension if not exists postgis;

-- Legacy compatibility table kept for older consumers that only store lat/lng pairs.
create table if not exists public.gps_tracks (
  id          uuid primary key default gen_random_uuid(),
  workout_id  uuid not null references public.workout_sessions(id) on delete cascade,
  latitude    double precision not null,
  longitude   double precision not null,
  recorded_at timestamp not null,
  created_at  timestamp default now()
);

comment on table public.gps_tracks is
  'Legacy GPS polyline table retained temporarily for compatibility. New code should use public.gps_points.';

create index if not exists idx_gps_tracks_workout
  on public.gps_tracks (workout_id);

alter table public.gps_tracks enable row level security;

drop policy if exists "gps_tracks: select own" on public.gps_tracks;
create policy "gps_tracks: select own"
  on public.gps_tracks for select
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = gps_tracks.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "gps_tracks: insert own" on public.gps_tracks;
create policy "gps_tracks: insert own"
  on public.gps_tracks for insert
  to authenticated
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = gps_tracks.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "gps_tracks: delete own" on public.gps_tracks;
create policy "gps_tracks: delete own"
  on public.gps_tracks for delete
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = gps_tracks.workout_id
        and ws.user_id = auth.uid()
    )
  );

create table if not exists public.gps_points (
  id          bigint generated always as identity primary key,
  workout_id  uuid not null references public.workout_sessions(id) on delete cascade,
  timestamp   timestamptz not null,
  location    geography(point, 4326) not null,
  altitude    float8,
  speed       float8,
  accuracy    float8,
  heading     float8,
  created_at  timestamptz default now()
);

comment on table public.gps_points is
  'Canonical GPS point table with PostGIS geography and optional telemetry such as speed, accuracy, and heading.';

create index if not exists idx_gps_points_workout
  on public.gps_points (workout_id);

create index if not exists idx_gps_points_workout_timestamp
  on public.gps_points (workout_id, timestamp);

create index if not exists idx_gps_points_location
  on public.gps_points using gist (location);

alter table public.gps_points enable row level security;

drop policy if exists "gps_points: select own" on public.gps_points;
create policy "gps_points: select own"
  on public.gps_points for select
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = gps_points.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "gps_points: insert own" on public.gps_points;
create policy "gps_points: insert own"
  on public.gps_points for insert
  to authenticated
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = gps_points.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "gps_points: delete own" on public.gps_points;
create policy "gps_points: delete own"
  on public.gps_points for delete
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = gps_points.workout_id
        and ws.user_id = auth.uid()
    )
  );

create table if not exists public.step_sessions (
  id              bigint generated always as identity primary key,
  workout_id      uuid not null references public.workout_sessions(id) on delete cascade,
  interval_start  timestamptz not null,
  interval_end    timestamptz not null,
  steps_count     int not null check (steps_count >= 0),
  created_at      timestamptz default now()
);

comment on table public.step_sessions is
  'Indoor pedometer intervals linked to workout_sessions. Table name is legacy-compatible; semantics are interval-based.';

create index if not exists idx_step_sessions_workout
  on public.step_sessions (workout_id);

create index if not exists idx_step_sessions_workout_start
  on public.step_sessions (workout_id, interval_start);

alter table public.step_sessions enable row level security;

drop policy if exists "step_sessions: select own" on public.step_sessions;
create policy "step_sessions: select own"
  on public.step_sessions for select
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = step_sessions.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "step_sessions: insert own" on public.step_sessions;
create policy "step_sessions: insert own"
  on public.step_sessions for insert
  to authenticated
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = step_sessions.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "step_sessions: delete own" on public.step_sessions;
create policy "step_sessions: delete own"
  on public.step_sessions for delete
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = step_sessions.workout_id
        and ws.user_id = auth.uid()
    )
  );
