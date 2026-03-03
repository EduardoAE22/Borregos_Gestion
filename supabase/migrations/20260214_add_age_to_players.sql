alter table public.players
  add column if not exists age integer;

alter table public.players
  drop constraint if exists players_age_check;

alter table public.players
  add constraint players_age_check
  check (age is null or (age >= 3 and age <= 80));
