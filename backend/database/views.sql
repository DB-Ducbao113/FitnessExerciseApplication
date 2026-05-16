-- ================================================================
-- views.sql
-- Derived reporting views.
-- Run this after workouts.sql so public.workout_sessions already exists.
-- ================================================================

create or replace view public.v_user_stats as
select
  user_id,
  count(*) as total_sessions,
  coalesce(sum(duration_sec), 0) as total_duration_sec,
  coalesce(sum(distance_km), 0) as total_distance_km,
  coalesce(sum(calories_kcal), 0) as total_calories_kcal,
  coalesce(sum(steps), 0) as total_steps,
  coalesce(
    avg(avg_speed_kmh) filter (where avg_speed_kmh is not null),
    0
  ) as overall_avg_speed_kmh
from public.workout_sessions
group by user_id;

create or replace view public.v_weekly_stats as
select
  user_id,
  count(*) as sessions_this_week,
  coalesce(sum(duration_sec), 0) as duration_sec_week,
  coalesce(sum(distance_km), 0) as distance_km_week,
  coalesce(sum(calories_kcal), 0) as calories_week,
  coalesce(sum(steps), 0) as steps_week
from public.workout_sessions
where started_at >= (now() - interval '7 days')
group by user_id;

create or replace view public.v_monthly_sessions as
select
  user_id,
  date_trunc('month', started_at) as month,
  count(*) as sessions,
  coalesce(sum(distance_km), 0) as distance_km,
  coalesce(sum(calories_kcal), 0) as calories,
  coalesce(sum(duration_sec), 0) as duration_sec
from public.workout_sessions
group by user_id, date_trunc('month', started_at)
order by user_id, month desc;
