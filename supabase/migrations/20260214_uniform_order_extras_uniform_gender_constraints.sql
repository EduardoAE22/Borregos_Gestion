alter table public.uniform_order_extras
  add column if not exists uniform_gender text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'uniform_order_extras'
      and column_name = 'gender'
  ) then
    execute 'update public.uniform_order_extras set uniform_gender = gender where uniform_gender is null and gender is not null';
  end if;
end $$;

alter table public.uniform_order_extras
  drop constraint if exists uniform_order_extras_jersey_size_check;

alter table public.uniform_order_extras
  add constraint uniform_order_extras_jersey_size_check
  check (
    jersey_size is null or jersey_size in ('XS','S','M','L','XL','2XL','3XL','2','4','6','8','10','12','14','16')
  );

alter table public.uniform_order_extras
  drop constraint if exists uniform_order_extras_uniform_gender_check;

alter table public.uniform_order_extras
  add constraint uniform_order_extras_uniform_gender_check
  check (uniform_gender is null or uniform_gender in ('H','M','Niña','Niño'));
