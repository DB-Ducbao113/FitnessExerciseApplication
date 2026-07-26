-- ================================================================
-- Fix Supabase Advisor Warnings
-- 1. Enable RLS on public.spatial_ref_sys
-- 2. Revoke PUBLIC execution from st_estimatedextent
-- 3. Update public.update_user_profile and public.set_updated_at search_path
-- ================================================================

-- 1. (Skipped) RLS on public.spatial_ref_sys - Owned by supabase_admin, usually ignored

-- 2. Revoke PUBLIC execution from SECURITY DEFINER functions dynamically
do $$ 
declare
    func_record record;
    revoke_stmt text;
begin
    for func_record in 
        select pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on p.pronamespace = n.oid
        where n.nspname = 'public' and p.proname = 'st_estimatedextent'
    loop
        revoke_stmt := format('REVOKE EXECUTE ON FUNCTION public.st_estimatedextent(%s) FROM PUBLIC;', func_record.args);
        execute revoke_stmt;
    end loop;
end $$;

-- 3. Set search_path for set_updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 4. Try to fix update_user_profile if it exists by altering it using a DO block
do $$ 
declare
    func_record record;
    alter_stmt text;
begin
    for func_record in 
        select p.proname, pg_get_function_identity_arguments(p.oid) as args
        from pg_proc p
        join pg_namespace n on p.pronamespace = n.oid
        where n.nspname = 'public' and p.proname = 'update_user_profile'
    loop
        alter_stmt := format('ALTER FUNCTION public.%I(%s) SET search_path = '''';', func_record.proname, func_record.args);
        execute alter_stmt;
    end loop;
end $$;

-- 5. Fix Public Bucket Allows Listing for avatars
drop policy if exists "avatars: anyone can view" on storage.objects;
drop policy if exists "avatars: view own" on storage.objects;
create policy "avatars: view own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
