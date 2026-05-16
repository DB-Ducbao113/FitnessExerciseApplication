-- ================================================================
-- migration_user_goals.sql
-- Creates the user_goals table and related RLS policies.
-- Safe to re-run.
-- ================================================================

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
  goal_type    text not null check (goal_type in ('distance', 'workouts', 'calories')),
  target_value numeric(10,2) not null check (target_value > 0),
  period       text not null check (period in ('weekly', 'monthly')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint user_goals_user_id_unique unique (user_id)
);

comment on table public.user_goals is
  'One row per user; their current active fitness goal.';

drop trigger if exists trg_user_goals_updated_at on public.user_goals;
create trigger trg_user_goals_updated_at
  before update on public.user_goals
  for each row execute function public.set_updated_at();

create index if not exists idx_user_goals_user_id
  on public.user_goals (user_id);

alter table public.user_goals enable row level security;

drop policy if exists "user_goals: select own" on public.user_goals;
create policy "user_goals: select own"
  on public.user_goals for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "user_goals: insert own" on public.user_goals;
create policy "user_goals: insert own"
  on public.user_goals for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "user_goals: update own" on public.user_goals;
create policy "user_goals: update own"
  on public.user_goals for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_goals: delete own" on public.user_goals;
create policy "user_goals: delete own"
  on public.user_goals for delete
  to authenticated
  using (auth.uid() = user_id);
