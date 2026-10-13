-- The Edge Function uses canonical workout_sessions IDs and auth.users IDs.
-- Keep the replacement constraints NOT VALID so existing legacy rows cannot
-- block a production forward migration; every new row is still enforced.

alter table public.workout_ai_insights
  drop constraint if exists workout_ai_insights_workout_id_fkey;

alter table public.workout_ai_insights
  add constraint workout_ai_insights_workout_id_fkey
  foreign key (workout_id)
  references public.workout_sessions(id)
  on delete cascade
  not valid;

alter table public.workout_ai_insights
  drop constraint if exists workout_ai_insights_user_id_fkey;

alter table public.workout_ai_insights
  add constraint workout_ai_insights_user_id_fkey
  foreign key (user_id)
  references auth.users(id)
  on delete cascade
  not valid;

do $$
begin
  if not exists (
    select 1
    from public.workout_ai_insights insights
    left join public.workout_sessions sessions
      on sessions.id = insights.workout_id
    where sessions.id is null
  ) then
    alter table public.workout_ai_insights
      validate constraint workout_ai_insights_workout_id_fkey;
  end if;

  if not exists (
    select 1
    from public.workout_ai_insights insights
    left join auth.users users
      on users.id = insights.user_id
    where users.id is null
  ) then
    alter table public.workout_ai_insights
      validate constraint workout_ai_insights_user_id_fkey;
  end if;
end;
$$;
