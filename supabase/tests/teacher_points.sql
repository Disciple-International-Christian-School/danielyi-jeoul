-- Disposable database only. Use the fixture and workflow order from CI.
begin;
do $$
declare
  teacher uuid:=gen_random_uuid();
  other_teacher uuid:=gen_random_uuid();
  student uuid:=gen_random_uuid();
  kept uuid:=gen_random_uuid();
  cancelled uuid:=gen_random_uuid();
  start_on date;
  later date;
  denied boolean;
begin
  insert into core.students values(student);
  insert into public.students values(1,student,5,'Fixture student','G5');
  insert into core.staff_accounts values(teacher,'Fixture teacher',true),(other_teacher,'Fixture teacher',true);
  perform set_config('request.jwt.claim.sub',teacher::text,true);
  assert (select count(*)=1 from public.teacher_point_students());
  perform public.submit_teacher_point(kept,student,'NEGATIVE','Example',5);
  perform public.submit_teacher_point(kept,student,'NEGATIVE','Example',5);
  perform public.submit_teacher_point(cancelled,student,'POSITIVE','Cancelled',4);
  assert (select count(*)=2 from public.teacher_point_history());
  assert not exists(select from public.point_records);
  begin
    perform public.submit_teacher_point(gen_random_uuid(),student,'NEGATIVE','Invalid',6);
    raise exception 'Accepted an excessive score';
  exception when check_violation then null; end;
  perform set_config('request.jwt.claim.sub',other_teacher::text,true);
  assert not exists(select from public.teacher_point_history());
  denied:=false;
  begin perform public.cancel_teacher_point(kept); exception when raise_exception then denied:=true; end;
  assert denied;
  perform set_config('request.jwt.claim.sub',teacher::text,true);
  perform public.cancel_teacher_point(cancelled);
  begin
    perform public.teacher_point_history(true,null);
    raise exception 'Team history was visible';
  exception when insufficient_privilege then null; end;
  select scheduled_on into start_on from private.teacher_point_requests where id=kept;
  insert into discipline.seondo_holidays values(start_on,'Test closure');
  select scheduled_on into later from private.teacher_point_requests where id=kept;
  assert later>start_on;
  assert (select scheduled_on=start_on from private.teacher_point_requests where id=cancelled);
  delete from discipline.seondo_holidays where day=start_on;
  assert (select scheduled_on=start_on from private.teacher_point_requests where id=kept);
  -- Simulate a missed run spanning a week boundary.
  update private.teacher_point_requests set entered_at=now()-interval '9 days',scheduled_on=private.kst_today()-6 where id=kept;
  denied:=false;
  begin perform public.cancel_teacher_point(kept); exception when raise_exception then denied:=true; end;
  assert denied;
  delete from core.staff_accounts where id=teacher;
  -- A transient ledger failure must not finalize the request.
  alter table public.point_records add constraint fixture_no_posts check (false);
  perform private.post_teacher_points();
  assert (select failed_at is not null and posted_at is null from private.teacher_point_requests where id=kept);
  alter table public.point_records drop constraint fixture_no_posts;
  update private.teacher_point_requests set failed_at=now()-interval '6 minutes' where id=kept;
  perform private.post_teacher_points();
  perform private.post_teacher_points();
  assert (select count(*)=1 from public.point_records);
  assert (select points=5 and recorded_at=private.kst_today() and source_key='teacher-point:'||kept from public.point_records);
  assert (select posted_at is not null and point_id is not null and staff_name='Fixture teacher' from private.teacher_point_requests where id=kept);
  assert (select posted_at is null and cancelled_at is not null from private.teacher_point_requests where id=cancelled);
  perform set_config('test.role','lead',true);
  assert exists(select from public.teacher_point_history(true,private.kst_today()-9) where id=kept and in_week);
  assert not has_function_privilege('authenticated','private.post_teacher_points()','execute');
  assert not has_table_privilege('authenticated','private.teacher_point_requests','update');
end $$;
rollback;
