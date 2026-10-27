-- Run against an authorized database connection. Test records are rolled back.
begin;

select set_config('request.jwt.claim.sub',(select user_id::text from public.admins where is_active and is_lead and role='SEONDO' order by id limit 1),true);
set local role authenticated;
do $test$
declare st uuid; a int; b int; blocked boolean:=false; v jsonb;
begin
 select core_student_id into st from public.v_discipline_students where grade=7 limit 1;
 a:=public.create_point_record_once(st,'POSITIVE','날짜 입력 검증 - 롤백',2,'2026-10-20',gen_random_uuid(),false);
 b:=public.create_point_record_once(st,'NEGATIVE','날짜 입력 검증 - 롤백',3,'2026-10-21',gen_random_uuid(),false);
 if (select recorded_at from public.point_records where id=a)<>'2026-10-20'::date then raise exception 'occurrence date changed'; end if;
 v:=public.get_discipline_history(st,'2026-10-19','2026-10-25');
 if not exists(select 1 from jsonb_array_elements(v->'rows') r where r->>'source'='DAILY' and (r->>'positive_points')::int=2 and (r->>'negative_points')::int=3 and (r->>'net')::int=-1) then raise exception 'past week aggregation mismatch';end if;
 perform public.create_point_record_once(st,'POSITIVE','날짜 입력 검증 - 롤백',1,'2026-08-10',gen_random_uuid(),false);
 begin
 perform public.create_point_record_once(st,'POSITIVE','날짜 입력 검증 - 롤백',1,current_date+2,gen_random_uuid(),false);
 exception when others then if sqlerrm like '%미래 날짜%' then blocked:=true; else raise;end if;end;
 if not blocked then raise exception 'future date allowed';end if;
 blocked:=false;
 begin
 update public.point_records set item=item where id=(select id from public.point_records where superseded_by_import_id is not null limit 1);
 exception when others then if sqlerrm like '%감사용%' then blocked:=true;else raise;end if;end;
 if not blocked then raise exception 'audit original changed';end if;
end $test$;
reset role;
select 'past dates, week totals, future rejection, archive immutability passed' result;

rollback;
