-- ================================================================
-- workouts.sql
-- Main workout schema used by the Flutter app.
-- Canonical table: public.workout_sessions
-- Legacy compatibility table: public.workouts
-- ================================================================

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$ begin
  create type activity_type_enum as enum (
    'running', 'walking', 'cycling', 'hiking', 'indoor_workout', 'other'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type tracking_mode_enum as enum ('outdoor', 'indoor');
exception when duplicate_object then null; end $$;

do $$ begin
  create type workout_status_enum as enum ('completed', 'cancelled');
exception when duplicate_object then null; end $$;

create table if not exists public.workout_sessions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,

  activity_type   text not null,
  mode            text not null default 'outdoor',

  started_at      timestamptz not null,
  ended_at        timestamptz,
  duration_sec    int check (duration_sec >= 0),
  moving_time_sec int not null default 0 check (moving_time_sec >= 0),

  distance_km     float8 check (distance_km is null or distance_km >= 0),
  avg_speed_kmh   float8 check (avg_speed_kmh is null or avg_speed_kmh >= 0),

  steps           int check (steps is null or steps >= 0),
  calories_kcal   float8 check (calories_kcal is null or calories_kcal >= 0),
  lap_splits      jsonb not null default '[]'::jsonb,

  -- Processing-ready metadata for future backend-owned workout finalization
  processing_status text not null default 'client_finalized',
  data_quality_score numeric(5,2)
    check (data_quality_score is null or (data_quality_score >= 0 and data_quality_score <= 100)),
  metrics_version int not null default 1 check (metrics_version >= 1),

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.workout_sessions is
  'One row per recorded workout. This is the canonical workout table used by the app.';

drop trigger if exists trg_workout_sessions_updated_at on public.workout_sessions;
create trigger trg_workout_sessions_updated_at
  before update on public.workout_sessions
  for each row execute function public.set_updated_at();

create index if not exists idx_workout_sessions_user_time
  on public.workout_sessions (user_id, started_at desc);

create index if not exists idx_workout_sessions_user_mode
  on public.workout_sessions (user_id, mode);

alter table public.workout_sessions enable row level security;

drop policy if exists "workout_sessions: select own" on public.workout_sessions;
create policy "workout_sessions: select own"
  on public.workout_sessions for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "workout_sessions: insert own" on public.workout_sessions;
create policy "workout_sessions: insert own"
  on public.workout_sessions for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "workout_sessions: update own" on public.workout_sessions;
create policy "workout_sessions: update own"
  on public.workout_sessions for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "workout_sessions: delete own" on public.workout_sessions;
create policy "workout_sessions: delete own"
  on public.workout_sessions for delete
  to authenticated
  using (auth.uid() = user_id);

-- Legacy compatibility table retained temporarily for older code and seed data.
create table if not exists public.workouts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references auth.users(id) on delete cascade,
  activity_type   text not null,
  started_at      timestamp not null,
  ended_at        timestamp,
  distance_km     numeric,
  duration_min    numeric,
  avg_speed_kmh   numeric,
  calories        numeric,
  created_at      timestamp default now()
);

comment on table public.workouts is
  'Legacy workout table retained temporarily for compatibility. New code should use public.workout_sessions.';

alter table public.workouts enable row level security;

drop policy if exists "workouts: select own" on public.workouts;
create policy "workouts: select own"
  on public.workouts for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "workouts: insert own" on public.workouts;
create policy "workouts: insert own"
  on public.workouts for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "workouts: delete own" on public.workouts;
create policy "workouts: delete own"
  on public.workouts for delete
  to authenticated
  using (auth.uid() = user_id);
