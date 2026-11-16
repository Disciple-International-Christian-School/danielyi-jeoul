-- Run in a disposable PostgreSQL instance with fixtures/seondo.sql and both reflection migrations.
begin;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000100', true);
select set_config('test.role', 'lead', true);
select set_config('test.today', '2027-02-01', true);
insert into auth.users (id) values
  ('00000000-0000-4000-8000-000000000100'),
  ('00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000102');
insert into core.students (id) values
  ('00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000002'),
  ('00000000-0000-4000-8000-000000000003'),
  ('00000000-0000-4000-8000-000000000004');
insert into public.students (id, core_student_id, grade, name, homeroom) values
  (1, '00000000-0000-4000-8000-000000000001', 9, 'Senior A', 'G9-A'),
  (2, '00000000-0000-4000-8000-000000000002', 6, 'Elementary A', 'G6'),
  (3, '00000000-0000-4000-8000-000000000003', 8, 'Middle A', 'G8'),
  (4, '00000000-0000-4000-8000-000000000004', 7, 'Middle B', 'G7');

insert into discipline.seondo_policy (starts_at) values ('2026-11-23 00:00+09');
insert into discipline.seondo_committee_recipients (user_id) values ('00000000-0000-4000-8000-000000000101');
insert into public.point_records (id, core_student_id, recorded_at, created_at, points, type, item)
select x.id, s.core_student_id, x.local_time::date, x.local_time at time zone 'Asia/Seoul', x.points, x.type, x.item
from (values
  (1001, 1, timestamp '2026-11-20 08:00', 3, 'NEGATIVE', 'Earlier rule'),
  (1002, 1, timestamp '2026-12-23 12:00', 5, 'POSITIVE', 'Five-point merit'),
  (1003, 1, timestamp '2026-12-24 06:00', 7, 'NEGATIVE', 'Seven-point offense'),
  (1004, 1, timestamp '2026-12-24 07:00', 2, 'NEGATIVE', 'Two-point offense'),
  (1005, 2, timestamp '2026-12-24 07:15', 1, 'NEGATIVE', 'Elementary offense'),
  (1006, 1, timestamp '2026-12-24 08:00', 3, 'NEGATIVE', 'After cutoff'),
  (1007, 1, timestamp '2026-12-24 08:05', 1, 'POSITIVE', 'After cutoff merit'),
  (1008, 1, timestamp '2027-01-04 07:00', 8, 'NEGATIVE', 'January offense'),
  (1009, 1, timestamp '2027-01-18 07:00', 8, 'NEGATIVE', 'January offense'),
  (1010, 1, timestamp '2027-01-25 07:00', 8, 'NEGATIVE', 'January offense'),
  (1011, 3, timestamp '2027-01-20 07:00', 2, 'NEGATIVE', 'One of three'),
  (1012, 3, timestamp '2027-01-20 07:01', 2, 'NEGATIVE', 'Two of three'),
  (1013, 3, timestamp '2027-01-20 07:02', 3, 'NEGATIVE', 'Three of three'),
  (1014, 4, timestamp '2027-01-25 07:00', 9, 'NEGATIVE', 'Weekly balance check'),
  (1015, 4, timestamp '2027-01-25 07:00', 2, 'POSITIVE', 'Weekly balance check'),
  (1016, 4, timestamp '2026-12-24 06:30', 3, 'POSITIVE', 'Merit after offense'),
  (1017, 4, timestamp '2026-12-24 06:00', 3, 'NEGATIVE', 'Offense before merit'),
  (1018, 3, timestamp '2026-12-23 06:00', 5, 'POSITIVE', 'Merit before holiday'),
  (1019, 3, timestamp '2026-12-30 06:00', 5, 'NEGATIVE', 'Last valid school day')
) x(id, student_id, local_time, points, type, item)
join public.students s on s.id = x.student_id;

-- Synthetic elementary incident rows verify that monthly eligibility excludes G1–G6.
insert into public.point_records (id, core_student_id, recorded_at, created_at, points, type, item)
select 1100 + row_number() over ()::integer, s.core_student_id, w.day, (w.day + time '12:00') at time zone 'Asia/Seoul',
  1, 'NEGATIVE', 'Elementary training'
from public.students s
cross join (values (date '2027-01-04'), (date '2027-01-18'), (date '2027-01-25')) w(day)
cross join generate_series(1, 8)
where s.id = 2;

insert into public.reflection_records (id, point_record_id, due_at, submission_deadline)
select p.id, p.id, (p.recorded_at + time '17:00') at time zone 'Asia/Seoul', p.recorded_at
from public.point_records p where p.type = 'NEGATIVE' and p.id < 1100;

-- Registered discretionary school closures must not consume merit-validity days.
insert into discipline.seondo_holidays(day,label)
values ('2027-01-06','DICS discretionary school closure');

do $
begin
  if private.seondo_merit_valid('2027-01-04','2027-01-11') is not true
    or private.seondo_merit_valid('2027-01-04','2027-01-12') is not false then
    raise exception 'School closure must extend merit validity to five attendance days';
  end if;
end;
$;

do $
begin
  if private.seondo_merit_valid('2026-12-23', '2026-12-29') is not true
    or private.seondo_merit_valid('2026-12-23', '2026-12-30') is not true
    or private.seondo_merit_valid('2026-12-23', '2026-12-31') is not false
    or private.seondo_merit_valid('2027-01-04', '2027-01-09') is not false
    or private.seondo_deadline('2026-12-24', 6, false) <> timestamptz '2026-12-28 08:20+09'
    or private.seondo_deadline('2026-12-24', 6, true) <> timestamptz '2026-12-29 08:20+09'
    or private.seondo_deadline('2026-12-24', 9, true) <> timestamptz '2026-12-28 17:00+09' then
    raise exception 'Weekday validity or school holiday calculation failed';
  end if;
  if not exists (select from public.v_reflections where id = 1001 and not seondo_managed)
    or exists (select from public.v_reflections where id in (1003,1004,1005)) then
    raise exception 'Pre-cutover cases or unpublished cases are incorrect';
  end if;
end;
$$;

select private.seondo_notice_action_at(false, '2026-12-24 08:00+09');
select private.seondo_notice_action_at(false, '2026-12-24 08:01+09');
do $$
begin
  if (select pages from discipline.seondo_notice_entries where reflection_id = 1003) is distinct from 4
    or (select pages from discipline.seondo_notice_entries where reflection_id = 1004) is distinct from 0
    or (select pages from discipline.seondo_notice_entries where reflection_id = 1017) is distinct from 3
    or exists (select from discipline.seondo_merit_allocations where reflection_id = 1017)
    or exists (select from discipline.seondo_notice_entries where reflection_id in (1006,1007,1019)) then
    raise exception 'Cutoff and smallest-first allocation failed';
  end if;
  if exists (select from public.v_reflections where id = 1003) then
    raise exception 'Draft must not open student deadlines';
  end if;
end;
$$;

select private.seondo_notice_action_at(true, '2026-12-24 08:15+09');
select private.seondo_notice_action_at(true, '2026-12-24 08:16+09');
select private.seondo_notice_action_at(false, '2026-12-28 08:00+09');
select private.seondo_notice_action_at(true, '2026-12-28 08:05+09');
select private.seondo_notice_action_at(false, '2026-12-29 08:00+09');
select private.seondo_notice_action_at(true, '2026-12-29 08:05+09');

do $$
begin
  if not exists (select from public.v_reflections
      where id = 1003 and seondo_managed and reflection_pages = 4
        and due_at = timestamptz '2026-12-24 17:00+09'
        and double_submit_deadline = timestamptz '2026-12-28 17:00+09')
    or exists (select from public.v_reflections where id = 1004)
    or not exists (select from public.v_reflections where id = 1006 and reflection_pages = 2 and due_at = '2026-12-28 17:00+09')
    or not exists (select from discipline.seondo_notice_entries e
      join discipline.seondo_notice_batches b on b.id = e.batch_id
      where b.notice_day = '2026-12-29' and e.reflection_id = 1005 and e.is_double and e.pages = 2
        and e.due_at = timestamptz '2026-12-29 08:20+09')
    or (select sum(points) from discipline.seondo_merit_allocations where merit_id = 1002) <> 5
    or (select pages from discipline.seondo_notice_entries where reflection_id = 1019) is distinct from 0
    or (select sum(points) from discipline.seondo_merit_allocations where merit_id = 1018) is distinct from 5 then
    raise exception 'Posting, carryover, or merit reuse failed';
  end if;
  if (public.get_seondo_notice('2026-12-24')->'entries'->0->>'pages') is null then
    raise exception 'Authorized notice list is missing';
  end if;
end;
$$;

select private.seondo_notice_action_at(false, '2027-01-04 08:00+09');
select private.seondo_notice_action_at(true, '2027-01-04 08:05+09');
update public.reflection_records set submitted = true, submitted_at = '2027-01-06 08:00+09' where id = 1008;

select private.seondo_finalize('2027-01-31 23:59+09');
select private.seondo_finalize('2027-02-01 00:59+09');
do $$
begin
  if (select count(*) from discipline.seondo_weekly_training where week_start = '2027-01-04' and core_student_id =
    '00000000-0000-4000-8000-000000000001') <> 1
    or (select cardinality(reasons) from discipline.seondo_weekly_training
      where week_start = '2027-01-04' and core_student_id = '00000000-0000-4000-8000-000000000001') is distinct from 2
    or exists (select from discipline.seondo_weekly_training where week_start >= '2027-01-01' and core_student_id in
      ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004')) then
    raise exception 'Weekly threshold, late submission, or duplicate handling failed';
  end if;
  if (select jsonb_array_length(public.get_seondo_settlements('MONTHLY','2027-01-01')->'students')) <> 1
    or (select training_count from discipline.seondo_monthly_committee where month_start = '2027-01-01') is distinct from 4
    or (select count(*) from discipline.seondo_committee_inbox where month_start = '2027-01-01') <> 1 then
    raise exception 'Calendar-month settlement or elementary exclusion failed';
  end if;
end;
$$;

set local role authenticated;
select set_config('test.role','teacher',true);
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000101', true);
do $$
begin
  if public.can_read_seondo_committee() is not true
    or (public.get_seondo_settlements('MONTHLY', '2027-01-01')->>'delivered_at') is null then
    raise exception 'Registered teacher inbox is missing';
  end if;
  if jsonb_array_length(public.get_seondo_notice('2026-12-24')->'entries') <> 0 then
    raise exception 'Non-admin accessed a daily notice';
  end if;
  begin
    perform public.seondo_notice_action(false);
    raise exception 'Unexpected authorized write';
  exception when others then
    if sqlerrm <> '선도부장 권한이 필요합니다.' then raise; end if;
  end;
end;
$$;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000102', true);
do $$
begin
  if public.can_read_seondo_committee() is true then
    raise exception 'An unregistered recipient passed the inbox gate';
  end if;
  begin
    perform public.get_seondo_settlements('MONTHLY','2027-01-01');
    raise exception 'Unexpected authorized report access';
  exception when others then
    if sqlerrm <> '결산 조회 권한이 필요합니다.' then raise; end if;
  end;
end;
$$;
reset role;

rollback;
