-- Operational view for inspecting workout processing health in one query.

create or replace view public.v_workout_processing_status
with (security_invoker = true)
as
select
  sessions.id as workout_id,
  sessions.user_id,
  sessions.activity_type,
  sessions.mode,
  sessions.started_at,
  sessions.ended_at,
  sessions.processing_status,
  sessions.metrics_version,
  sessions.data_quality_score,
  sessions.route_match_status,
  sessions.route_match_confidence,
  sessions.route_distance_source,
  coalesce(raw_gps.point_count, 0) as raw_gps_point_count,
  coalesce(raw_steps.interval_count, 0) as raw_step_interval_count,
  coalesce(job_counts.queued_count, 0) as queued_job_count,
  coalesce(job_counts.running_count, 0) as running_job_count,
  coalesce(job_counts.failed_count, 0) as failed_job_count,
  deterministic_job.id as deterministic_job_id,
  deterministic_job.status as deterministic_job_status,
  deterministic_job.attempt_count as deterministic_attempt_count,
  deterministic_job.started_at as deterministic_started_at,
  deterministic_job.finished_at as deterministic_finished_at,
  deterministic_job.error_message as deterministic_error_message,
  route_job.id as route_job_id,
  route_job.status as route_job_status,
  route_job.attempt_count as route_attempt_count,
  route_job.started_at as route_started_at,
  route_job.finished_at as route_finished_at,
  route_job.error_message as route_error_message,
  latest_log.log_level as latest_log_level,
  latest_log.event_type as latest_log_event_type,
  latest_log.message as latest_log_message,
  latest_log.created_at as latest_log_created_at
from public.workout_sessions sessions
left join lateral (
  select count(*)::int as point_count
  from public.raw_gps_points points
  where points.workout_id = sessions.id
) raw_gps on true
left join lateral (
  select count(*)::int as interval_count
  from public.raw_step_intervals intervals
  where intervals.workout_id = sessions.id
) raw_steps on true
left join lateral (
  select
    count(*) filter (where jobs.status = 'queued')::int as queued_count,
    count(*) filter (where jobs.status = 'running')::int as running_count,
    count(*) filter (where jobs.status = 'failed')::int as failed_count
  from public.workout_processing_jobs jobs
  where jobs.workout_id = sessions.id
) job_counts on true
left join lateral (
  select jobs.*
  from public.workout_processing_jobs jobs
  where jobs.workout_id = sessions.id
    and jobs.job_type = 'deterministic_finalize'
  order by jobs.created_at desc
  limit 1
) deterministic_job on true
left join lateral (
  select jobs.*
  from public.workout_processing_jobs jobs
  where jobs.workout_id = sessions.id
    and jobs.job_type = 'route_correction_finalize'
  order by jobs.created_at desc
  limit 1
) route_job on true
left join lateral (
  select logs.log_level, logs.event_type, logs.message, logs.created_at
  from public.workout_processing_logs logs
  where logs.workout_id = sessions.id
  order by logs.created_at desc
  limit 1
) latest_log on true;

comment on view public.v_workout_processing_status is
  'One-row-per-workout operational view for processing jobs, raw tracking counts, finalization status, route matching status, and latest processing log.';

grant select on public.v_workout_processing_status to authenticated;
