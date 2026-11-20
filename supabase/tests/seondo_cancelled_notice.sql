-- Disposable Seondo fixture only; all identities and records are synthetic.
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000100',true);
select set_config('test.role','lead',true);
insert into auth.users values ('00000000-0000-4000-8000-000000000100');
insert into core.students values ('00000000-0000-4000-8000-000000000001');
insert into public.students(id,core_student_id,grade,name,homeroom)
values (1,'00000000-0000-4000-8000-000000000001',4,'Synthetic cancellation','G4');
insert into discipline.seondo_policy(starts_at) values (now()-interval '7 days');
insert into public.point_records(id,core_student_id,recorded_at,created_at,points,type,item)
values (1001,'00000000-0000-4000-8000-000000000001',private.kst_today()-1,now()-interval '1 day',1,'NEGATIVE','Cancelled original');
insert into public.reflection_records(id,point_record_id,due_at,submission_deadline)
values (1001,1001,now()-interval '12 hours',private.kst_today()-1);
-- Freeze before cancellation, then keep the old snapshot as audit evidence.
select private.seondo_notice_action_at(false,now()-interval '2 minutes');
update public.point_records set deleted_at=now() where id=1001;
update public.reflection_records set submitted=true,submitted_at=now() where id=1001;
insert into public.point_records(id,core_student_id,recorded_at,created_at,points,type,item)
values (1002,'00000000-0000-4000-8000-000000000001',private.kst_today(),now()-interval '1 minute',1,'NEGATIVE','Replacement after cutoff');
insert into public.reflection_records(id,point_record_id,due_at,submission_deadline)
values (1002,1002,now()+interval '2 days',private.kst_today()+2);
do $$ declare n jsonb; begin
 n:=public.get_seondo_notice(private.kst_today());
 if jsonb_array_length(n->'entries')<>0
 or jsonb_array_length(n->'live_entries')<>1
 or (n->'live_entries'->0->>'reflection_id')::int<>1002
 or (n->'live_entries'->0->>'is_double')::boolean
 or (n->'live_entries'->0->>'pages')::int<>1
 or (n->>'pending_after_cutoff_count')::int<>1
 or not exists(select 1 from discipline.seondo_notice_entries where reflection_id=1001)
 then raise exception 'Cancelled snapshot revived, replacement lost/doubled, or original audit snapshot removed'; end if;
end; $$;
update public.reflection_records set submitted=true,submitted_at=now() where id=1002;
do $$ declare n jsonb; begin
 n:=public.get_seondo_notice(private.kst_today());
 if n->'live_entries'<>'[]'::jsonb then raise exception 'Submitted replacement revived'; end if;
end; $$;
rollback;
