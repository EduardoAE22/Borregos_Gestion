-- Schema for Borregos Gestion (Flag Football, sede unica: Progreso)
-- Postgres compatible with Supabase

create extension if not exists pgcrypto;

-- 1) User profile metadata linked to Supabase auth users.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('super_admin', 'coach', 'viewer')),
  created_at timestamptz not null default timezone('utc', now())
);
comment on table public.profiles is 'Perfil de usuario y rol de acceso para administracion del equipo.';

-- 2) Team seasons (only one venue, potentially many seasons).
create table if not exists public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  starts_on date not null,
  ends_on date not null,
  is_active boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  constraint seasons_dates_check check (ends_on >= starts_on)
);
comment on table public.seasons is 'Temporadas deportivas de la sede Progreso.';

-- 3) Players registered in a specific season.
create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  jersey_number integer not null,
  first_name text not null,
  last_name text not null,
  position text,
  jersey_size text,
  uniform_gender text,
  phone text,
  emergency_contact text,
  age integer,
  photo_path text,
  photo_thumb_path text,
  photo_url text,
  photo_thumb_url text,
  height_cm integer,
  weight_kg numeric,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  constraint players_jersey_unique unique (season_id, jersey_number),
  constraint players_age_check check (age is null or (age >= 3 and age <= 80)),
  constraint players_jersey_size_check check (
    jersey_size is null or jersey_size in ('XS','S','M','L','XL','2XL','3XL','2','4','6','8','10','12','14','16')
  ),
  constraint players_uniform_gender_check check (
    uniform_gender is null or uniform_gender in ('H','M','Niña','Niño')
  ),
  constraint players_height_check check (height_cm is null or height_cm > 0),
  constraint players_weight_check check (weight_kg is null or weight_kg > 0)
);
comment on table public.players is 'Jugadores registrados por temporada, con datos basicos y fisicos.';

-- 4) Physical/performance metrics by player and date.
create table if not exists public.player_metrics (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players (id) on delete cascade,
  measured_on date not null,
  forty_yd_seconds numeric,
  ten_yd_split numeric,
  shuttle_5_10_5 numeric,
  vertical_jump_cm numeric,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint player_metrics_positive_times_check check (
    (forty_yd_seconds is null or forty_yd_seconds > 0) and
    (ten_yd_split is null or ten_yd_split > 0) and
    (shuttle_5_10_5 is null or shuttle_5_10_5 > 0) and
    (vertical_jump_cm is null or vertical_jump_cm > 0)
  )
);
comment on table public.player_metrics is 'Mediciones fisicas y de rendimiento historicas por jugador.';

-- 5) Extra lines for uniform orders (porra/familia/novia/staff).
create table if not exists public.uniform_order_extras (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  name text not null,
  quantity integer not null default 1,
  jersey_number integer,
  jersey_size text,
  uniform_gender text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint uniform_order_extras_quantity_check check (quantity > 0),
  constraint uniform_order_extras_jersey_size_check check (
    jersey_size is null or jersey_size in ('XS','S','M','L','XL','2XL','3XL','2','4','6','8','10','12','14','16')
  ),
  constraint uniform_order_extras_uniform_gender_check check (
    uniform_gender is null or uniform_gender in ('H','M','Niña','Niño')
  )
);
comment on table public.uniform_order_extras is
  'Lineas extra de pedido de uniformes sin crear jugadores (porra, novia, familiar, staff).';

-- 6) Payment concept catalog (Semana, Uniforme, Inscripcion, etc.).
create table if not exists public.payment_concepts (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);
comment on table public.payment_concepts is 'Catalogo de conceptos de cobro.';

-- 7) Key/value app settings used by configurable business logic.
create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
comment on table public.app_settings is 'Configuraciones globales de la app por llave/valor.';

-- 8) Payments made by players for a season and concept.
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  concept_id uuid not null references public.payment_concepts (id),
  week_start date,
  week_end date,
  amount numeric not null,
  status text not null check (status in ('paid', 'partial', 'pending')),
  paid_amount numeric not null default 0,
  payment_method text,
  reference text,
  paid_at timestamptz not null default timezone('utc', now()),
  notes text,
  receipt_url text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint payments_week_pair_check check (
    (week_start is null and week_end is null) or
    (week_start is not null and week_end is not null and week_end >= week_start)
  ),
  constraint payments_amounts_check check (
    amount >= 0 and paid_amount >= 0 and paid_amount <= amount
  )
);
comment on table public.payments is 'Pagos por jugador/temporada/concepto, incluyendo estatus y evidencia.';

-- 9) Scheduled or played games.
create table if not exists public.games (
  id uuid primary key default gen_random_uuid(),
  season_id uuid references public.seasons (id) on delete cascade,
  roster_season_id uuid references public.seasons (id) on delete set null,
  opponent text not null,
  game_date date not null,
  game_type text not null default 'torneo'
    check (game_type in ('torneo', 'amistoso', 'interno')),
  location text,
  is_tournament boolean not null default false,
  our_score integer not null default 0,
  opp_score integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  constraint games_scores_check check (our_score >= 0 and opp_score >= 0),
  constraint games_season_by_type_check check (
    (game_type = 'torneo' and season_id is not null) or
    (game_type in ('amistoso', 'interno') and season_id is null)
  )
);
comment on table public.games is 'Partidos de la temporada con rival, fecha, sede y marcador.';

-- 10) Quarterback game stats.
create table if not exists public.game_stats_qb (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  completions integer not null default 0,
  incompletions integer not null default 0,
  pass_tds integer not null default 0,
  interceptions integer not null default 0,
  rush_tds integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  constraint game_stats_qb_unique unique (game_id, player_id),
  constraint game_stats_qb_nonnegative_check check (
    completions >= 0 and incompletions >= 0 and pass_tds >= 0 and interceptions >= 0 and rush_tds >= 0
  )
);
comment on table public.game_stats_qb is 'Estadisticas ofensivas de mariscal de campo por juego.';

-- 11) Skill-position game stats (receivers/runners).
create table if not exists public.game_stats_skill (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  receptions integer not null default 0,
  targets integer not null default 0,
  rec_yards integer not null default 0,
  rec_tds integer not null default 0,
  drops integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  constraint game_stats_skill_unique unique (game_id, player_id),
  constraint game_stats_skill_nonnegative_check check (
    receptions >= 0 and targets >= 0 and rec_yards >= 0 and rec_tds >= 0 and drops >= 0
  )
);
comment on table public.game_stats_skill is 'Estadisticas por juego para posiciones de habilidad (recepcion/carrera).';

-- 12) Defensive game stats.
create table if not exists public.game_stats_def (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games (id) on delete cascade,
  player_id uuid not null references public.players (id) on delete cascade,
  tackles integer not null default 0,
  sacks integer not null default 0,
  interceptions integer not null default 0,
  pick6 integer not null default 0,
  flags integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  constraint game_stats_def_unique unique (game_id, player_id),
  constraint game_stats_def_nonnegative_check check (
    tackles >= 0 and sacks >= 0 and interceptions >= 0 and pick6 >= 0 and flags >= 0
  )
);
comment on table public.game_stats_def is 'Estadisticas defensivas por juego.';

-- 13) Play-by-play performance events per game and player.
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
comment on table public.game_events is 'Eventos por jugada para rendimiento por juego (tiempo y lado).';

-- 14) Playbook captures with offense/defense details by half.
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
comment on table public.game_plays is 'Captura jugada-por-jugada por tiempo y unidad (ofensiva/defensiva).';

-- 15) Monthly player award per season.
create table if not exists public.awards_player_month (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete cascade,
  month date not null,
  player_id uuid not null references public.players (id) on delete cascade,
  reason text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint awards_player_month_unique unique (season_id, month),
  constraint awards_player_month_first_day_check check (
    month = date_trunc('month', month)::date
  )
);
comment on table public.awards_player_month is 'Reconocimiento mensual (un jugador por mes y temporada).';

-- Useful indexes (season_id, player_id, game_id and related foreign keys).
create index if not exists idx_players_season_id on public.players (season_id);
create index if not exists idx_player_metrics_player_id on public.player_metrics (player_id);
create index if not exists idx_uniform_order_extras_season_id on public.uniform_order_extras (season_id);
create index if not exists idx_payments_season_id on public.payments (season_id);
create index if not exists idx_payments_player_id on public.payments (player_id);
create index if not exists idx_payments_concept_id on public.payments (concept_id);
create index if not exists idx_games_season_id on public.games (season_id);
create index if not exists idx_game_stats_qb_game_id on public.game_stats_qb (game_id);
create index if not exists idx_game_stats_qb_player_id on public.game_stats_qb (player_id);
create index if not exists idx_game_stats_skill_game_id on public.game_stats_skill (game_id);
create index if not exists idx_game_stats_skill_player_id on public.game_stats_skill (player_id);
create index if not exists idx_game_stats_def_game_id on public.game_stats_def (game_id);
create index if not exists idx_game_stats_def_player_id on public.game_stats_def (player_id);
create index if not exists idx_game_events_game_id on public.game_events (game_id);
create index if not exists idx_game_events_player_id on public.game_events (player_id);
create index if not exists idx_game_events_period_side on public.game_events (period, side);
create index if not exists idx_game_plays_game_id on public.game_plays (game_id);
create index if not exists idx_game_plays_half_unit on public.game_plays (half, unit);
create index if not exists idx_game_plays_qb_player_id on public.game_plays (qb_player_id);
create index if not exists idx_game_plays_receiver_player_id on public.game_plays (receiver_player_id);
create index if not exists idx_game_plays_defender_player_id on public.game_plays (defender_player_id);
create index if not exists idx_awards_player_month_season_id on public.awards_player_month (season_id);
create index if not exists idx_awards_player_month_player_id on public.awards_player_month (player_id);

-- Enforce weekly range requirement when payment concept is "Semana".
-- A CHECK constraint cannot reference another table; this trigger handles that validation.
create or replace function public.validate_weekly_payment_dates()
returns trigger
language plpgsql
as $$
declare
  concept_name text;
begin
  select pc.name into concept_name
  from public.payment_concepts pc
  where pc.id = new.concept_id;

  if concept_name = 'Semana' then
    if new.week_start is null or new.week_end is null then
      raise exception 'week_start and week_end are required when concept is Semana';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_weekly_payment_dates on public.payments;
create trigger trg_validate_weekly_payment_dates
before insert or update on public.payments
for each row execute function public.validate_weekly_payment_dates();

-- Set exactly one active season at a time.
create or replace function public.set_active_season(p_season_id uuid)
returns void
language plpgsql
as $$
begin
  update public.seasons set is_active = false where is_active = true;
  update public.seasons set is_active = true where id = p_season_id;

  if not found then
    raise exception 'Season not found for id %', p_season_id;
  end if;
end;
$$;
