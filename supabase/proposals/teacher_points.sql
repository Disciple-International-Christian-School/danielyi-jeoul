-- Rehearse with BEGIN/ROLLBACK. Promote to the migration ledger at rollout.
create table private.teacher_point_requests (
  id uuid primary key,
  actor uuid not null,
  staff_id uuid not null,
  staff_name text not null,
  core_student_id uuid not null references core.students(id),
  student_name text not null,
  kind public.point_type not null,
  reason text not null check (length(reason) between 1 and 80),
  points integer not null check (points between 1 and 5),
  entered_at timestamptz not null,
  scheduled_on date not null,
  posted_at timestamptz,
  cancelled_at timestamptz,
  point_id integer unique references public.point_records(id),
  failed_at timestamptz,
  failure_code text
);
alter table private.teacher_point_requests enable row level security;
revoke all on private.teacher_point_requests from public, anon, authenticated;
create index teacher_points_due on private.teacher_point_requests(scheduled_on,entered_at)
where posted_at is null and cancelled_at is null;
create index teacher_points_owner on private.teacher_point_requests(actor,entered_at desc);

create function public.teacher_point_students()
returns table(id uuid, name text, homeroom text)
language sql stable security definer set search_path='' as $$
  select s.core_student_id,s.name::text,s.homeroom::text from public.v_discipline_students s
  where (select private.current_homeroom_staff()) is not null order by s.grade,s.homeroom,s.name
$$;

create function public.submit_teacher_point(p_id uuid,p_student uuid,p_kind public.point_type,p_reason text,p_points integer)
returns void language plpgsql security definer set search_path='' as $$
declare
  staff uuid := private.current_homeroom_staff();
  entry_time timestamptz;
  existing private.teacher_point_requests%rowtype;
begin
  if staff is null then raise exception '등록된 교사 계정이 필요합니다.' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
  select * into existing from private.teacher_point_requests where id=p_id;
  if found then
    if (existing.actor,existing.core_student_id,existing.kind,existing.reason,existing.points)
      is distinct from (auth.uid(),p_student,p_kind,btrim(p_reason),p_points) then
      raise exception '요청 정보가 일치하지 않습니다.';
    end if;
    return;
  end if;
  lock table discipline.seondo_holidays in share mode;
  entry_time := clock_timestamp();
  insert into private.teacher_point_requests
    (id,actor,staff_id,staff_name,core_student_id,student_name,kind,reason,points,entered_at,scheduled_on)
  select p_id,auth.uid(),a.id,a.display_name,s.core_student_id,s.name,p_kind,btrim(p_reason),p_points,entry_time,
    private.seondo_following_school_day((entry_time at time zone 'Asia/Seoul')::date,1)
  from public.v_discipline_students s cross join core.staff_accounts a
  where s.core_student_id=p_student and a.id=staff;
  if not found then raise exception '재학생을 선택하세요.'; end if;
end $$;

create function public.cancel_teacher_point(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare r private.teacher_point_requests%rowtype; cancelled timestamptz;
begin
  select * into r from private.teacher_point_requests
  where id=p_id and actor=auth.uid() and staff_id=private.current_homeroom_staff() for update;
  cancelled := clock_timestamp();
  if not found or r.posted_at is not null or
    (r.entered_at at time zone 'Asia/Seoul')::date <> (cancelled at time zone 'Asia/Seoul')::date then
    raise exception '당일 본인이 입력한 대기 기록만 취소할 수 있습니다.';
  end if;
  update private.teacher_point_requests set cancelled_at=cancelled where id=p_id and cancelled_at is null;
end $$;

create function private.reschedule_teacher_points() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  update private.teacher_point_requests set scheduled_on=private.seondo_following_school_day((entered_at at time zone 'Asia/Seoul')::date,1)
  where posted_at is null and cancelled_at is null;
  return null;
end $$;
create trigger teacher_points_calendar after insert or update or delete or truncate on discipline.seondo_holidays
for each statement execute function private.reschedule_teacher_points();

create function private.post_teacher_points() returns void
language plpgsql security definer set search_path='' as $$
declare r private.teacher_point_requests%rowtype; posted timestamptz; ledger_id integer;
begin
  lock table discipline.seondo_holidays in share mode;
  for r in select * from private.teacher_point_requests
    where scheduled_on <= (clock_timestamp() at time zone 'Asia/Seoul')::date
      and posted_at is null and cancelled_at is null and (failed_at is null or failed_at < now()-interval '5 minutes')
    order by entered_at,id for update skip locked
  loop
    begin
      posted := clock_timestamp();
      insert into public.point_records(core_student_id,type,item,points,entered_by_name,recorded_at,created_at,source_type,source_key)
      values(r.core_student_id,r.kind,r.reason,r.points,left(r.staff_name,40),(posted at time zone 'Asia/Seoul')::date,posted,
        'SYSTEM','teacher-point:'||r.id) returning id into ledger_id;
      update private.teacher_point_requests set point_id=ledger_id,posted_at=posted,failed_at=null,failure_code=null where id=r.id;
    exception when others then
      update private.teacher_point_requests set failed_at=clock_timestamp(),failure_code=sqlstate where id=r.id;
    end;
  end loop;
end $$;

create function public.teacher_point_history(p_team boolean default false,p_week date default null)
returns table(id uuid,teacher text,student text,kind public.point_type,reason text,points integer,
  entered_at timestamptz,scheduled_on date,posted_at timestamptz,cancelled_at timestamptz,state text,in_week boolean,next_school_day boolean)
language plpgsql stable security definer set search_path='' as $$
declare week_start date:=date_trunc('week',coalesce(p_week,private.kst_today())::timestamp)::date;
begin
  if p_team then
    if private.current_admin_role() is distinct from 'SEONDO' then raise exception '선도부 권한이 필요합니다.' using errcode='42501'; end if;
  elsif private.current_homeroom_staff() is null then raise exception '등록된 교사 계정이 필요합니다.' using errcode='42501';
  end if;
  return query select r.id,r.staff_name,r.student_name,r.kind,r.reason,r.points,r.entered_at,r.scheduled_on,r.posted_at,r.cancelled_at,
    case when r.cancelled_at is not null then '취소' when r.posted_at is not null then '반영 완료'
    when r.failed_at is not null then '반영 실패' else '반영 대기' end,
    (r.entered_at at time zone 'Asia/Seoul')::date between week_start and week_start+6,
    r.scheduled_on=private.seondo_following_school_day(coalesce(p_week,private.kst_today()),1)
  from private.teacher_point_requests r
  where (p_team or (r.actor=auth.uid() and r.staff_id=private.current_homeroom_staff()))
    and (not p_team or ((r.entered_at at time zone 'Asia/Seoul')::date >= week_start and
      (r.entered_at at time zone 'Asia/Seoul')::date < week_start+7) or
      r.scheduled_on=private.seondo_following_school_day(coalesce(p_week,private.kst_today()),1))
  order by r.entered_at desc,r.id;
end $$;

revoke all on function private.post_teacher_points(),private.reschedule_teacher_points() from public,anon,authenticated;
revoke all on function public.teacher_point_students(),public.submit_teacher_point(uuid,uuid,public.point_type,text,integer),
  public.cancel_teacher_point(uuid),public.teacher_point_history(boolean,date) from public,anon;
grant execute on function public.teacher_point_students(),public.submit_teacher_point(uuid,uuid,public.point_type,text,integer),
  public.cancel_teacher_point(uuid),public.teacher_point_history(boolean,date) to authenticated;
select cron.schedule('teacher-point-posting','* * * * *','select private.post_teacher_points()');
