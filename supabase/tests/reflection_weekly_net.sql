-- Authorized connection required. All test records are rolled back.
begin;
select set_config('request.jwt.claim.sub',(select user_id::text from public.admins where is_active and is_lead and role='SEONDO' order by id limit 1),true);
set local role authenticated;
do $test$
declare
  st uuid; wk date := private.kst_week_start();
  a int; b int; c int; d int; e int;
begin
  select ds.core_student_id into st from public.v_discipline_students ds
   where ds.grade=7 and not exists (
     select 1 from public.point_records pr where pr.core_student_id=ds.core_student_id
       and pr.deleted_at is null and pr.superseded_by_import_id is null
   ) limit 1;
  if st is null then raise exception 'Need a student without live events for rollback test'; end if;
  a:=public.create_point_record_once(st,'POSITIVE','반성문NET 검증',10,wk,gen_random_uuid(),false);
  b:=public.create_point_record_once(st,'NEGATIVE','반성문NET 검증',5,wk,gen_random_uuid(),false);
  if exists(select 1 from public.v_reflections where point_record_id=b) then
    raise exception 'NET +5 must not produce an eligible reflection';
  end if;
  c:=public.create_point_record_once(st,'NEGATIVE','반성문NET 검증',6,wk,gen_random_uuid(),false);
  if exists(select 1 from public.v_reflections where point_record_id=b) then
    raise exception 'Covered first penalty became retroactively due';
  end if;
  if not exists(select 1 from public.v_reflections where point_record_id=c) then
    raise exception 'NET -1 threshold crossing did not make reflection eligible';
  end if;
  if not exists(select 1 from public.v_daily_discipline_notice where point_record_id=b and reflection_id is null) then
    raise exception 'Daily notice incorrectly shows covered penalty reflection';
  end if;
  if not exists(select 1 from public.v_point_records where id=b and reflection_id is null) then
    raise exception 'Point history incorrectly shows covered penalty reflection';
  end if;
  if not exists(select 1 from public.v_student_summary where core_student_id=st
       and ('반성문 미제출'=any(statuses) or '반성문 2배 제출 대상'=any(statuses))) then
    raise exception 'Student status did not show eligible reflection';
  end if;
  d:=public.create_point_record_once(st,'POSITIVE','반성문NET 검증',1,wk,gen_random_uuid(),false);
  if exists(select 1 from public.v_reflections where point_record_id in (b,c)) then
    raise exception 'NET zero still shows reflections';
  end if;
  if exists(select 1 from public.v_student_summary where core_student_id=st
       and ('반성문 미제출'=any(statuses) or '반성문 2배 제출 대상'=any(statuses))) then
    raise exception 'NET zero left stale student reflection status';
  end if;
  e:=public.create_point_record_once(st,'NEGATIVE','반성문NET 검증',1,wk,gen_random_uuid(),false);
  if not exists(select 1 from public.v_reflections where point_record_id=e) then
    raise exception 'Re-entering NET -1 must reactivate eligibility for the new penalty';
  end if;
  if exists(select 1 from public.v_reflections where point_record_id=b) then
    raise exception 'Old covered penalty became eligible after a later threshold crossing';
  end if;
end $test$;
reset role;
select 'reflection NET thresholds, score offset, prior covered events, dashboard status, daily notice passed' as result;
rollback;
