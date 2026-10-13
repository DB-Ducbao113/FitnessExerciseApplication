-- A workout is created when recording starts and receives an end time only
-- when the user finishes it. Older production schemas made this NOT NULL.
alter table public.workout_sessions
  alter column ended_at drop not null;
