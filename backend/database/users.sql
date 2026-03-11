-- ================================================================
-- users.sql
-- Public mirror of auth.users with extended profile fields.
-- Matches Supabase table: public.users
-- ================================================================

create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text,
  gender      text,
  age         int check (age > 0 and age < 130),
  weight_kg   numeric(5,1),
  height_cm   numeric(5,1),
  created_at  timestamptz not null default now()
);

comment on table public.users is
  'Public user profile that mirrors auth.users. One row per authenticated account.';

-- ── RLS ──────────────────────────────────────────────────────────
alter table public.users enable row level security;

create policy "users: select own row"
  on public.users for select
  to authenticated
  using (auth.uid() = id);

create policy "users: insert own row"
  on public.users for insert
  to authenticated
  with check (auth.uid() = id);

create policy "users: update own row"
  on public.users for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Deleted via auth.users cascade — no explicit delete policy needed.
