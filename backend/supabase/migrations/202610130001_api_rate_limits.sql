-- Durable, atomic rate limits for security-sensitive Edge Functions.
-- Keys are SHA-256 digests; raw IP addresses and email addresses are never stored.

create table if not exists public.api_rate_limits (
  scope text not null,
  key_hash text not null,
  window_started_at timestamptz not null default now(),
  request_count integer not null default 1 check (request_count > 0),
  primary key (scope, key_hash),
  constraint api_rate_limits_scope_length check (length(scope) between 1 and 80),
  constraint api_rate_limits_key_hash check (key_hash ~ '^[0-9a-f]{64}$')
);

create index if not exists api_rate_limits_window_started_at_idx
  on public.api_rate_limits (window_started_at);

alter table public.api_rate_limits enable row level security;
revoke all on table public.api_rate_limits from public, anon, authenticated;
grant select, insert, update, delete on table public.api_rate_limits to service_role;

create or replace function public.consume_api_rate_limit(
  p_scope text,
  p_key_hash text,
  p_limit integer,
  p_window_seconds integer
)
returns table (allowed boolean, retry_after_seconds integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_window_started_at timestamptz;
  v_request_count integer;
begin
  if p_scope is null or length(p_scope) not between 1 and 80
    or p_key_hash is null or p_key_hash !~ '^[0-9a-f]{64}$'
    or p_limit is null or p_limit not between 1 and 10000
    or p_window_seconds is null or p_window_seconds not between 1 and 86400 then
    raise exception 'Invalid rate limit parameters';
  end if;

  insert into public.api_rate_limits (
    scope,
    key_hash,
    window_started_at,
    request_count
  ) values (
    p_scope,
    p_key_hash,
    v_now,
    1
  )
  on conflict (scope, key_hash) do update
  set
    window_started_at = case
      when public.api_rate_limits.window_started_at
        + make_interval(secs => p_window_seconds) <= v_now
      then v_now
      else public.api_rate_limits.window_started_at
    end,
    request_count = case
      when public.api_rate_limits.window_started_at
        + make_interval(secs => p_window_seconds) <= v_now
      then 1
      else public.api_rate_limits.request_count + 1
    end
  returning api_rate_limits.window_started_at, api_rate_limits.request_count
    into v_window_started_at, v_request_count;

  allowed := v_request_count <= p_limit;
  retry_after_seconds := greatest(
    1,
    ceil(extract(epoch from (
      v_window_started_at + make_interval(secs => p_window_seconds) - v_now
    )))::integer
  );
  return next;
end;
$$;

revoke all on function public.consume_api_rate_limit(text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_api_rate_limit(text, text, integer, integer)
  to service_role;

create or replace function public.cleanup_api_rate_limits()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.api_rate_limits
  where window_started_at < now() - interval '2 days';
$$;

revoke all on function public.cleanup_api_rate_limits()
  from public, anon, authenticated;
grant execute on function public.cleanup_api_rate_limits() to service_role;

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
    update public.recovery_email_verifications
    set attempt_count = attempt_count + 1
    where id = v_verification.id
    returning recovery_email_verifications.attempt_count into attempt_count;
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

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('cleanup-api-rate-limits');
    exception when others then
      null;
    end;
    perform cron.schedule(
      'cleanup-api-rate-limits',
      '17 * * * *',
      'select public.cleanup_api_rate_limits();'
    );
  end if;
end;
$$;
