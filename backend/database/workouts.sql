-- ================================================================
-- workouts.sql
-- Main workout session table used by the Flutter app.
-- Matches Supabase table: public.workout_sessions (primary)
-- Legacy table: public.workouts (kept for backward compat — see below)
-- ================================================================

-- ── Trigger helper (shared, safe to run once) ─────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ── Enums ─────────────────────────────────────────────────────────
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

-- ── workout_sessions (primary table used by app) ──────────────────
create table if not exists public.workout_sessions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,

  activity_type   text not null,          -- matches screenshot: text column
  mode            text not null default 'outdoor', -- 'outdoor' | 'indoor'

  started_at      timestamptz not null,
  ended_at        timestamptz,
  duration_sec    int check (duration_sec >= 0),

  -- Outdoor GPS metrics (null for indoor)
  distance_km     float8,
  avg_speed_kmh   float8,

  -- Shared
  steps           int check (steps >= 0),
  calories_kcal   float8 check (calories_kcal >= 0),
  lap_splits      jsonb not null default '[]'::jsonb,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.workout_sessions is
  'One row per recorded workout. GPS metrics are null for indoor sessions.';

create trigger trg_workout_sessions_updated_at
  before update on public.workout_sessions
  for each row execute function public.set_updated_at();

create index if not exists idx_workout_sessions_user_time
  on public.workout_sessions (user_id, started_at desc);

create index if not exists idx_workout_sessions_user_mode
  on public.workout_sessions (user_id, mode);

alter table public.workout_sessions enable row level security;

create policy "workout_sessions: select own"
  on public.workout_sessions for select
  to authenticated
  using (auth.uid() = user_id);

create policy "workout_sessions: insert own"
  on public.workout_sessions for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "workout_sessions: update own"
  on public.workout_sessions for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "workout_sessions: delete own"
  on public.workout_sessions for delete
  to authenticated
  using (auth.uid() = user_id);

-- ── workouts (legacy table visible in screenshot) ─────────────────
-- This table exists in the DB. Kept for reference / backward compat.
-- New code should write to workout_sessions instead.
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

alter table public.workouts enable row level security;

create policy "workouts: select own"
  on public.workouts for select to authenticated using (auth.uid() = user_id);

create policy "workouts: insert own"
  on public.workouts for insert to authenticated with check (auth.uid() = user_id);

create policy "workouts: delete own"
  on public.workouts for delete to authenticated using (auth.uid() = user_id);
