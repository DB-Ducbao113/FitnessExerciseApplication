create table if not exists public.user_recovery_emails (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recovery_email text not null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_recovery_emails_user_id_unique unique (user_id),
  constraint user_recovery_emails_gmail_check check (
    lower(recovery_email) like '%@gmail.com'
  )
);

create unique index if not exists user_recovery_emails_lower_email_unique
  on public.user_recovery_emails (lower(recovery_email));

create index if not exists idx_user_recovery_emails_user_id
  on public.user_recovery_emails (user_id);

drop trigger if exists trg_user_recovery_emails_updated_at
  on public.user_recovery_emails;
create trigger trg_user_recovery_emails_updated_at
  before update on public.user_recovery_emails
  for each row execute function public.set_updated_at();

alter table public.user_recovery_emails enable row level security;

drop policy if exists "user_recovery_emails: select own"
  on public.user_recovery_emails;
create policy "user_recovery_emails: select own"
  on public.user_recovery_emails for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "user_recovery_emails: delete own"
  on public.user_recovery_emails;
create policy "user_recovery_emails: delete own"
  on public.user_recovery_emails for delete
  to authenticated
  using (auth.uid() = user_id);

create table if not exists public.recovery_email_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recovery_email text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  attempt_count int not null default 0,
  created_at timestamptz not null default now(),
  constraint recovery_email_verifications_gmail_check check (
    lower(recovery_email) like '%@gmail.com'
  )
);

create index if not exists idx_recovery_email_verifications_user_email
  on public.recovery_email_verifications (
    user_id,
    lower(recovery_email),
    created_at desc
  );

alter table public.recovery_email_verifications enable row level security;

drop policy if exists "recovery_email_verifications: no client access"
  on public.recovery_email_verifications;
create policy "recovery_email_verifications: no client access"
  on public.recovery_email_verifications
  as restrictive
  for all
  to authenticated
  using (false)
  with check (false);
