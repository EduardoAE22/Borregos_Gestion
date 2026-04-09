alter table public.players
add column if not exists payment_mode text not null default 'normal';

alter table public.players
drop constraint if exists players_payment_mode_check;

alter table public.players
add constraint players_payment_mode_check
check (payment_mode in ('normal', 'exempt'));

create table if not exists public.training_sessions (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  session_date date not null,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint training_sessions_unique unique (season_id, session_date)
);

create table if not exists public.player_attendance (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  attended_on date not null,
  status text not null,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint player_attendance_player_day_unique unique (player_id, attended_on),
  constraint player_attendance_status_check check (status in ('present', 'absent'))
);

create index if not exists idx_training_sessions_season_id
on public.training_sessions (season_id);

create index if not exists idx_training_sessions_session_date
on public.training_sessions (session_date);

create index if not exists idx_player_attendance_season_id
on public.player_attendance (season_id);

create index if not exists idx_player_attendance_player_id
on public.player_attendance (player_id);

create index if not exists idx_player_attendance_attended_on
on public.player_attendance (attended_on);

alter table public.training_sessions enable row level security;
alter table public.player_attendance enable row level security;

drop policy if exists training_sessions_select_authenticated on public.training_sessions;
create policy training_sessions_select_authenticated
on public.training_sessions
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists player_attendance_select_authenticated on public.player_attendance;
create policy player_attendance_select_authenticated
on public.player_attendance
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists training_sessions_super_admin_all on public.training_sessions;
create policy training_sessions_super_admin_all
on public.training_sessions
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists player_attendance_super_admin_all on public.player_attendance;
create policy player_attendance_super_admin_all
on public.player_attendance
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists training_sessions_coach_all on public.training_sessions;
create policy training_sessions_coach_all
on public.training_sessions
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

drop policy if exists player_attendance_coach_all on public.player_attendance;
create policy player_attendance_coach_all
on public.player_attendance
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');
