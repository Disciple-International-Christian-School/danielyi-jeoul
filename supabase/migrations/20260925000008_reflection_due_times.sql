-- 2026-09-25
-- Reflection-paper deadlines need a timestamp, not only a date.
-- G7-G12 default: same day 17:00 KST, with discretionary extension to 21:00.
-- G1-G6 default: next morning 08:20 KST.

alter table public.reflection_records
  add column if not exists due_at timestamptz,
  add column if not exists deadline_changed_by uuid references auth.users(id) on delete set null,
  add column if not exists deadline_change_reason text;

update public.reflection_records r
set due_at = case
  when s.grade between 1 and 6
    then ((pr.recorded_at + 1) + time '08:20') at time zone 'Asia/Seoul'
  else (pr.recorded_at + time '17:00') at time zone 'Asia/Seoul'
end
from public.point_records pr
join public.students s on s.id = pr.student_id
where r.point_record_id = pr.id
  and r.due_at is null;

alter table public.reflection_records
  alter column due_at set not null;

comment on column public.reflection_records.due_at is
  'Operational reflection deadline. G7-G12 default same-day 17:00 KST; G1-G6 next morning 08:20 KST.';
comment on column public.reflection_records.deadline_change_reason is
  'Reason for an authorized deadline extension/change.';

create or replace function private.create_reflection_for_penalty()
returns trigger
language plpgsql
as $$
declare
  v_grade int;
  v_due_at timestamptz;
  v_deadline_date date;
begin
  if new.type = 'NEGATIVE' then
    select grade into v_grade
    from public.students
    where id = new.student_id;

    if v_grade between 1 and 6 then
      v_due_at := ((new.recorded_at + 1) + time '08:20') at time zone 'Asia/Seoul';
      v_deadline_date := new.recorded_at + 1;
    else
      v_due_at := (new.recorded_at + time '17:00') at time zone 'Asia/Seoul';
      v_deadline_date := new.recorded_at;
    end if;

    insert into public.reflection_records (point_record_id, submission_deadline, due_at)
    values (new.id, v_deadline_date, v_due_at)
    on conflict (point_record_id) do nothing;
  end if;

  return new;
end;
$$;

create or replace view public.v_reflections
with (security_invoker = true) as
select
  r.id,
  r.point_record_id,
  pr.student_id,
  s.name as student_name,
  s.grade,
  pr.item,
  pr.points,
  pr.recorded_at,
  r.submitted,
  r.submission_deadline,
  r.submitted_at,
  case
    when r.submitted then 'SUBMITTED'
    when r.due_at < now() then 'DOUBLE'
    else 'MISSING'
  end as status,
  r.due_at,
  r.deadline_change_reason
from public.reflection_records r
join public.point_records pr on pr.id = r.point_record_id and pr.deleted_at is null
join public.students s on s.id = pr.student_id;

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
    when r.id is null then null
    when r.submitted then 'SUBMITTED'
    when r.due_at < now() then 'DOUBLE'
    else 'MISSING'
  end as reflection_status,
  r.due_at as reflection_due_at
from public.point_records pr
join public.students s on s.id = pr.student_id
left join public.reflection_records r on r.point_record_id = pr.id
where pr.deleted_at is null;

create or replace function public.extend_reflection_to_21(
  p_reflection_id int,
  p_reason text
)
returns timestamptz
language plpgsql
set search_path = ''
as $$
declare
  v_grade int;
  v_recorded_at date;
  v_submitted boolean;
  v_target timestamptz;
begin
  if private.current_admin_role() <> 'SEONDO' then
    raise exception '선도부 관리자만 반성문 마감을 변경할 수 있습니다.';
  end if;

  select s.grade, pr.recorded_at, r.submitted
  into v_grade, v_recorded_at, v_submitted
  from public.reflection_records r
  join public.point_records pr on pr.id = r.point_record_id
  join public.students s on s.id = pr.student_id
  where r.id = p_reflection_id;

  if v_grade is null then
    raise exception '반성문 기록을 찾을 수 없습니다.';
  end if;

  if v_grade between 1 and 6 then
    raise exception '초등부 반성문은 익일 등교 제출 규칙을 사용합니다.';
  end if;

  if v_submitted then
    raise exception '이미 제출된 반성문입니다.';
  end if;

  v_target := (v_recorded_at + time '21:00') at time zone 'Asia/Seoul';

  update public.reflection_records
  set due_at = v_target,
      deadline_changed_by = auth.uid(),
      deadline_change_reason = nullif(btrim(p_reason), '')
  where id = p_reflection_id;

  return v_target;
end;
$$;

grant execute on function public.extend_reflection_to_21(int, text) to authenticated;
