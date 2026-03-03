create table if not exists public.game_events (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  period integer not null check (period in (1, 2)),
  side text not null check (side in ('ofensa', 'defensa')),
  event_type text not null,
  yards integer,
  notes text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_game_events_game_id on public.game_events (game_id);
create index if not exists idx_game_events_player_id on public.game_events (player_id);
create index if not exists idx_game_events_period_side on public.game_events (period, side);

alter table public.game_events enable row level security;

drop policy if exists game_events_select_authenticated on public.game_events;
create policy game_events_select_authenticated
on public.game_events
for select
to authenticated
using (auth.uid() is not null);

drop policy if exists game_events_super_admin_all on public.game_events;
create policy game_events_super_admin_all
on public.game_events
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'super_admin')
with check (auth.uid() is not null and public.current_role() = 'super_admin');

drop policy if exists game_events_coach_all on public.game_events;
create policy game_events_coach_all
on public.game_events
for all
to authenticated
using (auth.uid() is not null and public.current_role() = 'coach')
with check (auth.uid() is not null and public.current_role() = 'coach');

notify pgrst, 'reload schema';
