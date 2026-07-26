-- Make raw tracking uploads idempotent so offline retry can safely re-upload
-- points or step intervals that were already flushed live.

delete from public.raw_gps_points a
using public.raw_gps_points b
where a.id > b.id
  and a.workout_id = b.workout_id
  and a.timestamp = b.timestamp
  and a.latitude = b.latitude
  and a.longitude = b.longitude;

create unique index if not exists idx_raw_gps_points_unique_sample
  on public.raw_gps_points (workout_id, timestamp, latitude, longitude);

delete from public.raw_step_intervals a
using public.raw_step_intervals b
where a.id > b.id
  and a.workout_id = b.workout_id
  and a.interval_start = b.interval_start
  and a.interval_end = b.interval_end;

create unique index if not exists idx_raw_step_intervals_unique_interval
  on public.raw_step_intervals (workout_id, interval_start, interval_end);
