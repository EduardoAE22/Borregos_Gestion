insert into storage.buckets (id, name, public)
values ('payment_receipts', 'payment_receipts', false)
on conflict (id) do nothing;

update storage.buckets
set public = false
where id = 'payment_receipts';

drop policy if exists payment_receipts_select_coach_admin on storage.objects;
create policy payment_receipts_select_coach_admin
on storage.objects
for select
to authenticated
using (
  bucket_id = 'payment_receipts'
  and public.current_role() in ('super_admin', 'coach')
);

drop policy if exists payment_receipts_insert_coach_admin on storage.objects;
create policy payment_receipts_insert_coach_admin
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'payment_receipts'
  and public.current_role() in ('super_admin', 'coach')
);

drop policy if exists payment_receipts_update_coach_admin on storage.objects;
create policy payment_receipts_update_coach_admin
on storage.objects
for update
to authenticated
using (
  bucket_id = 'payment_receipts'
  and public.current_role() in ('super_admin', 'coach')
)
with check (
  bucket_id = 'payment_receipts'
  and public.current_role() in ('super_admin', 'coach')
);

drop policy if exists payment_receipts_delete_coach_admin on storage.objects;
create policy payment_receipts_delete_coach_admin
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'payment_receipts'
  and public.current_role() in ('super_admin', 'coach')
);

notify pgrst, 'reload schema';
