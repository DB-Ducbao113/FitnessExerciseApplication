-- Allow Google, Apple, and OAuth providers to create new accounts directly.
create or replace function public.hook_allow_username_accounts_only(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  provider text := coalesce(event -> 'user' -> 'app_metadata' ->> 'provider', '');
  email text := lower(coalesce(event -> 'user' ->> 'email', ''));
begin
  -- Allow username/password accounts (@aetron.local)
  if provider = 'email' and email like '%@aetron.local' then
    return '{}'::jsonb;
  end if;

  -- Allow Google OAuth, Apple, and other social sign-ins
  if provider in ('google', 'apple', 'facebook') or (provider is not null and provider != '' and provider != 'email') then
    return '{}'::jsonb;
  end if;

  -- Allow if valid email
  if email != '' and email like '%@%' then
    return '{}'::jsonb;
  end if;

  return '{}'::jsonb;
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.hook_allow_username_accounts_only(jsonb)
  to supabase_auth_admin;
revoke execute on function public.hook_allow_username_accounts_only(jsonb)
  from authenticated, anon, public;
