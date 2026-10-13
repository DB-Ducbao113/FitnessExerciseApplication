create or replace function public.verify_recovery_email_code(
  p_user_id uuid,
  p_recovery_email text,
  p_code_hash text
)
returns table (status text, verified_at timestamptz, attempt_count integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_verification public.recovery_email_verifications%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  select * into v_verification
  from public.recovery_email_verifications
  where user_id = p_user_id
    and lower(recovery_email) = lower(p_recovery_email)
    and consumed_at is null
  order by created_at desc
  limit 1
  for update;

  if not found then
    status := 'not_found';
    return next;
    return;
  end if;
  if v_verification.attempt_count >= 5 then
    status := 'locked';
    attempt_count := v_verification.attempt_count;
    return next;
    return;
  end if;
  if v_verification.expires_at < v_now then
    update public.recovery_email_verifications
    set consumed_at = v_now
    where id = v_verification.id;
    status := 'expired';
    attempt_count := v_verification.attempt_count;
    return next;
    return;
  end if;
  if v_verification.code_hash <> p_code_hash then
    update public.recovery_email_verifications as verification
    set attempt_count = verification.attempt_count + 1
    where verification.id = v_verification.id
    returning verification.attempt_count into attempt_count;
    status := case when attempt_count >= 5 then 'locked' else 'incorrect' end;
    return next;
    return;
  end if;

  update public.user_recovery_emails
  set verified_at = v_now
  where user_id = p_user_id
    and lower(recovery_email) = lower(p_recovery_email);
  if not found then
    raise exception 'Recovery email record not found';
  end if;

  update public.recovery_email_verifications
  set consumed_at = v_now
  where id = v_verification.id;

  status := 'verified';
  verified_at := v_now;
  attempt_count := v_verification.attempt_count;
  return next;
end;
$$;

revoke all on function public.verify_recovery_email_code(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.verify_recovery_email_code(uuid, text, text)
  to service_role;
