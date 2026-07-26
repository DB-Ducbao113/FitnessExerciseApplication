-- Stabilize workout processing by making active jobs idempotent and
-- recovering stale running jobs before each dispatcher tick.

with ranked_active_jobs as (
  select
    id,
    row_number() over (
      partition by workout_id, job_type
      order by created_at, id
    ) as active_rank
  from public.workout_processing_jobs
  where status in ('queued', 'running')
)
update public.workout_processing_jobs jobs
set
  status = 'cancelled_duplicate',
  finished_at = coalesce(jobs.finished_at, now()),
  error_message = 'Cancelled duplicate active processing job before unique active-job index creation.'
from ranked_active_jobs ranked
where jobs.id = ranked.id
  and ranked.active_rank > 1;

create unique index if not exists idx_workout_processing_jobs_one_active
  on public.workout_processing_jobs (workout_id, job_type)
  where status in ('queued', 'running');

create index if not exists idx_workout_processing_jobs_dispatch
  on public.workout_processing_jobs (status, job_type, created_at)
  where status in ('queued', 'running');

create or replace function public.requeue_stale_workout_processing_jobs(
  stale_after interval default interval '10 minutes'
)
returns table (
  recovered_job_id uuid,
  recovered_status text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with stale_jobs as (
    select id, attempt_count
    from public.workout_processing_jobs
    where status = 'running'
      and started_at is not null
      and started_at < now() - coalesce(stale_after, interval '10 minutes')
  ),
  updated_jobs as (
    update public.workout_processing_jobs jobs
    set
      status = case
        when jobs.attempt_count < 3 then 'queued'
        else 'failed'
      end,
      started_at = case
        when jobs.attempt_count < 3 then null
        else jobs.started_at
      end,
      finished_at = case
        when jobs.attempt_count < 3 then null
        else coalesce(jobs.finished_at, now())
      end,
      error_message = case
        when jobs.attempt_count < 3 then null
        else 'Processing job exceeded stale recovery retry budget.'
      end
    from stale_jobs stale
    where jobs.id = stale.id
    returning jobs.id, jobs.status
  )
  select updated_jobs.id, updated_jobs.status
  from updated_jobs;
end;
$$;

revoke all on function public.requeue_stale_workout_processing_jobs(interval)
  from public, anon, authenticated;
grant execute on function public.requeue_stale_workout_processing_jobs(interval)
  to service_role;

create or replace function public.dispatch_workout_processing_jobs(
  batch_size int default 5
)
returns table (
  dispatched_job_id uuid,
  dispatched_job_type text,
  request_id bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  project_url text;
  service_role_key text;
  worker_name text;
  job record;
begin
  perform public.requeue_stale_workout_processing_jobs();

  select decrypted_secret
    into project_url
  from vault.decrypted_secrets
  where name = 'project_url'
  order by updated_at desc
  limit 1;

  select decrypted_secret
    into service_role_key
  from vault.decrypted_secrets
  where name = 'service_role_key'
  order by updated_at desc
  limit 1;

  if project_url is null or service_role_key is null then
    raise warning
      'Workout processing dispatcher skipped: missing Vault secrets project_url or service_role_key.';
    return;
  end if;

  project_url := regexp_replace(project_url, '/+$', '');

  for job in
    select jobs.id, jobs.workout_id, jobs.job_type
    from public.workout_processing_jobs jobs
    where jobs.status = 'queued'
      and jobs.attempt_count < 3
      and jobs.job_type in ('deterministic_finalize', 'route_correction_finalize')
      and (
        jobs.job_type <> 'route_correction_finalize'
        or not exists (
          select 1
          from public.workout_processing_jobs finalize_jobs
          where finalize_jobs.workout_id = jobs.workout_id
            and finalize_jobs.job_type = 'deterministic_finalize'
            and finalize_jobs.status in ('queued', 'running')
            and finalize_jobs.attempt_count < 3
        )
      )
    order by
      case jobs.job_type
        when 'deterministic_finalize' then 0
        when 'route_correction_finalize' then 1
        else 2
      end,
      jobs.created_at
    limit greatest(coalesce(batch_size, 5), 1)
  loop
    worker_name := case job.job_type
      when 'deterministic_finalize' then 'deterministic-finalize-worker'
      when 'route_correction_finalize' then 'route-correction-worker'
      else null
    end;

    if worker_name is null then
      continue;
    end if;

    dispatched_job_id := job.id;
    dispatched_job_type := job.job_type;

    select net.http_post(
      url := project_url || '/functions/v1/' || worker_name,
      body := jsonb_build_object(
        'job_id', job.id,
        'workout_id', job.workout_id
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key,
        'apikey', service_role_key
      ),
      timeout_milliseconds := 5000
    )
    into request_id;

    return next;
  end loop;
end;
$$;

grant execute on function public.dispatch_workout_processing_jobs(int)
  to service_role;
