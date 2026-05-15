-- ================================================================
-- processing.sql
-- Processing and job-tracking tables for future backend-owned workout pipelines.
-- ================================================================

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

comment on table public.workout_processing_jobs is
  'Tracks deterministic or AI processing jobs for a workout session.';

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

comment on table public.workout_processing_logs is
  'Audit trail for workout processing decisions such as dropped outliers, smoothing, fallback selection, and finalization steps.';

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

create table if not exists public.workout_segment_audits (
  id                    bigint generated always as identity primary key,
  workout_id            uuid not null references public.workout_sessions(id) on delete cascade,
  segment_index         int not null check (segment_index >= 0),
  started_at            timestamptz not null,
  ended_at              timestamptz not null,
  duration_sec          int not null check (duration_sec >= 0),
  distance_m            double precision not null check (distance_m >= 0),
  pace_sec_per_km       double precision,
  avg_speed_kmh         double precision not null default 0 check (avg_speed_kmh >= 0),
  max_speed_kmh         double precision not null default 0 check (max_speed_kmh >= 0),
  avg_accuracy_m        double precision,
  status                text not null check (status in ('valid', 'suspicious', 'invalid')),
  reason                text not null,
  features              jsonb not null default '{}'::jsonb,
  created_at            timestamptz not null default now(),
  unique (workout_id, segment_index)
);

comment on table public.workout_segment_audits is
  'Segment-level deterministic audit trail for workout validity, anti-cheat checks, and future AI enrichment.';

create index if not exists idx_workout_segment_audits_workout
  on public.workout_segment_audits (workout_id);

create index if not exists idx_workout_segment_audits_status
  on public.workout_segment_audits (status);

create index if not exists idx_workout_segment_audits_workout_started
  on public.workout_segment_audits (workout_id, started_at);

alter table public.workout_segment_audits enable row level security;

drop policy if exists "workout_segment_audits: select own" on public.workout_segment_audits;
create policy "workout_segment_audits: select own"
  on public.workout_segment_audits for select
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_segment_audits.workout_id
        and ws.user_id = auth.uid()
    )
  );
