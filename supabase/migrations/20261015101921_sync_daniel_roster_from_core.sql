create or replace function private.sync_daniel_student_bridge(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, core, public, private
as $$
declare
  v_name text;
  v_grade integer;
begin
  select s.name, c.grade
    into v_name, v_grade
  from core.students s
  join core.enrollments e
    on e.student_id = s.id
   and e.left_at is null
  join core.academic_terms t
    on t.id = e.term_id
   and t.is_current
  join core.classes c
    on c.id = e.class_id
  where s.id = p_student_id
    and s.is_active
  order by e.enrolled_at desc
  limit 1;

  if found then
    insert into public.students (name, grade, core_student_id, deleted_at)
    values (v_name, v_grade, p_student_id, null)
    on conflict (core_student_id) where core_student_id is not null
    do update
       set name = excluded.name,
           grade = excluded.grade,
           deleted_at = null,
           updated_at = now();
  else
    update public.students
       set deleted_at = coalesce(deleted_at, now()),
           updated_at = now()
     where core_student_id = p_student_id
       and deleted_at is null;
  end if;
end;
$$;

revoke all on function private.sync_daniel_student_bridge(uuid) from public, anon, authenticated;

create or replace function private.sync_daniel_student_from_core_trigger()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, core, public, private
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.students where core_student_id = old.id;
    return old;
  end if;

  perform private.sync_daniel_student_bridge(new.id);
  return new;
end;
$$;

revoke all on function private.sync_daniel_student_from_core_trigger() from public, anon, authenticated;

drop trigger if exists sync_daniel_student_from_core on core.students;
create trigger sync_daniel_student_from_core
after insert or update of name, is_active
on core.students
for each row
execute function private.sync_daniel_student_from_core_trigger();

drop trigger if exists delete_daniel_student_bridge_before_core_delete on core.students;
create trigger delete_daniel_student_bridge_before_core_delete
before delete
on core.students
for each row
execute function private.sync_daniel_student_from_core_trigger();

create or replace function private.sync_daniel_student_from_enrollment_trigger()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, core, public, private
as $$
begin
  if tg_op = 'DELETE' then
    perform private.sync_daniel_student_bridge(old.student_id);
    return old;
  end if;

  perform private.sync_daniel_student_bridge(new.student_id);

  if tg_op = 'UPDATE' and old.student_id is distinct from new.student_id then
    perform private.sync_daniel_student_bridge(old.student_id);
  end if;

  return new;
end;
$$;

revoke all on function private.sync_daniel_student_from_enrollment_trigger() from public, anon, authenticated;

drop trigger if exists sync_daniel_student_from_enrollment on core.enrollments;
create trigger sync_daniel_student_from_enrollment
after insert or update of student_id, term_id, class_id, left_at or delete
on core.enrollments
for each row
execute function private.sync_daniel_student_from_enrollment_trigger();

create or replace function private.sync_all_daniel_students_from_term_trigger()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, core, public, private
as $$
declare
  v_student_id uuid;
begin
  if tg_op = 'INSERT'
     or old.is_current is distinct from new.is_current then
    for v_student_id in select id from core.students loop
      perform private.sync_daniel_student_bridge(v_student_id);
    end loop;
  end if;
  return new;
end;
$$;

revoke all on function private.sync_all_daniel_students_from_term_trigger() from public, anon, authenticated;

drop trigger if exists sync_all_daniel_students_from_current_term on core.academic_terms;
create trigger sync_all_daniel_students_from_current_term
after insert or update of is_current
on core.academic_terms
for each row
execute function private.sync_all_daniel_students_from_term_trigger();

select private.sync_daniel_student_bridge(id)
from core.students;

comment on function private.sync_daniel_student_bridge(uuid) is
  'Keeps the Daniel legacy roster bridge synchronized with active Core students in the current academic term.';
