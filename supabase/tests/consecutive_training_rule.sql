-- Authorized connection required. Every test event is rolled back.
begin;

select set_config('request.jwt.claim.sub',(select user_id::text from public.admins where is_active and is_lead and role='SEONDO' order by id limit 1),true);
set local role authenticated;
do $test$
declare st uuid; wk date:=private.kst_week_start(); ids int[]:='{}'; n int; p int; i int; v boolean; streak int;
begin
 select ds.core_student_id into st from public.v_discipline_students ds where ds.grade=7
 and not exists(select 1 from public.point_records pr where pr.core_student_id=ds.core_student_id and pr.deleted_at is null and pr.superseded_by_import_id is null) limit 1;
 if st is null then raise exception 'Need a student without live events for rollback test';end if;
 for i in 0..2 loop
 n:=public.create_point_record_once(st,'NEGATIVE','규칙 검증 - 롤백',8,wk-i*7,gen_random_uuid(),false);
 ids:=array_append(ids,n);
 end loop;
 select committee_required,physical_training_weeks into v,streak from public.v_settlement_scores_core_shadow where core_student_id=st and is_open;
 if v is distinct from true or streak<>3 then raise exception 'Three consecutive weeks must qualify';end if;
 -- Remove the middle week; high current-period points alone must not qualify.
 update public.point_records set deleted_at=now() where id=ids[2];
 n:=public.create_point_record_once(st,'NEGATIVE','규칙 검증 - 롤백',20,wk,gen_random_uuid(),false);
 ids:=array_append(ids,n);
 select committee_required,physical_training_weeks into v,streak from public.v_settlement_scores_core_shadow where core_student_id=st and is_open;
 if v is distinct from false or streak<>1 then raise exception 'Gap or cumulative 20 incorrectly qualifies';end if;
 update public.point_records set deleted_at=now() where id=any(ids);
 ids:='{}';
 -- Three low-point reasons qualify even when merits make NET positive.
 for i in 1..3 loop
 n:=public.create_point_record_once(st,'NEGATIVE','규칙 검증 - 롤백',1,wk,gen_random_uuid(),false);
 ids:=array_append(ids,n);
 end loop;
 p:=public.create_point_record_once(st,'POSITIVE','규칙 검증 - 롤백',50,wk,gen_random_uuid(),false);
 select physical_training_required into v from public.v_weekly_scores_core_shadow where core_student_id=st and week_start=wk;
 if v is distinct from true then raise exception 'Three occurrences must qualify despite positive NET';end if;
 update public.point_records set deleted_at=now() where id=ids[3];
 select physical_training_required into v from public.v_weekly_scores_core_shadow where core_student_id=st and week_start=wk;
 if v is distinct from false then raise exception 'Two occurrences with positive NET must not qualify';end if;
 update public.point_records set deleted_at=now() where id=any(ids) or id=p;
 n:=public.create_point_record_once(st,'NEGATIVE','규칙 검증 - 롤백',8,wk,gen_random_uuid(),false);
 p:=public.create_point_record_once(st,'POSITIVE','규칙 검증 - 롤백',1,wk,gen_random_uuid(),false);
 select physical_training_required into v from public.v_weekly_scores_core_shadow where core_student_id=st and week_start=wk;
 if v is distinct from false then raise exception 'NET -7 must not qualify';end if;
 update public.point_records set deleted_at=now() where id=p;
 select physical_training_required into v from public.v_weekly_scores_core_shadow where core_student_id=st and week_start=wk;
 if v is distinct from true then raise exception 'NET -8 must qualify';end if;
end $test$;
reset role;
select 'training -8/3 occurrences, merit offset, consecutive weeks, gap and removed 20-point threshold passed' result;

rollback;
