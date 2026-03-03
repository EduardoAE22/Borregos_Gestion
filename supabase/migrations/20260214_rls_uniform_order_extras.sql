alter table public.uniform_order_extras enable row level security;

drop policy if exists uniform_order_extras_select_authenticated on public.uniform_order_extras;
create policy uniform_order_extras_select_authenticated
on public.uniform_order_extras
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists uniform_order_extras_super_admin_all on public.uniform_order_extras;
create policy uniform_order_extras_super_admin_all
on public.uniform_order_extras
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists uniform_order_extras_coach_all on public.uniform_order_extras;
create policy uniform_order_extras_coach_all
on public.uniform_order_extras
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');
