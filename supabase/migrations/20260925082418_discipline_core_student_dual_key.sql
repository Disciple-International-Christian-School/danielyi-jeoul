-- 2026-09-25
-- Discipline canonical student dual-key phase.
--
-- Keep the legacy integer student_id operational for the current frontend,
-- while every discipline record also receives the canonical core.students UUID.
-- A trigger rejects mismatches so the two identities cannot silently diverge.

alter table public.point_records
  add column if not exists core_student_id uuid;

alter table public.punishments
  add column if not exists core_student_id uuid;

update public.point_records pr
set core_student_id = s.core_student_id
from public.students s
where s.id = pr.student_id
  and pr.core_student_id is null;

update public.punishments p
set core_student_id = s.core_student_id
from public.students s
where s.id = p.student_id
  and p.core_student_id is null;

do $$
begin
  if exists (
    select 1
    from public.point_records
    where core_student_id is null
  ) then
    raise exception 'point_records contains rows without canonical Core student mapping.';
  end if;

  if exists (
    select 1
    from public.punishments
    where core_student_id is null
  ) then
    raise exception 'punishments contains rows without canonical Core student mapping.';
  end if;
end $$;

alter table public.point_records
  alter column core_student_id set not null;

alter table public.punishments
  alter column core_student_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.point_records'::regclass
      and conname = 'point_records_core_student_id_fkey'
  ) then
    alter table public.point_records
      add constraint point_records_core_student_id_fkey
      foreign key (core_student_id)
      references core.students(id)
      on delete restrict;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.punishments'::regclass
      and conname = 'punishments_core_student_id_fkey'
  ) then
    alter table public.punishments
      add constraint punishments_core_student_id_fkey
      foreign key (core_student_id)
      references core.students(id)
      on delete restrict;
  end if;
end $$;

create index if not exists point_records_core_student_idx
  on public.point_records (core_student_id, recorded_at desc);

create index if not exists punishments_core_student_idx
  on public.punishments (core_student_id, start_date desc);

create or replace function private.sync_discipline_core_student_id()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_core_student_id uuid;
begin
  select s.core_student_id
  into v_core_student_id
  from public.students s
  where s.id = new.student_id;

  if v_core_student_id is null then
    raise exception 'Legacy student row has no canonical Core student mapping.';
  end if;

  if new.core_student_id is null then
    new.core_student_id := v_core_student_id;
  elsif new.core_student_id <> v_core_student_id then
    raise exception 'Legacy student_id and core_student_id refer to different students.';
  end if;

  return new;
end;
$$;

drop trigger if exists point_records_sync_core_student on public.point_records;
create trigger point_records_sync_core_student
  before insert or update of student_id, core_student_id
  on public.point_records
  for each row execute function private.sync_discipline_core_student_id();

drop trigger if exists punishments_sync_core_student on public.punishments;
create trigger punishments_sync_core_student
  before insert or update of student_id, core_student_id
  on public.punishments
  for each row execute function private.sync_discipline_core_student_id();

-- Append canonical UUID to existing view contracts.
create or replace view public.v_point_records
with (security_invoker = true) as
select
  pr.id,
  pr.student_id,
  s.name as student_name,
  pr.type,
  pr.item,
  pr.points,
  pr.recorded_at,
  pr.entered_by_name,
  pr.created_at,
  r.id as reflection_id,
  r.submitted as reflection_submitted,
  r.submission_deadline as reflection_deadline,
  r.submitted_at as reflection_submitted_at,
  case
    when r.id is null then null::text
    when r.submitted then 'SUBMITTED'
    when r.due_at < now() then 'DOUBLE'
    else 'MISSING'
  end as reflection_status,
  r.due_at as reflection_due_at,
  pr.core_student_id
from public.point_records pr
join public.students s
  on s.id = pr.student_id
left join public.reflection_records r
  on r.point_record_id = pr.id
where pr.deleted_at is null;

create or replace view public.v_punishments
with (security_invoker = true) as
select
  p.id,
  p.student_id,
  s.name as student_name,
  s.grade,
  p.types,
  p.start_date,
  p.end_date,
  p.entered_by_name,
  (p.violated_at is not null) as violated,
  p.created_at,
  p.core_student_id
from public.punishments p
join public.students s
  on s.id = p.student_id;

create or replace view public.v_discipline_core_fk_readiness
with (security_invoker = true) as
select
  (select count(*)::int from public.point_records) as point_records_total,
  (select count(*)::int from public.point_records where core_student_id is not null) as point_records_core_linked,
  (
    select count(*)::int
    from public.point_records pr
    join public.students s on s.id = pr.student_id
    where pr.core_student_id is distinct from s.core_student_id
  ) as point_records_mismatch,
  (select count(*)::int from public.punishments) as punishments_total,
  (select count(*)::int from public.punishments where core_student_id is not null) as punishments_core_linked,
  (
    select count(*)::int
    from public.punishments p
    join public.students s on s.id = p.student_id
    where p.core_student_id is distinct from s.core_student_id
  ) as punishments_mismatch;

comment on view public.v_discipline_core_fk_readiness is
  'Aggregate verification for the discipline legacy-ID to canonical Core UUID transition.';

grant select on public.v_discipline_core_fk_readiness to authenticated;
