-- Row Level Security policies for Borregos Gestion (Supabase/Postgres)
-- Roles in public.profiles.role: super_admin, coach, viewer

-- Helper: current authenticated user's role from profiles.
create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
  limit 1
$$;

comment on function public.current_role() is
  'Returns current authenticated user role from public.profiles using auth.uid().';

grant execute on function public.current_role() to authenticated;

-- Enable RLS on all application tables.
alter table public.profiles enable row level security;
alter table public.seasons enable row level security;
alter table public.players enable row level security;
alter table public.player_metrics enable row level security;
alter table public.uniform_order_extras enable row level security;
alter table public.app_settings enable row level security;
alter table public.payment_concepts enable row level security;
alter table public.payments enable row level security;
alter table public.games enable row level security;
alter table public.game_events enable row level security;
alter table public.game_plays enable row level security;
alter table public.game_stats_qb enable row level security;
alter table public.game_stats_skill enable row level security;
alter table public.game_stats_def enable row level security;
alter table public.awards_player_month enable row level security;

-- =========================
-- SELECT policies
-- Any authenticated user can read all tables.
-- =========================

drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_authenticated
on public.profiles
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists seasons_select_authenticated on public.seasons;
create policy seasons_select_authenticated
on public.seasons
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists players_select_authenticated on public.players;
create policy players_select_authenticated
on public.players
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists player_metrics_select_authenticated on public.player_metrics;
create policy player_metrics_select_authenticated
on public.player_metrics
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists uniform_order_extras_select_authenticated on public.uniform_order_extras;
create policy uniform_order_extras_select_authenticated
on public.uniform_order_extras
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists app_settings_select_authenticated on public.app_settings;
create policy app_settings_select_authenticated
on public.app_settings
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists payment_concepts_select_authenticated on public.payment_concepts;
create policy payment_concepts_select_authenticated
on public.payment_concepts
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists payments_select_authenticated on public.payments;
create policy payments_select_authenticated
on public.payments
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists games_select_authenticated on public.games;
create policy games_select_authenticated
on public.games
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists game_events_select_authenticated on public.game_events;
create policy game_events_select_authenticated
on public.game_events
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists game_plays_select_coach_admin on public.game_plays;
create policy game_plays_select_coach_admin
on public.game_plays
for select
to authenticated
using (public."current_role"() in ('super_admin', 'coach'));

drop policy if exists game_stats_qb_select_authenticated on public.game_stats_qb;
create policy game_stats_qb_select_authenticated
on public.game_stats_qb
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists game_stats_skill_select_authenticated on public.game_stats_skill;
create policy game_stats_skill_select_authenticated
on public.game_stats_skill
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists game_stats_def_select_authenticated on public.game_stats_def;
create policy game_stats_def_select_authenticated
on public.game_stats_def
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists awards_player_month_select_authenticated on public.awards_player_month;
create policy awards_player_month_select_authenticated
on public.awards_player_month
for select
to authenticated
using (auth.uid() is not null);

-- =========================
-- super_admin write policies
-- super_admin can CRUD all tables.
-- =========================

drop policy if exists profiles_super_admin_all on public.profiles;
create policy profiles_super_admin_all
on public.profiles
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists seasons_super_admin_all on public.seasons;
create policy seasons_super_admin_all
on public.seasons
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists players_super_admin_all on public.players;
create policy players_super_admin_all
on public.players
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists player_metrics_super_admin_all on public.player_metrics;
create policy player_metrics_super_admin_all
on public.player_metrics
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists uniform_order_extras_super_admin_all on public.uniform_order_extras;
create policy uniform_order_extras_super_admin_all
on public.uniform_order_extras
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists app_settings_super_admin_all on public.app_settings;
create policy app_settings_super_admin_all
on public.app_settings
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists payment_concepts_super_admin_all on public.payment_concepts;
create policy payment_concepts_super_admin_all
on public.payment_concepts
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists payments_super_admin_all on public.payments;
create policy payments_super_admin_all
on public.payments
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists games_super_admin_all on public.games;
create policy games_super_admin_all
on public.games
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists game_events_super_admin_all on public.game_events;
create policy game_events_super_admin_all
on public.game_events
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists game_plays_super_admin_all on public.game_plays;
create policy game_plays_super_admin_all
on public.game_plays
for all
to authenticated
using (public."current_role"() = 'super_admin')
with check (public."current_role"() = 'super_admin');

drop policy if exists game_stats_qb_super_admin_all on public.game_stats_qb;
create policy game_stats_qb_super_admin_all
on public.game_stats_qb
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists game_stats_skill_super_admin_all on public.game_stats_skill;
create policy game_stats_skill_super_admin_all
on public.game_stats_skill
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists game_stats_def_super_admin_all on public.game_stats_def;
create policy game_stats_def_super_admin_all
on public.game_stats_def
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists awards_player_month_super_admin_all on public.awards_player_month;
create policy awards_player_month_super_admin_all
on public.awards_player_month
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

-- =========================
-- coach write policies
-- coach can CRUD only in:
-- players, player_metrics, games, game_stats_*, awards_player_month.
-- =========================

drop policy if exists players_coach_all on public.players;
create policy players_coach_all
on public.players
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists player_metrics_coach_all on public.player_metrics;
create policy player_metrics_coach_all
on public.player_metrics
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists uniform_order_extras_coach_all on public.uniform_order_extras;
create policy uniform_order_extras_coach_all
on public.uniform_order_extras
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists app_settings_coach_all on public.app_settings;
create policy app_settings_coach_all
on public.app_settings
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists payments_coach_all on public.payments;
create policy payments_coach_all
on public.payments
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists games_coach_all on public.games;
create policy games_coach_all
on public.games
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists game_events_coach_all on public.game_events;
create policy game_events_coach_all
on public.game_events
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists game_plays_coach_all on public.game_plays;
create policy game_plays_coach_all
on public.game_plays
for all
to authenticated
using (public."current_role"() = 'coach')
with check (public."current_role"() = 'coach');

drop policy if exists game_stats_qb_coach_all on public.game_stats_qb;
create policy game_stats_qb_coach_all
on public.game_stats_qb
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists game_stats_skill_coach_all on public.game_stats_skill;
create policy game_stats_skill_coach_all
on public.game_stats_skill
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists game_stats_def_coach_all on public.game_stats_def;
create policy game_stats_def_coach_all
on public.game_stats_def
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists awards_player_month_coach_all on public.awards_player_month;
create policy awards_player_month_coach_all
on public.awards_player_month
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

-- Notes:
-- 1) viewer has no write policy, so writes are denied.
-- 2) payment_concepts write policy only for super_admin.
-- 3) payments and app_settings write policy for super_admin and coach.
-- 4) game_events write policy for super_admin and coach.
-- 5) game_plays write policy for super_admin and coach.
-- 6) profiles update/delete/insert are restricted to super_admin only.
