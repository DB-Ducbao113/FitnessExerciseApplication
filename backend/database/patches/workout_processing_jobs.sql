create table if not exists public.workout_processing_jobs (
  id             uuid primary key default gen_random_uuid(),
  workout_id     uuid not null references public.workout_sessions(id) on delete cascade,
  job_type       text not null,
  status         text not null default 'queued',
  attempt_count  int not null default 0 check (attempt_count >= 0),
  started_at     timestamptz,
  finished_at    timestamptz,
  error_message  text,
  created_at     timestamptz not null default now()
);

create index if not exists idx_workout_processing_jobs_workout
  on public.workout_processing_jobs (workout_id);

create index if not exists idx_workout_processing_jobs_status
  on public.workout_processing_jobs (status);

create index if not exists idx_workout_processing_jobs_created
  on public.workout_processing_jobs (created_at desc);

alter table public.workout_processing_jobs enable row level security;

drop policy if exists "workout_processing_jobs: select own" on public.workout_processing_jobs;
create policy "workout_processing_jobs: select own"
  on public.workout_processing_jobs for select
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_jobs.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "workout_processing_jobs: insert own" on public.workout_processing_jobs;
create policy "workout_processing_jobs: insert own"
  on public.workout_processing_jobs for insert
  to authenticated
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_jobs.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "workout_processing_jobs: update own" on public.workout_processing_jobs;
create policy "workout_processing_jobs: update own"
  on public.workout_processing_jobs for update
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_jobs.workout_id
        and ws.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_jobs.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "workout_processing_jobs: delete own" on public.workout_processing_jobs;
create policy "workout_processing_jobs: delete own"
  on public.workout_processing_jobs for delete
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_jobs.workout_id
        and ws.user_id = auth.uid()
    )
  );
