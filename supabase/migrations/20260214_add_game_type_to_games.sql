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

notify pgrst, 'reload schema';
