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

create index if not exists idx_uniform_order_extras_season_id
  on public.uniform_order_extras (season_id);
