-- ================================================================
-- migration_user_goals.sql
-- Creates the user_goals table and related RLS policies.
-- Run once in Supabase SQL Editor.
-- Self-contained: embeds set_updated_at() in case 01_fitness_schema.sql
-- was not run yet.
-- ================================================================

-- Ensure the updated_at trigger helper exists (safe to re-run)
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


create table if not exists public.user_goals (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,

  -- 'distance' | 'workouts' | 'calories'
  goal_type    text not null check (goal_type in ('distance', 'workouts', 'calories')),

  -- Numeric target: km for distance, count for workouts, kcal for calories
  target_value numeric(10,2) not null check (target_value > 0),

  -- 'weekly' | 'monthly'
  period       text not null check (period in ('weekly', 'monthly')),

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- Only one active goal per user at a time
  constraint user_goals_user_id_unique unique (user_id)
);

comment on table public.user_goals is
  'One row per user – their current active fitness goal.';

-- updated_at auto-update
create trigger trg_user_goals_updated_at
  before update on public.user_goals
  for each row execute function public.set_updated_at();

-- Index
create index if not exists idx_user_goals_user_id on public.user_goals (user_id);

-- RLS
alter table public.user_goals enable row level security;

create policy "user_goals: select own"
  on public.user_goals for select
  to authenticated using (auth.uid() = user_id);

create policy "user_goals: insert own"
  on public.user_goals for insert
  to authenticated with check (auth.uid() = user_id);

create policy "user_goals: update own"
  on public.user_goals for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "user_goals: delete own"
  on public.user_goals for delete
  to authenticated using (auth.uid() = user_id);
