-- ================================================================
-- insert_sample.sql  ──  DEV SEED DATA
-- Run AFTER all schema files. Replace the user UUID below with
-- a real auth.users ID from your Supabase project.
-- ================================================================

-- ── Step 1: Upsert user row ───────────────────────────────────────
-- Replace the UUID with your own from Supabase Auth > Users tab.
insert into public.users (id, name, gender, age, weight_kg, height_cm)
values (
  '6e2f84d1-e16c-4ab4-bd89-1688aea5a37d',
  'Duc Bao',
  'male',
  22,
  65.0,
  175.0
)
on conflict (id) do update set
  name   = excluded.name,
  gender = excluded.gender,
  age    = excluded.age;

-- ── Step 2: Upsert user_profile row ──────────────────────────────
insert into public.user_profiles (user_id, weight_kg, height_m, age, gender)
values (
  '6e2f84d1-e16c-4ab4-bd89-1688aea5a37d',
  65.0,
  1.75,
  22,
  'male'
)
on conflict (user_id) do update set
  weight_kg = excluded.weight_kg,
  height_m  = excluded.height_m;

-- ── Step 3: Sample workout_sessions ──────────────────────────────

-- Outdoor running (yesterday, 30 min)
insert into public.workout_sessions (
  user_id, activity_type, mode,
  started_at, ended_at, duration_sec,
  distance_km, avg_speed_kmh, calories_kcal
) values (
  '6e2f84d1-e16c-4ab4-bd89-1688aea5a37d',
  'running', 'outdoor',
  now() - interval '1 day',
  now() - interval '1 day' + interval '30 minutes',
  1800,
  5.2, 10.4, 320.0
);

-- Outdoor cycling (4 hours ago, 60 min)
insert into public.workout_sessions (
  user_id, activity_type, mode,
  started_at, ended_at, duration_sec,
  distance_km, avg_speed_kmh, calories_kcal
) values (
  '6e2f84d1-e16c-4ab4-bd89-1688aea5a37d',
  'cycling', 'outdoor',
  now() - interval '4 hours',
  now() - interval '3 hours',
  3600,
  20.5, 20.5, 450.0
);

-- Indoor walking (2 days ago, step-based)
insert into public.workout_sessions (
  user_id, activity_type, mode,
  started_at, ended_at, duration_sec,
  steps, calories_kcal
) values (
  '6e2f84d1-e16c-4ab4-bd89-1688aea5a37d',
  'walking', 'indoor',
  now() - interval '2 days',
  now() - interval '2 days' + interval '45 minutes',
  2700,
  5400, 200.0
);

-- ── Step 4: Sample gps_tracks for the running session ────────────
-- Get the running session id first:
--   select id from workout_sessions where activity_type='running' limit 1;
-- Then replace <RUNNING_SESSION_UUID> below.

/*
insert into public.gps_tracks (workout_id, latitude, longitude, recorded_at)
values
  ('<RUNNING_SESSION_UUID>', 10.77690, 106.70090, now() - interval '1 day'),
  ('<RUNNING_SESSION_UUID>', 10.77710, 106.70120, now() - interval '1 day' + interval '30 seconds'),
  ('<RUNNING_SESSION_UUID>', 10.77740, 106.70150, now() - interval '1 day' + interval '60 seconds');
*/

-- ── Step 5: Verify ────────────────────────────────────────────────
select activity_type, mode, duration_sec, distance_km, calories_kcal, started_at
from public.workout_sessions
where user_id = '6e2f84d1-e16c-4ab4-bd89-1688aea5a37d'
order by started_at desc;
