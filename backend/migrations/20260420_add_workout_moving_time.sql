alter table public.workout_sessions
  add column if not exists moving_time_sec int not null default 0
  check (moving_time_sec >= 0);

update public.workout_sessions
set moving_time_sec = coalesce(duration_sec, 0)
where moving_time_sec = 0
  and mode = 'indoor';

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'workout_sessions'
      and column_name = 'gps_analysis'
  ) then
    execute $sql$
      update public.workout_sessions
      set moving_time_sec = greatest(
        0,
        coalesce(duration_sec, 0) -
        coalesce((gps_analysis ->> 'restDurationSec')::int, 0)
      )
      where moving_time_sec = 0
        and mode <> 'indoor'
    $sql$;
  else
    update public.workout_sessions
    set moving_time_sec = coalesce(duration_sec, 0)
    where moving_time_sec = 0
      and mode <> 'indoor';
  end if;
end $$;
