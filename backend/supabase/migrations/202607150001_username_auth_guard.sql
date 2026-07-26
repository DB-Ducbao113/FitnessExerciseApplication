-- Username/password accounts use internal auth emails only. Google OAuth is
-- allowed for identity linking, but cannot create a separate account.
create or replace function public.hook_allow_username_accounts_only(event jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  provider text := coalesce(event -> 'user' -> 'app_metadata' ->> 'provider', '');
  email text := lower(coalesce(event -> 'user' ->> 'email', ''));
begin
  if provider = 'email' and email like '%@aetron.local' then
    return '{}'::jsonb;
  end if;

  return jsonb_build_object(
    'error',
    jsonb_build_object(
      'http_code', 403,
      'message', 'Create an Aetron account with a username and password first.'
    )
  );
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.hook_allow_username_accounts_only(jsonb)
  to supabase_auth_admin;
revoke execute on function public.hook_allow_username_accounts_only(jsonb)
  from authenticated, anon, public;
