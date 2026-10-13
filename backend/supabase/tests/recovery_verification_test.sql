begin;

insert into auth.users (
  id,
  aud,
  role,
  email,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values (
  '30000000-0000-4000-8000-000000000003',
  'authenticated',
  'authenticated',
  'recovery-owner@aetron.local',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

insert into public.user_recovery_emails (
  user_id,
  recovery_email
) values (
  '30000000-0000-4000-8000-000000000003',
  'recovery.fixture@gmail.com'
);

insert into public.recovery_email_verifications (
  user_id,
  recovery_email,
  code_hash,
  expires_at
) values (
  '30000000-0000-4000-8000-000000000003',
  'recovery.fixture@gmail.com',
  repeat('a', 64),
  now() + interval '10 minutes'
);

do $$
declare
  verification_status text;
  verification_attempts integer;
begin
  for attempt_index in 1..5 loop
    select status, attempt_count
    into verification_status, verification_attempts
    from public.verify_recovery_email_code(
      '30000000-0000-4000-8000-000000000003',
      'recovery.fixture@gmail.com',
      repeat('b', 64)
    );

    if attempt_index < 5 and verification_status <> 'incorrect' then
      raise exception
        'Expected incorrect on attempt %, got %',
        attempt_index,
        verification_status;
    end if;
    if attempt_index = 5 and verification_status <> 'locked' then
      raise exception 'Expected locked on attempt 5, got %', verification_status;
    end if;
    if verification_attempts <> attempt_index then
      raise exception
        'Expected attempt_count %, got %',
        attempt_index,
        verification_attempts;
    end if;
  end loop;

  select status, attempt_count
  into verification_status, verification_attempts
  from public.verify_recovery_email_code(
    '30000000-0000-4000-8000-000000000003',
    'recovery.fixture@gmail.com',
    repeat('a', 64)
  );

  if verification_status <> 'locked' or verification_attempts <> 5 then
    raise exception
      'A locked verification accepted the correct code: status %, attempts %',
      verification_status,
      verification_attempts;
  end if;
end;
$$;

rollback;
