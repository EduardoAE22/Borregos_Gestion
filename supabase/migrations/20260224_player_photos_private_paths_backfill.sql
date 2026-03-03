alter table public.players
  add column if not exists photo_path text,
  add column if not exists photo_thumb_path text;

update public.players
set photo_path = case
  when photo_url is null or btrim(photo_url) = '' then photo_path
  when btrim(photo_url) like 'http%' and btrim(photo_url) ~ '^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/(public|sign)/player_photos/' then
    split_part(
      regexp_replace(
        btrim(photo_url),
        '^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/(public|sign)/player_photos/',
        ''
      ),
      '?',
      1
    )
  when btrim(photo_url) not like 'http%' then split_part(btrim(photo_url), '?', 1)
  else photo_path
end
where photo_path is null;

update public.players
set photo_thumb_path = case
  when photo_thumb_url is null or btrim(photo_thumb_url) = '' then photo_thumb_path
  when btrim(photo_thumb_url) like 'http%' and btrim(photo_thumb_url) ~ '^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/(public|sign)/player_photos/' then
    split_part(
      regexp_replace(
        btrim(photo_thumb_url),
        '^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/(public|sign)/player_photos/',
        ''
      ),
      '?',
      1
    )
  when btrim(photo_thumb_url) not like 'http%' then split_part(btrim(photo_thumb_url), '?', 1)
  else photo_thumb_path
end
where photo_thumb_path is null;

insert into storage.buckets (id, name, public)
values ('player_photos', 'player_photos', false)
on conflict (id) do nothing;

update storage.buckets
set public = false
where id = 'player_photos';

drop policy if exists player_photos_select_authenticated on storage.objects;
drop policy if exists player_photos_select_coach_admin on storage.objects;
create policy player_photos_select_coach_admin
on storage.objects
for select
to authenticated
using (
  bucket_id = 'player_photos'
  and public.current_role() in ('super_admin', 'coach')
);

drop policy if exists player_photos_insert_coach_admin on storage.objects;
create policy player_photos_insert_coach_admin
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'player_photos'
  and public.current_role() in ('super_admin', 'coach')
);

drop policy if exists player_photos_update_coach_admin on storage.objects;
create policy player_photos_update_coach_admin
on storage.objects
for update
to authenticated
using (
  bucket_id = 'player_photos'
  and public.current_role() in ('super_admin', 'coach')
)
with check (
  bucket_id = 'player_photos'
  and public.current_role() in ('super_admin', 'coach')
);

drop policy if exists player_photos_delete_coach_admin on storage.objects;
create policy player_photos_delete_coach_admin
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'player_photos'
  and public.current_role() in ('super_admin', 'coach')
);

notify pgrst, 'reload schema';
