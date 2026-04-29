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
