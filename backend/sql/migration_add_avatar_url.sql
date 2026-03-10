-- ================================================================
-- migration_add_avatar_url.sql
-- Adds avatar_url column to user_profiles table.
-- Run once in Supabase SQL Editor.
-- ================================================================

-- Step 1: Add avatar_url column to user_profiles
alter table public.user_profiles
  add column if not exists avatar_url text;

comment on column public.user_profiles.avatar_url is
  'Public URL of the user avatar stored in Supabase Storage (avatars bucket).';

-- Step 2: Create the storage bucket if it does not exist yet.
-- NOTE: Run this via Supabase Dashboard → Storage → New bucket, OR via the
-- Management API. The SQL below uses the storage schema (available on Supabase).
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Step 3: RLS policies for the avatars bucket
-- Users can upload their own avatar (path = avatars/<userId>.jpg)
create policy "avatars: anyone can view"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars: authenticated users can upload own file"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars: owner can update own file"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars: owner can delete own file"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
