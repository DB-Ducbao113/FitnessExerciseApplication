-- ================================================================
-- user_profiles.sql
-- Extended user body metrics stored in user_profiles.
-- Matches Supabase table: public.user_profiles
-- Source of truth for new installs:
--   - prefer `height_cm` + `date_of_birth`
-- Compatibility:
--   - keep `height_m` + `age` during migration rollout
-- Note: separate from `users`; do not merge.
-- ================================================================

create table if not exists public.user_profiles (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  weight_kg     numeric(5,1) check (weight_kg is null or weight_kg > 0),

  -- Canonical profile fields
  height_cm     numeric(5,1) check (height_cm is null or height_cm > 0),
  date_of_birth date,

  -- Legacy compatibility fields
  height_m      numeric(4,2), -- temporary compatibility column for older app builds
  age           int check (age is null or (age > 0 and age < 130)),

  gender        varchar(20),
  avatar_url    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint user_profiles_user_id_unique unique (user_id)
);

comment on table public.user_profiles is
  'Body metrics per user. Canonical fields are height_cm and date_of_birth; height_m and age remain temporarily for compatibility.';

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

create index if not exists idx_user_profiles_user_id
  on public.user_profiles (user_id);

create index if not exists idx_user_profiles_date_of_birth
  on public.user_profiles (date_of_birth);

alter table public.user_profiles enable row level security;

drop policy if exists "user_profiles: select own" on public.user_profiles;
create policy "user_profiles: select own"
  on public.user_profiles for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "user_profiles: insert own" on public.user_profiles;
create policy "user_profiles: insert own"
  on public.user_profiles for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "user_profiles: update own" on public.user_profiles;
create policy "user_profiles: update own"
  on public.user_profiles for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_profiles: delete own" on public.user_profiles;
create policy "user_profiles: delete own"
  on public.user_profiles for delete
  to authenticated
  using (auth.uid() = user_id);
