-- ================================================================
-- 01_fitness_schema.sql
-- Master schema entry point for Supabase SQL Editor or local bootstrap.
-- Run this file first, then run the table files in the documented order.
-- ================================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists postgis;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Run the remaining files in this order:
--
--   1) users.sql
--   2) user_metrics.sql
--   3) workouts.sql
--   4) gps_tracks.sql
--   5) raw_tracking.sql
--   6) processing.sql
--   7) views.sql
--   8) migrations/20260311_user_goals.sql
--   9) migrations/20260311_add_avatar_url.sql
--  10) migrations/20260324_add_workout_lap_splits.sql
--  11) migrations/20260413_user_profiles_compatibility.sql
--  12) migrations/20260413_workout_processing_metadata.sql
--  13) migrations/20260413_raw_tracking_tables.sql
--  14) migrations/20260413_workout_processing_jobs.sql
--  15) migrations/20260413_workout_processing_logs.sql
--  16) seed/dev_seed.sql (optional, dev only)

-- Storage note:
-- Create an `avatars` bucket in Supabase Storage and store the public URL in
-- public.user_profiles.avatar_url.
