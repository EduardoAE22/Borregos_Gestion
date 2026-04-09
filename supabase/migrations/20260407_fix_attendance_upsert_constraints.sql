-- Fix legacy attendance tables that may exist without the unique constraints
-- required by Flutter upserts in feature/asistencia-cobro.

-- Keep the most recent training session per season/day before enforcing
-- the unique key used by AttendanceRepo.ensureTrainingSession().
with ranked_training_sessions as (
  select
    id,
    row_number() over (
      partition by season_id, session_date
      order by created_at desc, id desc
    ) as rn
  from public.training_sessions
)
delete from public.training_sessions ts
using ranked_training_sessions ranked
where ts.id = ranked.id
  and ranked.rn > 1;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'training_sessions_unique'
      and conrelid = 'public.training_sessions'::regclass
  ) then
    alter table public.training_sessions
      add constraint training_sessions_unique
      unique (season_id, session_date);
  end if;
end $$;

-- Keep the most recent attendance row per player/day before enforcing
-- the unique key used by AttendanceRepo.upsertAttendance().
with ranked_player_attendance as (
  select
    id,
    row_number() over (
      partition by player_id, attended_on
      order by created_at desc, id desc
    ) as rn
  from public.player_attendance
)
delete from public.player_attendance pa
using ranked_player_attendance ranked
where pa.id = ranked.id
  and ranked.rn > 1;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'player_attendance_player_day_unique'
      and conrelid = 'public.player_attendance'::regclass
  ) then
    alter table public.player_attendance
      add constraint player_attendance_player_day_unique
      unique (player_id, attended_on);
  end if;
end $$;
