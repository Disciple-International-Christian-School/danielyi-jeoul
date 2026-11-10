-- Keep batch writes atomic and reuse single-record authorization, validation and auditing.
create or replace function public.create_point_record_once(p_core_student_id uuid,p_type public.point_type,p_item text,p_points int,p_recorded_at date,p_request_id uuid,p_reflection_submitted boolean default false)
returns int language plpgsql security invoker set search_path='' as $$
declare v_id int; v_name text; v_old public.point_records%rowtype;
begin
 if auth.uid() is null or private.current_admin_role() is distinct from 'SEONDO' then raise exception '선도부 권한이 필요합니다.'; end if;
 if p_type='NEGATIVE' and exists (
  select 1 from public.v_discipline_students
  where core_student_id=p_core_student_id and grade between 1 and 6
 ) then p_points:=1; end if;
 if p_request_id is null then raise exception '저장 요청 ID가 필요합니다.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':'||p_request_id::text,0));
 select * into v_old from public.point_records where created_by=auth.uid() and request_id=p_request_id;
 if v_old.id is not null then
  if v_old.core_student_id<>p_core_student_id or v_old.type<>p_type or v_old.item<>btrim(p_item) or v_old.points<>p_points or v_old.recorded_at<>p_recorded_at then raise exception '이 요청 ID는 다른 기록에 사용됐습니다.'; end if;
  return v_old.id;
 end if;
 if not exists(select 1 from public.v_discipline_students where core_student_id=p_core_student_id) then raise exception '재학생을 선택하세요.'; end if;
 select display_name into v_name from public.admins where user_id=auth.uid() and is_active limit 1;
 insert into public.point_records(core_student_id,type,item,points,recorded_at,entered_by_name,created_by,request_id)
 values(p_core_student_id,p_type,btrim(p_item),p_points,p_recorded_at,v_name,auth.uid(),p_request_id) returning id into v_id;
 if p_type='NEGATIVE' and p_reflection_submitted then update public.reflection_records set submitted=true,submitted_at=now() where point_record_id=v_id; end if;
 return v_id;
end $$;
revoke all on function public.create_point_record_once(uuid,public.point_type,text,int,date,uuid,boolean) from public,anon;
grant execute on function public.create_point_record_once(uuid,public.point_type,text,int,date,uuid,boolean) to authenticated;

create function public.create_group_penalty_once(
  p_grade int,
  p_homeroom text,
  p_student_ids uuid[],
  p_item text,
  p_points int,
  p_recorded_at date,
  p_request_id uuid
)
returns int
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_scope public.discipline_scope;
  v_roster uuid[];
  v_expected uuid[];
  v_student uuid;
begin
  if auth.uid() is null or private.current_admin_role() is distinct from 'SEONDO' then
    raise exception '선도부 권한이 필요합니다.';
  end if;
  v_scope := private.current_admin_scope();
  if p_grade is null or p_grade not between 1 and 12 or not coalesce(
    v_scope = 'ALL'
    or (v_scope = 'ELEMENTARY' and p_grade between 1 and 6)
    or (v_scope = 'MIDDLE' and p_grade between 7 and 8)
    or (v_scope = 'HIGH' and p_grade between 9 and 12),
    false
  ) then
    raise exception '담당 범위의 학년을 선택하세요.';
  end if;
  if p_request_id is null or cardinality(p_student_ids) is null or cardinality(p_student_ids) = 0 then
    raise exception '대상 학생과 저장 요청 ID가 필요합니다.';
  end if;

  select array_agg(core_student_id order by core_student_id)
  into v_roster
  from public.v_discipline_students
  where grade = p_grade
    and (p_homeroom is null or homeroom = p_homeroom);
  select array_agg(id order by id) into v_expected from unnest(p_student_ids) as ids(id);
  if v_roster is distinct from v_expected then
    raise exception '대상 명부가 바뀌었거나 Core 연결이 누락됐습니다. 새로고침 후 다시 확인해주세요.';
  end if;

  foreach v_student in array v_roster loop
    perform public.create_point_record_once(
      v_student, 'NEGATIVE', p_item, p_points, p_recorded_at,
      md5(p_request_id::text || ':' || v_student::text)::uuid, false
    );
  end loop;
  return cardinality(v_roster);
end;
$$;

revoke all on function public.create_group_penalty_once(int,text,uuid[],text,int,date,uuid) from public,anon;
grant execute on function public.create_group_penalty_once(int,text,uuid[],text,int,date,uuid) to authenticated;

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
    select s.grade
    into v_grade
    from public.students s
    where s.core_student_id = new.core_student_id;

    if v_grade is null then
      raise exception 'Core 학생의 학년 정보를 찾을 수 없습니다.';
    end if;

    if v_grade between 1 and 6 then
      v_deadline_date := new.recorded_at + case extract(isodow from new.recorded_at)::int
        when 5 then 3
        when 6 then 2
        else 1
      end;
      v_due_at := (v_deadline_date + time '08:20') at time zone 'Asia/Seoul';
    else
      v_due_at := (new.recorded_at + time '17:00') at time zone 'Asia/Seoul';
      v_deadline_date := new.recorded_at;
    end if;

    insert into public.reflection_records (
      point_record_id,
      submission_deadline,
      due_at
    )
    values (
      new.id,
      v_deadline_date,
      v_due_at
    )
    on conflict (point_record_id) do nothing;
  end if;

  return new;
end;
$$;

-- The reference workbook owns scores for matching penalty item names.
-- Existing activation choices are preserved. The import never removes items.
create function public.sync_penalty_items_from_sheet(p_items jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_item record;
begin
  if auth.uid() is null or private.current_admin_role() is distinct from 'SEONDO' then
    raise exception '선도부 권한이 필요합니다.';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 1000 then
    raise exception '벌점 항목 목록을 확인해주세요.';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('sync_penalty_items_from_sheet', 0));
  if exists (
    select 1 from jsonb_to_recordset(p_items) as source(name text)
    group by btrim(name) having count(*) > 1
  ) then
    raise exception '시트에 같은 이름의 벌점 항목이 있습니다.';
  end if;

  for v_item in
    select btrim(name) as name, fixed_points
    from jsonb_to_recordset(p_items) as source(name text, fixed_points int)
  loop
    if coalesce(char_length(v_item.name), 0) not between 1 and 80
       or (v_item.fixed_points is not null and v_item.fixed_points not between 1 and 100) then
      raise exception '항목명 또는 점수가 잘못됐습니다.';
    end if;
    update public.point_items
      set fixed_points = v_item.fixed_points, is_fixed = v_item.fixed_points is not null
      where type = 'NEGATIVE' and name = v_item.name;
    if not found then
      insert into public.point_items(name, type, fixed_points, is_fixed, is_active)
      values (v_item.name, 'NEGATIVE', v_item.fixed_points, v_item.fixed_points is not null, true);
    end if;
  end loop;
end;
$$;

revoke all on function public.sync_penalty_items_from_sheet(jsonb) from public,anon;
grant execute on function public.sync_penalty_items_from_sheet(jsonb) to authenticated;
