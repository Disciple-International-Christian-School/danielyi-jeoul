-- Authorized connection required; fixture membership changes are rolled back.
begin;

select set_config('request.jwt.claim.sub',(select user_id::text from public.admins where is_active and is_lead and role='SEONDO' order by id limit 1),true);
set local role authenticated;
do $test$
declare dep uuid; st uuid; mid uuid; mid2 uuid; n_before int; end_date date;
begin
 select id into dep from core.departments where is_active order by code limit 1;
 select ds.core_student_id into st from public.v_discipline_students ds
 where not exists(select 1 from core.department_memberships m where m.department_id=dep and m.student_id=ds.core_student_id) limit 1;
 select count(*) into n_before from public.v_department_current_members;
 mid:=public.set_department_student_membership(dep,st,true,private.kst_today());
 if not exists(select 1 from public.v_department_current_members where membership_id=mid) then raise exception 'New member not visible';end if;
 perform public.set_department_student_membership(dep,st,false,private.kst_today());
 if exists(select 1 from public.v_department_current_members where membership_id=mid) then raise exception 'Ended today remains visible';end if;
 select ends_on into end_date from core.department_memberships where id=mid;
 if end_date<>private.kst_today() then raise exception 'End history not preserved';end if;
 mid2:=public.set_department_student_membership(dep,st,true,private.kst_today());
 if mid2<>mid then raise exception 'Same-day rejoin duplicated membership';end if;
 perform public.set_department_active(dep,false);
 perform public.set_department_student_membership(dep,st,false,private.kst_today());
 if (select count(*) from public.v_department_current_members)<>n_before then raise exception 'Stopped department removal failed';end if;
end $test$;
reset role;
select 'same-day end, same-day rejoin, inactive department removal and history preservation passed' result;

rollback;
