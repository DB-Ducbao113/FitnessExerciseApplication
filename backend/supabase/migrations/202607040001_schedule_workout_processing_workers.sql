-- Schedule workout processing workers on Supabase hosted.
--
-- Required Vault secrets before the cron job can dispatch work:
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<service-role-key>', 'service_role_key');

create extension if not exists pg_cron;
create extension if not exists pg_net;

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

revoke all on function public.dispatch_workout_processing_jobs(int)
  from public, anon, authenticated;
grant execute on function public.dispatch_workout_processing_jobs(int)
  to service_role;

do $$
begin
  perform cron.unschedule('dispatch-workout-processing-jobs');
exception
  when others then
    null;
end;
$$;

select cron.schedule(
  'dispatch-workout-processing-jobs',
  '* * * * *',
  $cron$
    select * from public.dispatch_workout_processing_jobs(5);
  $cron$
);
