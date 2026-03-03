-- Seed data for Borregos Gestion (Supabase/Postgres)
-- Run this after schema.sql and rls.sql

-- Payment concepts
insert into public.payment_concepts (name, is_active)
values
  ('Semana', true),
  ('Inscripción', true),
  ('Uniforme', true),
  ('Viaje', true),
  ('Multa', true),
  ('Otro', true)
on conflict (name) do update
set is_active = excluded.is_active;

-- Example season
insert into public.seasons (name, starts_on, ends_on, is_active)
select '2026 Progreso', date '2026-01-01', date '2026-12-31', true
where not exists (
  select 1
  from public.seasons s
  where s.name = '2026 Progreso'
);

-- IMPORTANT:
-- Do NOT insert users into auth.users manually here.
-- Create users first from Supabase Auth UI.
-- Then insert their profile rows with the same UUID from auth.users.id.
--
-- Example (run manually after creating users):
-- insert into public.profiles (id, full_name, role)
-- values
--   ('<uuid-super-admin>', 'Nombre Admin', 'super_admin'),
--   ('<uuid-coach>', 'Nombre Coach', 'coach'),
--   ('<uuid-viewer>', 'Nombre Viewer', 'viewer');
