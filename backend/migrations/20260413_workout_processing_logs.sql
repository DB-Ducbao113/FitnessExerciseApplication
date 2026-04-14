create table if not exists public.workout_processing_logs (
  id           bigint generated always as identity primary key,
  workout_id   uuid not null references public.workout_sessions(id) on delete cascade,
  job_id       uuid references public.workout_processing_jobs(id) on delete set null,
  log_level    text not null default 'info',
  event_type   text not null,
  message      text not null,
  payload      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index if not exists idx_workout_processing_logs_workout
  on public.workout_processing_logs (workout_id);

create index if not exists idx_workout_processing_logs_job
  on public.workout_processing_logs (job_id);

create index if not exists idx_workout_processing_logs_created
  on public.workout_processing_logs (created_at desc);

alter table public.workout_processing_logs enable row level security;

drop policy if exists "workout_processing_logs: select own" on public.workout_processing_logs;
create policy "workout_processing_logs: select own"
  on public.workout_processing_logs for select
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_logs.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "workout_processing_logs: insert own" on public.workout_processing_logs;
create policy "workout_processing_logs: insert own"
  on public.workout_processing_logs for insert
  to authenticated
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_logs.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "workout_processing_logs: update own" on public.workout_processing_logs;
create policy "workout_processing_logs: update own"
  on public.workout_processing_logs for update
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_logs.workout_id
        and ws.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_logs.workout_id
        and ws.user_id = auth.uid()
    )
  );

drop policy if exists "workout_processing_logs: delete own" on public.workout_processing_logs;
create policy "workout_processing_logs: delete own"
  on public.workout_processing_logs for delete
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_processing_logs.workout_id
        and ws.user_id = auth.uid()
    )
  );
