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
  alter column season_id drop not null;

update public.games
set season_id = null
where game_type in ('amistoso', 'interno');

alter table public.games
  drop constraint if exists games_season_required_by_type_check;

alter table public.games
  drop constraint if exists games_season_by_type_check;

alter table public.games
  drop constraint if exists games_game_type_check;

alter table public.games
  add constraint games_game_type_check
  check (game_type in ('torneo', 'amistoso', 'interno'));

alter table public.games
  add constraint games_season_by_type_check
  check (
    (game_type = 'torneo' and season_id is not null) or
    (game_type in ('amistoso', 'interno') and season_id is null)
  );

notify pgrst, 'reload schema';
