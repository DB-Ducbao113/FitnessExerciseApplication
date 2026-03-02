-- Enable PostGIS for geospatial storage
create extension if not exists postgis;

-- 1. WORKOUTS TABLE
create type workout_activity as enum ('RUNNING', 'CYCLING', 'WALKING', 'SWIMMING', 'WEIGHTS', 'YOGA');
create type workout_status as enum ('ONGOING', 'COMPLETED', 'CANCELLED');
create type workout_source as enum ('GPS', 'MANUAL', 'PEDOMETER');

create table if not exists workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  activity_type workout_activity not null,
  status workout_status default 'ONGOING' not null,
  source workout_source default 'GPS' not null,
  
  start_time timestamptz default now() not null,
  end_time timestamptz,
  
  -- Aggregates (calculated at end)
  duration_seconds int default 0,
  distance_meters float default 0,
  calories_burned float default 0,
  avg_pace float, -- seconds per km
  elevation_gain float default 0,
  steps_count int default 0, -- for walking
  
  created_at timestamptz default now()
);

-- RLS for workouts
alter table workouts enable row level security;

create policy "Users can insert their own workouts"
on workouts for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can view their own workouts"
on workouts for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can update their own workouts"
on workouts for update
to authenticated
using (auth.uid() = user_id);


-- 2. GPS POINTS TABLE (Time-Series)
create table if not exists gps_points (
  id bigint generated always as identity primary key,
  workout_id uuid references workouts(id) on delete cascade not null,
  timestamp timestamptz not null,
  
  -- Store as PostGIS Geography Point (Long, Lat)
  location geography(POINT, 4326) not null,
  
  altitude float,
  speed float, -- m/s
  accuracy float, -- meters
  heading float,
  
  created_at timestamptz default now()
);

-- Index for querying points by workout
create index if not exists idx_gps_points_workout on gps_points(workout_id);
-- Spatial index (GIST) for location queries
create index if not exists idx_gps_points_location on gps_points using gist(location);

-- RLS for gps_points
alter table gps_points enable row level security;

create policy "Users can insert points for their workouts"
on gps_points for insert
to authenticated
with check (
  exists (
    select 1 from workouts
    where workouts.id = gps_points.workout_id
    and workouts.user_id = auth.uid()
  )
);

create policy "Users can select points for their workouts"
on gps_points for select
to authenticated
using (
  exists (
    select 1 from workouts
    where workouts.id = gps_points.workout_id
    and workouts.user_id = auth.uid()
  )
);


-- 3. STEP SESSIONS TABLE (For Pedometer Data)
-- Instead of storing every step, we store intervals (e.g. every minute)
create table if not exists step_sessions (
  id bigint generated always as identity primary key,
  workout_id uuid references workouts(id) on delete cascade not null,
  
  interval_start timestamptz not null,
  interval_end timestamptz not null,
  steps_count int not null,
  
  created_at timestamptz default now()
);

-- Index
create index if not exists idx_step_sessions_workout on step_sessions(workout_id);

-- RLS
alter table step_sessions enable row level security;

create policy "Users can insert steps for their workouts"
on step_sessions for insert
to authenticated
with check (
  exists (
    select 1 from workouts
    where workouts.id = step_sessions.workout_id
    and workouts.user_id = auth.uid()
  )
);

create policy "Users can select steps for their workouts"
on step_sessions for select
to authenticated
using (
  exists (
    select 1 from workouts
    where workouts.id = step_sessions.workout_id
    and workouts.user_id = auth.uid()
  )
);
