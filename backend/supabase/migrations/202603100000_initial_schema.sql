-- Baseline schema for a brand-new Supabase project.
--
-- The original project was bootstrapped through backend/database/*.sql before
-- versioned migrations were introduced. Keep this migration idempotent so it
-- can also be applied safely to that existing project with `db push
-- --include-all`.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Legacy profile mirror retained for old workout_ai_insights foreign keys.
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text,
  gender      text,
  age         int check (age is null or (age > 0 and age < 130)),
  weight_kg   numeric(5,1),
  height_cm   numeric(5,1),
  created_at  timestamptz not null default now()
);

alter table public.users enable row level security;

drop policy if exists "users: select own row" on public.users;
create policy "users: select own row"
  on public.users for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "users: insert own row" on public.users;
create policy "users: insert own row"
  on public.users for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "users: update own row" on public.users;
create policy "users: update own row"
  on public.users for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create table if not exists public.user_profiles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  weight_kg   numeric(5,1),
  height_m    numeric(4,2),
  age         int check (age is null or (age > 0 and age < 130)),
  gender      varchar(20),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint user_profiles_user_id_unique unique (user_id)
);

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

create index if not exists idx_user_profiles_user_id
  on public.user_profiles (user_id);

alter table public.user_profiles enable row level security;

drop policy if exists "user_profiles: select own" on public.user_profiles;
create policy "user_profiles: select own"
  on public.user_profiles for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "user_profiles: insert own" on public.user_profiles;
create policy "user_profiles: insert own"
  on public.user_profiles for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "user_profiles: update own" on public.user_profiles;
create policy "user_profiles: update own"
  on public.user_profiles for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "user_profiles: delete own" on public.user_profiles;
create policy "user_profiles: delete own"
  on public.user_profiles for delete
  to authenticated
  using ((select auth.uid()) = user_id);

create table if not exists public.workout_sessions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  activity_type text not null,
  mode          text not null default 'outdoor',
  started_at    timestamptz not null,
  ended_at      timestamptz,
  duration_sec  int check (duration_sec is null or duration_sec >= 0),
  distance_km   float8 check (distance_km is null or distance_km >= 0),
  avg_speed_kmh float8 check (avg_speed_kmh is null or avg_speed_kmh >= 0),
  steps         int check (steps is null or steps >= 0),
  calories_kcal float8 check (calories_kcal is null or calories_kcal >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

drop trigger if exists trg_workout_sessions_updated_at
  on public.workout_sessions;
create trigger trg_workout_sessions_updated_at
  before update on public.workout_sessions
  for each row execute function public.set_updated_at();

create index if not exists idx_workout_sessions_user_time
  on public.workout_sessions (user_id, started_at desc);

create index if not exists idx_workout_sessions_user_mode
  on public.workout_sessions (user_id, mode);

alter table public.workout_sessions enable row level security;

drop policy if exists "workout_sessions: select own"
  on public.workout_sessions;
create policy "workout_sessions: select own"
  on public.workout_sessions for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "workout_sessions: insert own"
  on public.workout_sessions;
create policy "workout_sessions: insert own"
  on public.workout_sessions for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "workout_sessions: update own"
  on public.workout_sessions;
create policy "workout_sessions: update own"
  on public.workout_sessions for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "workout_sessions: delete own"
  on public.workout_sessions;
create policy "workout_sessions: delete own"
  on public.workout_sessions for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- Legacy workout table retained until workout_ai_insights is migrated fully to
-- the canonical workout_sessions table.
create table if not exists public.workouts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references auth.users(id) on delete cascade,
  activity_type text not null,
  started_at    timestamp not null,
  ended_at      timestamp,
  distance_km   numeric,
  duration_min  numeric,
  avg_speed_kmh numeric,
  calories      numeric,
  created_at    timestamp default now()
);

alter table public.workouts enable row level security;

drop policy if exists "workouts: select own" on public.workouts;
create policy "workouts: select own"
  on public.workouts for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "workouts: insert own" on public.workouts;
create policy "workouts: insert own"
  on public.workouts for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "workouts: delete own" on public.workouts;
create policy "workouts: delete own"
  on public.workouts for delete
  to authenticated
  using ((select auth.uid()) = user_id);
