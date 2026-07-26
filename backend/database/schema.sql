-- ================================================================
-- schema.sql
-- Master schema entry point for Supabase SQL Editor or local bootstrap.
-- Run this file first, then run the table files in the documented order.
-- ================================================================

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
create extension if not exists postgis;

create or replace function public.set_updated_at()
returns trigger language plpgsql
set search_path = ''
as $$
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
--   8) patches/user_goals.sql
--   9) patches/profile_avatar.sql
--  10) patches/workout_lap_splits.sql
--  11) patches/raw_tracking_tables.sql
--  12) patches/user_profiles_compatibility.sql
--  13) patches/workout_processing_jobs.sql
--  14) patches/workout_processing_logs.sql
--  15) patches/workout_processing_metadata.sql
--  16) patches/route_matching.sql
--  17) patches/workout_moving_time.sql
--  18) patches/workout_segment_audits.sql
--
-- Supabase CLI deploy path:
--   use backend/supabase/migrations. Do not rename migrations after they have
--   been pushed to a Supabase project.
--  19) seed/dev_seed.sql (optional, dev only)

-- Storage note:
-- Create an `avatars` bucket in Supabase Storage and store the public URL in
-- public.user_profiles.avatar_url.
