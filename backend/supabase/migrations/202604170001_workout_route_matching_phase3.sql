alter table public.workout_sessions
  add column if not exists filtered_route_json jsonb not null default '[]'::jsonb,
  add column if not exists matched_route_json jsonb not null default '[]'::jsonb,
  add column if not exists route_match_status text not null default 'pending',
  add column if not exists route_match_confidence double precision,
  add column if not exists route_distance_source text not null default 'filtered',
  add column if not exists matched_distance_km double precision,
  add column if not exists route_match_metrics_json jsonb not null default '{}'::jsonb;

alter table public.workout_sessions
  drop constraint if exists workout_sessions_route_distance_source_check;

alter table public.workout_sessions
  add constraint workout_sessions_route_distance_source_check
  check (
    route_distance_source in (
      'filtered',
      'matched',
      'filtered_display_matched'
    )
  );

alter table public.workout_sessions
  drop constraint if exists workout_sessions_route_match_status_check;

alter table public.workout_sessions
  add constraint workout_sessions_route_match_status_check
  check (
    route_match_status in (
      'pending',
      'not_requested',
      'matched_success_high_confidence',
      'matched_success_medium_confidence',
      'partial_match',
      'match_failed_fallback_filtered'
    )
  );

create index if not exists idx_workout_sessions_route_match_status
  on public.workout_sessions (route_match_status);

create index if not exists idx_workout_sessions_route_distance_source
  on public.workout_sessions (route_distance_source);

comment on column public.workout_sessions.filtered_route_json is
  'Filtered route snapshot captured on the client when the workout finishes. Array of route segments.';

comment on column public.workout_sessions.matched_route_json is
  'Final corrected route after post-workout map matching. Array of route segments.';

comment on column public.workout_sessions.route_match_status is
  'Phase 3 route correction state for this workout.';

comment on column public.workout_sessions.route_match_confidence is
  '0..1 confidence score computed by the backend route matching worker.';

comment on column public.workout_sessions.route_distance_source is
  'Which route source is allowed to drive official distance metrics.';

comment on column public.workout_sessions.matched_distance_km is
  'Distance derived from the matched route when the backend considers it trustworthy enough.';

comment on column public.workout_sessions.route_match_metrics_json is
  'Quality metrics and diagnostics for route matching, such as coverage ratio and continuity score.';
