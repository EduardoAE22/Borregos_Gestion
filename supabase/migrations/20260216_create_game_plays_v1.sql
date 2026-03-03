create table if not exists public.game_plays (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  half smallint not null check (half in (1, 2)),
  unit text not null check (unit in ('ofensiva', 'defensiva')),
  down smallint check (down between 1 and 4),
  distance_yards integer check (distance_yards >= 0),
  yards integer not null default 0,
  points integer not null default 0 check (points in (0, 1, 2, 3, 6, 7, 8)),
  description text,
  notes text,
  qb_player_id uuid references public.players (id) on delete set null,
  receiver_player_id uuid references public.players (id) on delete set null,
  is_target boolean not null default false,
  is_completion boolean not null default false,
  is_drop boolean not null default false,
  is_pass_td boolean not null default false,
  is_rush boolean not null default false,
  is_rush_td boolean not null default false,
  defender_player_id uuid references public.players (id) on delete set null,
  is_sack boolean not null default false,
  is_tackle_flag boolean not null default false,
  is_interception boolean not null default false,
  is_pick6 boolean not null default false,
  is_pass_defended boolean not null default false,
  is_penalty boolean not null default false,
  penalty_text text
);

create index if not exists idx_game_plays_game_id on public.game_plays (game_id);
create index if not exists idx_game_plays_half_unit on public.game_plays (half, unit);
create index if not exists idx_game_plays_qb_player_id on public.game_plays (qb_player_id);
create index if not exists idx_game_plays_receiver_player_id on public.game_plays (receiver_player_id);
create index if not exists idx_game_plays_defender_player_id on public.game_plays (defender_player_id);

alter table public.game_plays enable row level security;

drop policy if exists game_plays_select_coach_admin on public.game_plays;
create policy game_plays_select_coach_admin
on public.game_plays
for select
to authenticated
using (public."current_role"() in ('super_admin', 'coach'));

drop policy if exists game_plays_insert_coach_admin on public.game_plays;
create policy game_plays_insert_coach_admin
on public.game_plays
for insert
to authenticated
with check (public."current_role"() in ('super_admin', 'coach'));

drop policy if exists game_plays_update_coach_admin on public.game_plays;
create policy game_plays_update_coach_admin
on public.game_plays
for update
to authenticated
using (public."current_role"() in ('super_admin', 'coach'))
with check (public."current_role"() in ('super_admin', 'coach'));

drop policy if exists game_plays_delete_coach_admin on public.game_plays;
create policy game_plays_delete_coach_admin
on public.game_plays
for delete
to authenticated
using (public."current_role"() in ('super_admin', 'coach'));

notify pgrst, 'reload schema';
