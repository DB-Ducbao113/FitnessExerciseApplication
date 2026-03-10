-- ================================================================
-- user_profiles.sql
-- Extended user body metrics stored in user_profiles.
-- Matches Supabase table: public.user_profiles
-- Note: separate from `users` in the DB screenshot — DO NOT merge.
-- ================================================================

create table if not exists public.user_profiles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  weight_kg   numeric(5,1),
  height_m    numeric(4,2),       -- stored in meters (e.g. 1.72), matches screenshot
  age         int check (age > 0 and age < 130),
  gender      varchar(20),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint user_profiles_user_id_unique unique (user_id)
);

comment on table public.user_profiles is
  'Body metrics per user. One row per user (enforced by unique constraint on user_id).';

-- ── updated_at trigger ────────────────────────────────────────────
-- Requires: set_updated_at() function (defined in workouts.sql or a shared file)
create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

-- ── Index ─────────────────────────────────────────────────────────
create index if not exists idx_user_profiles_user_id
  on public.user_profiles (user_id);

-- ── RLS ──────────────────────────────────────────────────────────
alter table public.user_profiles enable row level security;

create policy "user_profiles: select own"
  on public.user_profiles for select
  to authenticated
  using (auth.uid() = user_id);

create policy "user_profiles: insert own"
  on public.user_profiles for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "user_profiles: update own"
  on public.user_profiles for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "user_profiles: delete own"
  on public.user_profiles for delete
  to authenticated
  using (auth.uid() = user_id);
