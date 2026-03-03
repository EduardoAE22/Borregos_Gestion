-- P0 alignment: DB <-> app contract + security

-- 1) Payments columns expected by app code.
alter table public.payments
  add column if not exists paid_at timestamptz;

alter table public.payments
  add column if not exists notes text;

alter table public.payments
  add column if not exists created_by uuid references public.profiles (id) on delete set null;

update public.payments
set paid_at = coalesce(paid_at, created_at, timezone('utc', now()))
where paid_at is null;

alter table public.payments
  alter column paid_at set not null;

alter table public.payments
  alter column paid_at set default timezone('utc', now());

-- 2) app_settings used by weekly summary/settings.
create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.app_settings enable row level security;

drop policy if exists app_settings_select_authenticated on public.app_settings;
create policy app_settings_select_authenticated
on public.app_settings
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists app_settings_super_admin_all on public.app_settings;
create policy app_settings_super_admin_all
on public.app_settings
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists app_settings_coach_all on public.app_settings;
create policy app_settings_coach_all
on public.app_settings
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

-- 3) Games game_type contract used by season tabs.
alter table public.games
  add column if not exists game_type text;

update public.games
set game_type = case
  when coalesce(is_tournament, false) then 'torneo'
  else 'amistoso'
end
where game_type is null;

alter table public.games
  alter column game_type set default 'torneo';

alter table public.games
  alter column game_type set not null;

alter table public.games
  drop constraint if exists games_game_type_check;

alter table public.games
  add constraint games_game_type_check
  check (game_type in ('torneo', 'amistoso', 'interno'));

-- 4) uniform_order_extras RLS explicit for authenticated + role gate.
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

-- 5) Payments writes for coach to match app permissions.
drop policy if exists payments_coach_all on public.payments;
create policy payments_coach_all
on public.payments
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

notify pgrst, 'reload schema';
