-- ================================================================
-- gps_tracks.sql
-- Stores GPS trail points for outdoor workouts.
-- Matches Supabase tables: public.gps_tracks AND public.gps_points
-- ================================================================

-- ── ENABLE PostGIS (required for geography type in gps_points) ────
create extension if not exists postgis;

-- ── gps_tracks: simple lat/lng table (matches screenshot) ─────────
-- Kept because it exists in the DB. Lighter-weight than gps_points.
-- Use this table if you only need the drawn polyline.
create table if not exists public.gps_tracks (
  id          uuid primary key default gen_random_uuid(),
  workout_id  uuid not null references public.workout_sessions(id) on delete cascade,
  latitude    double precision not null,
  longitude   double precision not null,
  recorded_at timestamp not null,
  created_at  timestamp default now()
);

create index if not exists idx_gps_tracks_workout
  on public.gps_tracks (workout_id);

alter table public.gps_tracks enable row level security;

-- RLS via join to workout_sessions (user_id check)
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

-- ── gps_points: richer table with PostGIS geography + metadata ────
-- Matches the gps_points table in the screenshot.
-- Use this if you need spatial queries or speed/heading per point.
create table if not exists public.gps_points (
  id          bigint generated always as identity primary key,
  workout_id  uuid not null references public.workout_sessions(id) on delete cascade,
  timestamp   timestamptz not null,

  -- PostGIS geography point (longitude, latitude order per GeoJSON spec)
  location    geography(point, 4326) not null,

  altitude    float8,           -- meters, nullable (device may not supply)
  speed       float8,           -- m/s instantaneous, nullable
  accuracy    float8,           -- GPS accuracy radius in meters, nullable
  heading     float8,           -- degrees 0–360, nullable
  created_at  timestamptz default now()
);

create index if not exists idx_gps_points_workout
  on public.gps_points (workout_id);

-- Spatial index for bounding-box / within queries
create index if not exists idx_gps_points_location
  on public.gps_points using gist (location);

alter table public.gps_points enable row level security;

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

-- ── step_sessions: pedometer intervals for indoor workouts ────────
-- Matches the step_sessions table in the screenshot.
create table if not exists public.step_sessions (
  id              bigint generated always as identity primary key,
  workout_id      uuid not null references public.workout_sessions(id) on delete cascade,
  interval_start  timestamptz not null,
  interval_end    timestamptz not null,
  steps_count     int not null check (steps_count >= 0),
  created_at      timestamptz default now()
);

create index if not exists idx_step_sessions_workout
  on public.step_sessions (workout_id);

alter table public.step_sessions enable row level security;

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
