-- ================================================================
-- 01_fitness_schema.sql  ──  MASTER SCHEMA ENTRY POINT
-- Run this file FIRST in Supabase SQL Editor.
-- It defines extensions, the updated_at helper, and execution order.
-- Individual table definitions live in their own files (run after this).
-- ================================================================

-- ── 1. Extensions ─────────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists postgis;          -- required for gps_points.location

-- ── 2. Shared trigger function ────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ── 3. Execution order ────────────────────────────────────────────
-- Run in this order to satisfy foreign-key dependencies:
--
--   1) users.sql            → public.users
--   2) user_metrics.sql     → public.user_profiles
--   3) workouts.sql         → public.workout_sessions, public.workouts (legacy)
--   4) gps_tracks.sql       → public.gps_tracks, public.gps_points, public.step_sessions
--   5) insert_sample.sql    → seed data (optional, dev only)

-- ── 4. Statistics views ───────────────────────────────────────────

-- All-time totals per user
create or replace view public.v_user_stats as
select
  user_id,
  count(*)                                              as total_sessions,
  coalesce(sum(duration_sec), 0)                        as total_duration_sec,
  coalesce(sum(distance_km),  0)                        as total_distance_km,
  coalesce(sum(calories_kcal), 0)                       as total_calories_kcal,
  coalesce(sum(steps), 0)                               as total_steps,
  coalesce(
    avg(avg_speed_kmh) filter (where avg_speed_kmh is not null),
    0
  )                                                     as overall_avg_speed_kmh
from public.workout_sessions
group by user_id;

-- Last-7-days summary
create or replace view public.v_weekly_stats as
select
  user_id,
  count(*)                             as sessions_this_week,
  coalesce(sum(duration_sec), 0)       as duration_sec_week,
  coalesce(sum(distance_km),  0)       as distance_km_week,
  coalesce(sum(calories_kcal), 0)      as calories_week,
  coalesce(sum(steps), 0)              as steps_week
from public.workout_sessions
where started_at >= (now() - interval '7 days')
group by user_id;

-- Monthly breakdown (for chart bars)
create or replace view public.v_monthly_sessions as
select
  user_id,
  date_trunc('month', started_at)      as month,
  count(*)                             as sessions,
  coalesce(sum(distance_km),  0)       as distance_km,
  coalesce(sum(calories_kcal), 0)      as calories,
  coalesce(sum(duration_sec), 0)       as duration_sec
from public.workout_sessions
group by user_id, date_trunc('month', started_at)
order by user_id, month desc;

-- ── 5. Supabase Storage ───────────────────────────────────────────
-- Create a bucket named 'avatars' in Supabase Dashboard > Storage.
-- Recommended path pattern: <user_id>/avatar.jpg
-- After upload, store the public URL in public.users (add avatar_url column if needed):
--
--   alter table public.users add column if not exists avatar_url text;
