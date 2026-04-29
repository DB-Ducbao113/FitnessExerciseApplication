alter table public.workout_sessions
  add column if not exists processing_status text not null default 'client_finalized',
  add column if not exists data_quality_score numeric(5,2),
  add column if not exists metrics_version int not null default 1;

do $$ begin
  alter table public.workout_sessions
    add constraint workout_sessions_data_quality_score_range
      check (
        data_quality_score is null
        or (data_quality_score >= 0 and data_quality_score <= 100)
      );
exception
  when duplicate_object then null;
end $$;

do $$ begin
  alter table public.workout_sessions
    add constraint workout_sessions_metrics_version_positive
      check (metrics_version >= 1);
exception
  when duplicate_object then null;
end $$;

create index if not exists idx_workout_sessions_processing_status
  on public.workout_sessions (processing_status);
