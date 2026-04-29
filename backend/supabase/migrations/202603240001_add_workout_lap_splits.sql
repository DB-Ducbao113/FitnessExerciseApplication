alter table public.workout_sessions
add column if not exists lap_splits jsonb not null default '[]'::jsonb;
