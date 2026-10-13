-- Legacy production schemas have the set_updated_at trigger but predate the
-- updated_at column. Any finalized workout then fails when the trigger reads
-- NEW.updated_at. Backfill the column before enforcing the current contract.
alter table public.workout_sessions
  add column if not exists updated_at timestamptz;

update public.workout_sessions
set updated_at = coalesce(updated_at, created_at, started_at, now())
where updated_at is null;

alter table public.workout_sessions
  alter column updated_at set default now(),
  alter column updated_at set not null;
