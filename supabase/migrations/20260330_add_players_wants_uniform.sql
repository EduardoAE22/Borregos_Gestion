alter table public.players
add column if not exists wants_uniform boolean not null default true;
