-- ================================================================
-- migration_add_avatar_url.sql
-- Adds avatar_url support and storage bucket policies.
-- Safe to re-run.
-- ================================================================

alter table public.user_profiles
  add column if not exists avatar_url text;

comment on column public.user_profiles.avatar_url is
  'Public URL of the user avatar stored in Supabase Storage (avatars bucket).';

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars: anyone can view" on storage.objects;
create policy "avatars: anyone can view"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars: authenticated users can upload own file" on storage.objects;
create policy "avatars: authenticated users can upload own file"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars: owner can update own file" on storage.objects;
create policy "avatars: owner can update own file"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars: owner can delete own file" on storage.objects;
create policy "avatars: owner can delete own file"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
