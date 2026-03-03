alter table public.games
  add column if not exists roster_season_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'games_roster_season_id_fkey'
      and conrelid = 'public.games'::regclass
  ) then
    alter table public.games
      add constraint games_roster_season_id_fkey
      foreign key (roster_season_id) references public.seasons (id) on delete set null;
  end if;
end
$$;

update public.games g
set roster_season_id = s.id
from (
  select id
  from public.seasons
  where is_active = true
  order by starts_on desc nulls last, created_at desc nulls last
  limit 1
) s
where g.season_id is null
  and g.roster_season_id is null;

notify pgrst, 'reload schema';
