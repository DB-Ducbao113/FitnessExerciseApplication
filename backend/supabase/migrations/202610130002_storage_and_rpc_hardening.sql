-- Avatars contain personal images. Keep object access behind authenticated
-- Storage RLS and serve them through short-lived signed URLs.
update storage.buckets
set
  public = false,
  file_size_limit = 5 * 1024 * 1024,
  allowed_mime_types = array['image/jpeg']::text[]
where id = 'avatars';

comment on column public.user_profiles.avatar_url is
  'Private avatars bucket object path; clients resolve it to a short-lived signed URL.';

drop policy if exists "avatars: anyone can view" on storage.objects;
drop policy if exists "avatars: view own" on storage.objects;
create policy "avatars: view own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- SECURITY DEFINER functions must not search caller-writable schemas and must
-- never inherit PostgreSQL's default PUBLIC EXECUTE grant.
alter function public.delete_user_account() set search_path = '';
revoke all on function public.delete_user_account()
  from public, anon;
grant execute on function public.delete_user_account() to authenticated;
