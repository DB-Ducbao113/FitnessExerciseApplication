-- ================================================================
-- dev_seed.sql
-- Development seed data.
-- Safe behavior:
--   - uses the first available auth.users row
--   - skips cleanly if no auth user exists yet
-- ================================================================

do $$
declare
  seed_user_id uuid;
  running_workout_id uuid;
begin
  select id
  into seed_user_id
  from auth.users
  order by created_at asc
  limit 1;

  if seed_user_id is null then
    raise notice 'dev_seed.sql skipped: no rows found in auth.users.';
    return;
  end if;

  insert into public.users (id, name, gender, age, weight_kg, height_cm)
  values (
    seed_user_id,
    'Dev User',
    'male',
    22,
    65.0,
    175.0
  )
  on conflict (id) do update set
    name = excluded.name,
    gender = excluded.gender,
    age = excluded.age,
    weight_kg = excluded.weight_kg,
    height_cm = excluded.height_cm;

  insert into public.user_profiles (
    user_id,
    weight_kg,
    height_cm,
    date_of_birth,
    height_m,
    age,
    gender
  )
  values (
    seed_user_id,
    65.0,
    175.0,
    date '2004-01-01',
    1.75,
    22,
    'male'
  )
  on conflict (user_id) do update set
    weight_kg = excluded.weight_kg,
    height_cm = excluded.height_cm,
    date_of_birth = excluded.date_of_birth,
    height_m = excluded.height_m,
    age = excluded.age,
    gender = excluded.gender,
    updated_at = now();

  insert into public.user_goals (user_id, goal_type, target_value, period)
  values (
    seed_user_id,
    'distance',
    25.0,
    'weekly'
  )
  on conflict (user_id) do update set
    goal_type = excluded.goal_type,
    target_value = excluded.target_value,
    period = excluded.period,
    updated_at = now();

  insert into public.workout_sessions (
    user_id,
    activity_type,
    mode,
    started_at,
    ended_at,
    duration_sec,
    moving_time_sec,
    distance_km,
    avg_speed_kmh,
    calories_kcal,
    lap_splits
  )
  values (
    seed_user_id,
    'running',
    'outdoor',
    now() - interval '1 day',
    now() - interval '1 day' + interval '30 minutes',
    1800,
    1740,
    5.2,
    10.4,
    320.0,
    '[{"index":1,"distanceKm":1.0,"durationSeconds":330,"paceMinPerKm":5.5},{"index":2,"distanceKm":1.0,"durationSeconds":342,"paceMinPerKm":5.7}]'::jsonb
  )
  returning id into running_workout_id;

  insert into public.workout_sessions (
    user_id,
    activity_type,
    mode,
    started_at,
    ended_at,
    duration_sec,
    moving_time_sec,
    distance_km,
    avg_speed_kmh,
    calories_kcal,
    lap_splits
  )
  values (
    seed_user_id,
    'cycling',
    'outdoor',
    now() - interval '4 hours',
    now() - interval '3 hours',
    3600,
    3480,
    20.5,
    20.5,
    450.0,
    '[]'::jsonb
  );

  insert into public.workout_sessions (
    user_id,
    activity_type,
    mode,
    started_at,
    ended_at,
    duration_sec,
    moving_time_sec,
    steps,
    calories_kcal,
    lap_splits
  )
  values (
    seed_user_id,
    'walking',
    'indoor',
    now() - interval '2 days',
    now() - interval '2 days' + interval '45 minutes',
    2700,
    2700,
    5400,
    200.0,
    '[]'::jsonb
  );

  if running_workout_id is not null then
    insert into public.gps_tracks (workout_id, latitude, longitude, recorded_at)
    values
      (running_workout_id, 10.77690, 106.70090, now() - interval '1 day'),
      (
        running_workout_id,
        10.77710,
        106.70120,
        now() - interval '1 day' + interval '30 seconds'
      ),
      (
        running_workout_id,
        10.77740,
        106.70150,
        now() - interval '1 day' + interval '60 seconds'
      );
  end if;

  raise notice 'dev_seed.sql completed for auth user %', seed_user_id;
end $$;

select activity_type, mode, duration_sec, distance_km, calories_kcal, started_at
from public.workout_sessions
order by started_at desc
limit 10;
