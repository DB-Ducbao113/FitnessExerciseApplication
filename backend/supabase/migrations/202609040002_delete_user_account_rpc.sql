-- Migration: Add secure delete_user_account RPC function and DELETE policies for workout child tables

-- 1. Create secure function allowing authenticated users to delete their own account and all linked data
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
begin
  -- Retrieve currently authenticated user ID from context
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- 1. Delete workout child records
  delete from public.workout_segment_audits
  where workout_id in (select id from public.workout_sessions where user_id = v_user_id);

  delete from public.workout_processing_logs
  where workout_id in (select id from public.workout_sessions where user_id = v_user_id);

  delete from public.workout_processing_jobs
  where workout_id in (select id from public.workout_sessions where user_id = v_user_id);

  delete from public.raw_gps_points
  where workout_id in (select id from public.workout_sessions where user_id = v_user_id);

  delete from public.raw_step_intervals
  where workout_id in (select id from public.workout_sessions where user_id = v_user_id);

  -- 2. Delete workout sessions
  delete from public.workout_sessions where user_id = v_user_id;

  -- 3. Delete recovery emails & verifications
  delete from public.recovery_email_verifications where user_id = v_user_id;
  delete from public.user_recovery_emails where user_id = v_user_id;

  -- 4. Delete user goals
  delete from public.user_goals where user_id = v_user_id;

  -- 5. Delete user profiles
  delete from public.user_profiles where user_id = v_user_id or id = v_user_id;

  -- 6. Delete user from auth.users (removes authentication identity)
  delete from auth.users where id = v_user_id;
end;
$$;

-- Grant execution permissions
grant execute on function public.delete_user_account() to authenticated;

-- 2. Add missing DELETE RLS policies for workout child tables so client cascades do not fail
drop policy if exists "workout_segment_audits: delete own" on public.workout_segment_audits;
create policy "workout_segment_audits: delete own"
  on public.workout_segment_audits for delete
  to authenticated
  using (
    exists (
      select 1 from public.workout_sessions ws
      where ws.id = workout_segment_audits.workout_id
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
