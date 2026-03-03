alter table if exists public.players
  add column if not exists photo_thumb_url text;

notify pgrst, 'reload schema';
