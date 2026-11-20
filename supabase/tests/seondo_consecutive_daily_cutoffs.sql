-- Disposable fixture only. No real roster or production mutations.
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000100',true);
select set_config('test.role','lead',true);
select set_config('test.today','2026-11-18',true);
insert into auth.users values ('00000000-0000-4000-8000-000000000100');
insert into public.admins values ('00000000-0000-4000-8000-000000000100',true,'SEONDO');
insert into core.students values ('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
insert into public.students(id,core_student_id,grade,name,homeroom) values
(1,'00000000-0000-4000-8000-000000000001',8,'Synthetic Secondary','G8'),
(2,'00000000-0000-4000-8000-000000000002',3,'Synthetic Elementary','G3');
insert into discipline.seondo_policy(starts_at) values ('2026-11-18 00:00+09');
insert into public.point_records(id,core_student_id,recorded_at,created_at,points,type,item) values
(1001,'00000000-0000-4000-8000-000000000001','2026-11-18','2026-11-18 07:00+09',2,'NEGATIVE','Prior frozen initial'),
(1002,'00000000-0000-4000-8000-000000000001','2026-11-19','2026-11-19 07:00+09',3,'NEGATIVE','Never printed initial'),
(1003,'00000000-0000-4000-8000-000000000002','2026-11-18','2026-11-18 07:00+09',1,'NEGATIVE','Elementary before deadline'),
(1004,'00000000-0000-4000-8000-000000000001','2026-11-19','2026-11-19 07:00+09',1,'NEGATIVE','Already submitted');
insert into public.reflection_records(id,point_record_id,due_at,submission_deadline,submitted) values
(1001,1001,'2026-11-18 17:00+09','2026-11-18',false),
(1002,1002,'2026-11-19 17:00+09','2026-11-19',false),
(1003,1003,'2026-11-19 08:20+09','2026-11-19',false),
(1004,1004,'2026-11-19 17:00+09','2026-11-19',true);
select private.seondo_notice_action_at(false,'2026-11-18 08:00+09');
-- Missing publication cannot stop the first clock. Elementary gets its own 08:20 cutoff.
do $$ begin
 if not exists(select 1 from private.seondo_open_notice('2026-11-19 08:00+09') where reflection_id=1001 and is_double and pages=4)
 or not exists(select 1 from private.seondo_open_notice('2026-11-19 08:00+09') where reflection_id=1003 and not is_double and pages=1)
 then raise exception 'First deadlines were reset or ignored'; end if;
end; $$;
-- Carry a still-regular elementary snapshot without violating canonical-initial uniqueness.
select private.seondo_notice_action_at(false,'2026-11-19 08:00+09');
select private.seondo_notice_action_at(false,'2026-11-19 08:01+09');
do $$ begin
 if (select count(*) from discipline.seondo_notice_batches)<>2
 or (select count(*) from discipline.seondo_notice_entries where reflection_id=1003 and not is_double)<>2
 or (select count(*) from public.v_reflections where id=1003)<>1
 then raise exception 'Snapshot copy duplicated an obligation or cutoff was not idempotent'; end if;
end; $$;
select private.seondo_notice_action_at(true,'2026-11-19 08:02+09');
select private.seondo_notice_action_at(false,'2026-11-20 09:00+09');
select private.seondo_notice_action_at(true,'2026-11-20 09:01+09');
do $$ begin
 if not exists(select 1 from private.seondo_open_notice('2026-11-20 10:00+09') where reflection_id=1001 and is_double and pages=4 and first_due_at='2026-11-18 17:00+09'::timestamptz)
 or not exists(select 1 from private.seondo_open_notice('2026-11-20 10:00+09') where reflection_id=1002 and is_double and pages=6 and due_at='2026-11-20 17:00+09'::timestamptz)
 or exists(select 1 from private.seondo_open_notice('2026-11-20 10:00+09') where reflection_id=1004)
 or (select due_at from public.reflection_records where id=1001)<>'2026-11-18 17:00+09'::timestamptz
 or (select pages from discipline.seondo_notice_entries e join discipline.seondo_notice_batches b on b.id=e.batch_id where reflection_id=1001 and b.notice_day='2026-11-18')<>2
 then raise exception 'Overdue carryover reset, compounded, revived submitted, or changed old snapshot'; end if;
 if private.seondo_second_deadline('2026-11-20 17:00+09',8)<>'2026-11-23 17:00+09'::timestamptz
 then raise exception 'Second deadline did not skip weekend'; end if;
end; $$;
rollback;
