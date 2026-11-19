-- Disposable fixture regression for consecutive KST notice cutoffs.
-- Must run after fixtures/seondo.sql and all seondo migrations. Never run on production.
begin;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000100',true);
select set_config('test.role','lead',true);
select set_config('test.today','2026-11-18',true);
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000100');
insert into core.students(id) values ('00000000-0000-4000-8000-000000000001');
insert into public.students(id,core_student_id,grade,name,homeroom)
values (1,'00000000-0000-4000-8000-000000000001',9,'Synthetic A','G9');
insert into discipline.seondo_policy(starts_at) values ('2026-11-18 00:00+09');
insert into public.point_records(id,core_student_id,recorded_at,created_at,points,type,item)
values
(1001,'00000000-0000-4000-8000-000000000001','2026-11-18','2026-11-18 07:00+09',2,'NEGATIVE','Old unposted obligation'),
(1002,'00000000-0000-4000-8000-000000000001','2026-11-19','2026-11-19 07:00+09',3,'NEGATIVE','New current obligation');
insert into public.reflection_records(id,point_record_id,due_at,submission_deadline)
values
(1001,1001,'2026-11-18 17:00+09','2026-11-18'),
(1002,1002,'2026-11-19 17:00+09','2026-11-19');

-- Freeze an initial draft on the 18th without publishing.
select private.seondo_notice_action_at(false,'2026-11-18 08:00+09');
do $$
begin
 if (select count(*) from discipline.seondo_notice_batches) <> 1
    or (select pages from discipline.seondo_notice_entries where reflection_id=1001) <> 2
 then raise exception 'November 18 draft not created as expected'; end if;
end; $$;

select set_config('test.today','2026-11-19',true);
do $$
declare n jsonb;
begin
 n:=public.get_seondo_notice('2026-11-19');
 if n->'batch'<>'null'::jsonb
   or jsonb_array_length(n->'preview_entries')<>2
   or not exists (
     select from jsonb_array_elements(n->'preview_entries') v
     where (v->>'reflection_id')::int=1001 and (v->>'is_double')::boolean=false and (v->>'pages')::int=2
   ) then
   raise exception 'Before today cutoff, prior unpublished initial obligation must remain regular';
 end if;
end; $$;

-- A later-day cutoff is allowed despite yesterday's unpublished batch.
select private.seondo_notice_action_at(false,'2026-11-19 09:00+09');
do $$
begin
 if (select count(*) from discipline.seondo_notice_batches) <> 2
   or (select count(*) from discipline.seondo_notice_entries e
       join discipline.seondo_notice_batches b on b.id=e.batch_id
       where b.notice_day='2026-11-19' and not e.is_double and e.pages>0) <> 2
   or (select count(*) from discipline.seondo_notice_entries e
       join discipline.seondo_notice_batches b on b.id=e.batch_id
       where b.notice_day='2026-11-19' and e.is_double) <> 0
   or (select pages from discipline.seondo_notice_entries e
       join discipline.seondo_notice_batches b on b.id=e.batch_id
       where b.notice_day='2026-11-18' and e.reflection_id=1001) <> 2
   or (select published_at from discipline.seondo_notice_batches where notice_day='2026-11-18') is not null
 then raise exception 'Cross-day cutoff incorrectly modified or doubled old draft'; end if;
end; $$;

-- A second cutoff on the same day must be idempotent, then publish only today.
select private.seondo_notice_action_at(false,'2026-11-19 09:02+09');
select private.seondo_notice_action_at(true,'2026-11-19 09:05+09');
do $$
begin
 if (select count(*) from discipline.seondo_notice_batches) <> 2
   or (select published_at from discipline.seondo_notice_batches where notice_day='2026-11-18') is not null
   or (select published_at from discipline.seondo_notice_batches where notice_day='2026-11-19') is null
   or (select due_at from public.reflection_records where id=1001) <> '2026-11-19 17:00+09'::timestamptz
 then raise exception 'Today publishing unexpectedly modified past snapshot or missed deadline'; end if;
end; $$;
rollback;
