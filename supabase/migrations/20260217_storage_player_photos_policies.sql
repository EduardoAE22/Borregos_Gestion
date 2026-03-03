insert into storage.buckets (id, name, public)
values ('player_photos', 'player_photos', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists player_photos_select_authenticated on storage.objects;
create policy player_photos_select_authenticated
on storage.objects
for select
to authenticated
using (bucket_id = 'player_photos');

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
