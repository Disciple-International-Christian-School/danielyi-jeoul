-- 2026-09-25
-- Production hardening after DICS Core foundation rollout.

-- Security advisor: pin trigger search_path.
create or replace function private.create_reflection_for_penalty()
returns trigger
language plpgsql
set search_path = ''
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

-- Performance advisor: cover FK access paths.
create index if not exists core_enrollments_term_idx
  on core.enrollments (term_id);

create index if not exists core_enrollments_class_term_idx
  on core.enrollments (class_id, term_id);

create index if not exists reflection_records_deadline_changed_by_idx
  on public.reflection_records (deadline_changed_by)
  where deadline_changed_by is not null;

create index if not exists settlement_periods_created_by_idx
  on public.settlement_periods (created_by)
  where created_by is not null;

create index if not exists settlement_periods_closed_by_idx
  on public.settlement_periods (closed_by)
  where closed_by is not null;
