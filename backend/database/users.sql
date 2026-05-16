-- ================================================================
-- users.sql
-- Legacy public mirror of auth.users with profile-style fields.
-- This table is retained temporarily for backward compatibility only.
-- New application code should use public.user_profiles instead.
-- ================================================================

create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text,
  gender      text,
  age         int check (age is null or (age > 0 and age < 130)),
  weight_kg   numeric(5,1),
  height_cm   numeric(5,1),
  created_at  timestamptz not null default now()
);

comment on table public.users is
  'Legacy profile mirror of auth.users. Retained temporarily for compatibility; new code should use public.user_profiles.';

alter table public.users enable row level security;

drop policy if exists "users: select own row" on public.users;
create policy "users: select own row"
  on public.users for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "users: insert own row" on public.users;
create policy "users: insert own row"
  on public.users for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "users: update own row" on public.users;
create policy "users: update own row"
  on public.users for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Deleted via auth.users cascade; no explicit delete policy needed.
