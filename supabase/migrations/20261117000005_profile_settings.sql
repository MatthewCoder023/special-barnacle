-- Profile customization: username, photo, charging preferences, and
-- notification and privacy preferences.

alter table public.profiles
  add column username text unique
    check (username ~ '^[a-z0-9_]{3,20}$'),
  add column avatar_url text,
  -- Charging preferences used by route planning.
  add column charge_to_pct int not null default 80
    check (charge_to_pct between 50 and 100),
  add column reserve_pct int not null default 10
    check (reserve_pct between 0 and 30),
  -- Notification preferences, by kind. Account notices are always sent.
  add column notify_community boolean not null default true,
  add column notify_events boolean not null default true,
  add column notify_polls boolean not null default true,
  -- Privacy preferences.
  add column show_vehicle boolean not null default true,
  add column show_name_on_stations boolean not null default true;

-- Profile photos. The bucket is public to read, limited to small images,
-- and each user can write only inside the folder named after their own id.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars', 'avatars', true, 2097152,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

create policy "users add their own avatar" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "users replace their own avatar" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "users remove their own avatar" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Replacing a photo (upsert) reads the existing entry first, so users need
-- to see their own entries. Everyone can already view the images through
-- the bucket's public links.
create policy "users see their own avatar entry" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
