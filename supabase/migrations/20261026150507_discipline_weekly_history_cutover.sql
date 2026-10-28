-- Historical weekly settlements are not dated incidents.
create table discipline.history_settings (
  term_id uuid primary key references core.academic_terms(id) on delete restrict,
  daily_starts_on date not null check (extract(isodow from daily_starts_on)=1),
  min_grade int not null default 7, max_grade int not null default 12,
  activated_at timestamptz, activated_by uuid references auth.users(id),
  check (min_grade between 1 and 12 and max_grade between min_grade and 12)
);
create table discipline.history_import_batches (
  id uuid primary key default gen_random_uuid(), term_id uuid not null references core.academic_terms(id),
  source_label text not null check(length(source_label) between 1 and 250),
  content_hash text not null, payload jsonb not null,
  created_at timestamptz not null default now(), created_by uuid references auth.users(id),
  unique(term_id,content_hash)
);
create table discipline.history_calendar (
  term_id uuid not null references core.academic_terms(id),
  week_start date not null check(extract(isodow from week_start)=1),
  kind text not null check(kind in ('WEEKLY','NO_SCHOOL')), label text not null,
  primary key(term_id,week_start)
);
create table discipline.history_aliases (
  term_id uuid not null references core.academic_terms(id), source_name text not null,
  grade int not null, section text not null default '',
  core_student_id uuid not null references core.students(id) on delete restrict,
  reason text not null, primary key(term_id,source_name,grade,section)
);
create table discipline.history_source_rows (
  id bigint generated always as identity primary key,
  batch_id uuid not null references discipline.history_import_batches(id) on delete restrict,
  week_start date not null, source_key text not null, source_name text not null,
  grade int not null check(grade between 7 and 12), section text not null default '',
  positive_points int not null check(positive_points between 0 and 1000),
  negative_points int not null check(negative_points between 0 and 1000),
  source_net int not null, raw jsonb not null,
  core_student_id uuid references core.students(id) on delete restrict,
  resolution text not null check(resolution in ('MATCHED','ALIAS','UNLINKED')),
  unique(batch_id,source_key), check(source_net=positive_points-negative_points)
);
create table discipline.weekly_balances (
  id bigint generated always as identity primary key,
  batch_id uuid not null references discipline.history_import_batches(id) on delete restrict,
  term_id uuid not null references core.academic_terms(id),
  core_student_id uuid not null references core.students(id) on delete restrict,
  week_start date not null check(extract(isodow from week_start)=1),
  grade int not null check(grade between 7 and 12), source_name text not null,
  source_class text not null, positive_points int not null check(positive_points>=0),
  negative_points int not null check(negative_points>=0),
  source_net int not null, source_row_ids bigint[] not null,
  review_note text, is_current boolean not null default true,
  created_at timestamptz not null default now(),
  check(source_net=positive_points-negative_points)
);
create unique index weekly_balance_one_current on discipline.weekly_balances(term_id,core_student_id,week_start) where is_current;
create index weekly_balances_batch_idx on discipline.weekly_balances(batch_id);
create index history_source_batch_idx on discipline.history_source_rows(batch_id);
create index history_source_core_idx on discipline.history_source_rows(core_student_id);
alter table public.point_records add column superseded_by_import_id uuid references discipline.history_import_batches(id) on delete restrict;
alter table public.point_records add column request_id uuid;
create index point_records_superseded_idx on public.point_records(superseded_by_import_id) where superseded_by_import_id is not null;
create unique index point_records_request_once on public.point_records(created_by,request_id) where request_id is not null;

-- No anonymous access. Import internals are lead-only; balances obey staff scope.
alter table discipline.history_settings enable row level security;
alter table discipline.history_import_batches enable row level security;
alter table discipline.history_calendar enable row level security;
alter table discipline.history_aliases enable row level security;
alter table discipline.history_source_rows enable row level security;
alter table discipline.weekly_balances enable row level security;
grant usage on schema discipline to authenticated;
grant select on discipline.history_settings,discipline.history_calendar to authenticated;
grant select on discipline.history_import_batches,discipline.history_aliases,discipline.history_source_rows,discipline.weekly_balances to authenticated;
create policy history_settings_read on discipline.history_settings for select to authenticated using (private.current_admin_role() is not null);
create policy history_calendar_read on discipline.history_calendar for select to authenticated using (private.current_admin_role() is not null);
create policy history_batches_read on discipline.history_import_batches for select to authenticated using(private.current_admin_is_lead());
create policy history_aliases_read on discipline.history_aliases for select to authenticated using(private.current_admin_is_lead());
create policy history_source_read on discipline.history_source_rows for select to authenticated using(private.current_admin_is_lead());
create policy weekly_balances_read on discipline.weekly_balances for select to authenticated using (
  private.current_admin_role() is not null and
  (private.current_admin_scope()='ALL' or (private.current_admin_scope()='MIDDLE' and grade between 7 and 9) or (private.current_admin_scope()='HIGH' and grade between 10 and 12))
);

create or replace function private.import_discipline_weekly(p_term_id uuid,p_source_label text,p_rows jsonb,p_notes jsonb default '[]')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_batch uuid; v_cutover date; v_hash text; v_actor uuid:=auth.uid();
begin
 if v_actor is null or not private.current_admin_is_lead() then raise exception '선도부장 권한이 필요합니다.'; end if;
 if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows) not between 1 and 5000 then raise exception '1~5000개 원본 행이 필요합니다.'; end if;
 select daily_starts_on into v_cutover from discipline.history_settings where term_id=p_term_id for update;
 if v_cutover is null then raise exception '이관 기준 학기와 전환일을 먼저 설정하세요.'; end if;
 v_hash:=md5(jsonb_build_object('rows',p_rows,'notes',p_notes)::text);
 select id into v_batch from discipline.history_import_batches where term_id=p_term_id and content_hash=v_hash;
 if v_batch is not null then
   if exists(select 1 from discipline.weekly_balances where batch_id=v_batch and not is_current) then raise exception '이 파일은 이전 버전입니다. 최신 원본 파일로 수정 내용을 검토하세요.'; end if;
   return jsonb_build_object('batch_id',v_batch,'reused',true,'source_rows',(select count(*) from discipline.history_source_rows where batch_id=v_batch),'balances',(select count(*) from discipline.weekly_balances where batch_id=v_batch),'unlinked',(select count(*) from discipline.history_source_rows where batch_id=v_batch and core_student_id is null));
 end if;
 if exists(select 1 from jsonb_to_recordset(p_rows) r(week_start date,grade int,source_name text,source_key text,positive_points int,negative_points int,source_net int)
   join core.academic_terms t on t.id=p_term_id
   where r.week_start is null or r.week_start>t.ends_on or r.week_start+6<t.starts_on or r.week_start>=v_cutover or extract(isodow from r.week_start)<>1 or r.grade not between 7 and 12 or r.grade is null or nullif(btrim(r.source_name),'') is null or nullif(r.source_key,'') is null or r.positive_points is null or r.negative_points is null or r.source_net is null or r.source_net<>r.positive_points-r.negative_points) then raise exception '주차·학생·점수 또는 최종값이 유효하지 않습니다. 10/26 이후는 일별로 기록하세요.'; end if;
 if exists(select 1 from jsonb_to_recordset(p_rows) r(week_start date) join discipline.history_calendar c on c.term_id=p_term_id and c.week_start=r.week_start where c.kind='NO_SCHOOL') then raise exception '비운영 주차에는 점수를 이관할 수 없습니다.'; end if;
 -- A replacement must contain every previously imported source identity in each replaced week.
 if exists(select 1 from discipline.history_source_rows oldrow join discipline.history_import_batches b on b.id=oldrow.batch_id
   where b.term_id=p_term_id and exists(select 1 from discipline.weekly_balances w where w.batch_id=b.id and w.week_start=oldrow.week_start and w.is_current)
   and oldrow.week_start in(select (value->>'week_start')::date from jsonb_array_elements(p_rows))
   and not exists(select 1 from jsonb_to_recordset(p_rows) r(week_start date,grade int,section text,source_name text)
     where r.week_start=oldrow.week_start and r.grade=oldrow.grade and coalesce(r.section,'')=oldrow.section and btrim(r.source_name)=oldrow.source_name)) then raise exception '주차 전체 명부가 필요합니다. 기존 학생 행이 빠진 부분 파일은 이관할 수 없습니다.'; end if;
 insert into discipline.history_import_batches(term_id,source_label,content_hash,payload,created_by)
 values(p_term_id,p_source_label,v_hash,jsonb_build_object('rows',p_rows,'notes',p_notes),v_actor) returning id into v_batch;
 insert into discipline.history_source_rows(batch_id,week_start,source_key,source_name,grade,section,positive_points,negative_points,source_net,raw,core_student_id,resolution)
 select v_batch,r.week_start,r.source_key,btrim(r.source_name),r.grade,coalesce(r.section,''),r.positive_points,r.negative_points,r.source_net,coalesce(r.raw,'{}'),coalesce(a.core_student_id,m.id),case when a.core_student_id is not null then 'ALIAS' when m.id is not null then 'MATCHED' else 'UNLINKED' end
 from jsonb_to_recordset(p_rows) r(week_start date,source_key text,source_name text,grade int,section text,positive_points int,negative_points int,source_net int,raw jsonb)
 left join discipline.history_aliases a on a.term_id=p_term_id and a.source_name=btrim(r.source_name) and a.grade=r.grade and a.section=coalesce(r.section,'')
 left join lateral (select s.id from core.students s join core.enrollments e on e.student_id=s.id and e.term_id=p_term_id join core.classes c on c.id=e.class_id where s.name=btrim(r.source_name) and c.grade=r.grade and coalesce(c.section,'')=coalesce(r.section,'')) m on true;
 -- Identical repeated rows and zero placeholders collapse. Conflicting nonzero settlements never add silently.
 if exists(select 1 from discipline.history_source_rows where batch_id=v_batch and core_student_id is not null and (positive_points<>0 or negative_points<>0) group by core_student_id,week_start having count(distinct (positive_points,negative_points))>1) then raise exception '같은 학생·주차에 서로 다른 최종값이 있습니다. 원본에서 확인해주세요.'; end if;
 update discipline.weekly_balances w set is_current=false where w.term_id=p_term_id and w.is_current and w.week_start in(select distinct week_start from discipline.history_source_rows where batch_id=v_batch);
 insert into discipline.weekly_balances(batch_id,term_id,core_student_id,week_start,grade,source_name,source_class,positive_points,negative_points,source_net,source_row_ids,review_note)
 select v_batch,p_term_id,core_student_id,week_start,max(grade),min(source_name),'G'||max(grade)||case when max(section)<>'' then '-'||max(section) else '' end,
 max(positive_points),max(negative_points),max(positive_points)-max(negative_points),array_agg(id order by id),
 nullif(concat_ws(' · ',case when count(*)>1 then '중복행 통합: 동일값/0점 자리행' end,case when max(positive_points)>=100 or max(negative_points)>=100 then '큰 점수: 원본값 확인 필요' end,case when bool_or(raw->'cells'->>0 !~ '^G(7|8|9|10|11|12)(-[A-Z])?$') then '학년 표기: 다른 주차의 일치 반으로 연결, 원본 보존' end),'')
 from discipline.history_source_rows where batch_id=v_batch and core_student_id is not null group by core_student_id,week_start;
 insert into discipline.history_calendar(term_id,week_start,kind,label)
 select p_term_id,week_start,'WEEKLY','주간 확정' from discipline.history_source_rows where batch_id=v_batch group by week_start on conflict(term_id,week_start) do update set kind='WEEKLY',label='주간 확정';
 return jsonb_build_object('batch_id',v_batch,'reused',false,'source_rows',(select count(*) from discipline.history_source_rows where batch_id=v_batch),'balances',(select count(*) from discipline.weekly_balances where batch_id=v_batch),'unlinked',(select count(*) from discipline.history_source_rows where batch_id=v_batch and core_student_id is null));
end $$;
revoke all on function private.import_discipline_weekly(uuid,text,jsonb,jsonb) from public,anon;
grant execute on function private.import_discipline_weekly(uuid,text,jsonb,jsonb) to authenticated;
create function public.import_discipline_weekly(p_term_id uuid,p_source_label text,p_rows jsonb,p_notes jsonb default '[]')
returns jsonb language sql security invoker set search_path='' as $$select private.import_discipline_weekly(p_term_id,p_source_label,p_rows,p_notes)$$;
revoke all on function public.import_discipline_weekly(uuid,text,jsonb,jsonb) from public,anon;
grant execute on function public.import_discipline_weekly(uuid,text,jsonb,jsonb) to authenticated;

create view public.v_discipline_history_calendar with(security_invoker=true) as select c.*,s.daily_starts_on from discipline.history_calendar c join discipline.history_settings s using(term_id);
grant select on public.v_discipline_history_calendar to authenticated;

-- Safely expose a common read model to scoped staff or the owning CORE student.
create function private.discipline_history(p_student_id uuid,p_start date,p_end date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_role public.admin_role; v_scope public.discipline_scope; v_result jsonb; v_term uuid;
begin
 if v_uid is null then raise exception '로그인이 필요합니다.'; end if;
 v_role:=private.current_admin_role(); v_scope:=private.current_admin_scope();
 if v_role is null and (p_student_id is null or not exists(select 1 from core.students where id=p_student_id and auth_user_id=v_uid)) then raise exception '본인 이력만 조회할 수 있습니다.'; end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>800 then raise exception '조회 기간을 확인하세요.'; end if;
 select id into v_term from core.academic_terms where is_current limit 1;
 with identities as (
   select s.id,s.student_no,s.name,s.is_active,coalesce(c.grade,h.grade) grade,coalesce(c.label,h.source_class) homeroom
   from core.students s left join core.enrollments e on e.student_id=s.id and e.term_id=v_term left join core.classes c on c.id=e.class_id
   left join lateral(select grade,source_class from discipline.weekly_balances where core_student_id=s.id and term_id=v_term and is_current order by week_start desc limit 1) h on true
   where (p_student_id is null or s.id=p_student_id)
 ), allowed as (
   select * from identities i where (v_role is null and i.id=p_student_id) or (v_role is not null and (v_scope='ALL' or (v_scope='ELEMENTARY' and i.grade between 1 and 6) or (v_scope='MIDDLE' and i.grade between 7 and 9) or (v_scope='HIGH' and i.grade between 10 and 12)))
 ), balances as (
   select w.core_student_id,w.week_start,(w.week_start+6) week_end,w.positive_points,w.negative_points,w.source_net net,
     null::int incident_count,'WEEKLY'::text source,w.review_note,w.batch_id::text source_id
   from discipline.weekly_balances w join allowed a on a.id=w.core_student_id
   where w.is_current and w.term_id=v_term and w.week_start<=p_end and w.week_start+6>=p_start
   union all
   select pr.core_student_id,date_trunc('week',pr.recorded_at::timestamp)::date,date_trunc('week',pr.recorded_at::timestamp)::date+6,
     coalesce(sum(pr.points) filter(where pr.type='POSITIVE'),0)::int,coalesce(sum(pr.points) filter(where pr.type='NEGATIVE'),0)::int,
     (coalesce(sum(pr.points) filter(where pr.type='POSITIVE'),0)-coalesce(sum(pr.points) filter(where pr.type='NEGATIVE'),0))::int,
     count(*) filter(where pr.type='NEGATIVE')::int,'DAILY',null,null
   from public.point_records pr join allowed a on a.id=pr.core_student_id where pr.deleted_at is null and pr.superseded_by_import_id is null and pr.recorded_at between p_start and p_end
   group by pr.core_student_id,date_trunc('week',pr.recorded_at::timestamp)::date
 )
 select jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(x) order by x.week_start,x.student_name) from(select b.*,a.name student_name,a.student_no,a.homeroom,a.grade,a.is_active from balances b join allowed a on a.id=b.core_student_id) x),'[]'),
 'students',coalesce((select jsonb_agg(to_jsonb(a)) from allowed a),'[]'),
 'calendar',coalesce((select jsonb_agg(to_jsonb(c) order by c.week_start) from discipline.history_calendar c where c.term_id=v_term and c.week_start<=p_end and c.week_start+6>=p_start),'[]'),
 'daily_starts_on',(select daily_starts_on from discipline.history_settings where term_id=v_term and activated_at is not null)) into v_result;
 return v_result;
end $$;
revoke all on function private.discipline_history(uuid,date,date) from public,anon;
grant execute on function private.discipline_history(uuid,date,date) to authenticated;
create function public.get_discipline_history(p_student_id uuid,p_start date,p_end date) returns jsonb language sql security invoker set search_path='' as $$select private.discipline_history(p_student_id,p_start,p_end)$$;
revoke all on function public.get_discipline_history(uuid,date,date) from public,anon;
grant execute on function public.get_discipline_history(uuid,date,date) to authenticated;

-- Client request IDs survive a retry; deliberate repeated incidents use a new ID.
create function public.create_point_record_once(p_core_student_id uuid,p_type public.point_type,p_item text,p_points int,p_recorded_at date,p_request_id uuid,p_reflection_submitted boolean default false)
returns int language plpgsql security invoker set search_path='' as $$
declare v_id int; v_name text; v_old public.point_records%rowtype;
begin
 if auth.uid() is null or private.current_admin_role() is distinct from 'SEONDO' then raise exception '선도부 권한이 필요합니다.'; end if;
 if p_request_id is null then raise exception '저장 요청 ID가 필요합니다.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':'||p_request_id::text,0));
 select * into v_old from public.point_records where created_by=auth.uid() and request_id=p_request_id;
 if v_old.id is not null then
  if v_old.core_student_id<>p_core_student_id or v_old.type<>p_type or v_old.item<>btrim(p_item) or v_old.points<>p_points or v_old.recorded_at<>p_recorded_at then raise exception '이 요청 ID는 다른 기록에 사용됐습니다.'; end if;
  return v_old.id;
 end if;
 if not exists(select 1 from public.v_discipline_students where core_student_id=p_core_student_id) then raise exception '재학생을 선택하세요.'; end if;
 select display_name into v_name from public.admins where user_id=auth.uid() and is_active limit 1;
 insert into public.point_records(core_student_id,type,item,points,recorded_at,entered_by_name,created_by,request_id)
 values(p_core_student_id,p_type,btrim(p_item),p_points,p_recorded_at,v_name,auth.uid(),p_request_id) returning id into v_id;
 if p_type='NEGATIVE' and p_reflection_submitted then update public.reflection_records set submitted=true,submitted_at=now() where point_record_id=v_id; end if;
 return v_id;
end $$;
revoke all on function public.create_point_record_once(uuid,public.point_type,text,int,date,uuid,boolean) from public,anon;
grant execute on function public.create_point_record_once(uuid,public.point_type,text,int,date,uuid,boolean) to authenticated;

-- Extensions keep the existing default deadline. Weekend occurrences extend to Monday.
create function private.reflection_extension_due(p_date date) returns timestamptz language sql immutable set search_path='' as $$
 select ((p_date+case extract(isodow from p_date)::int when 6 then 2 when 7 then 1 else 1 end)+time '17:00') at time zone 'Asia/Seoul'
$$;
revoke all on function private.reflection_extension_due(date) from public,anon;
grant execute on function private.reflection_extension_due(date) to authenticated;
create function public.extend_reflection_to_next_day(p_reflection_id int,p_reason text) returns timestamptz language plpgsql security invoker set search_path='' as $$
declare v_rec record; v_target timestamptz;
begin
 if auth.uid() is null or private.current_admin_role() is distinct from 'SEONDO' then raise exception '선도부 권한이 필요합니다.'; end if;
 select r.*,pr.recorded_at,s.grade into v_rec from public.reflection_records r join public.point_records pr on pr.id=r.point_record_id join public.students s on s.core_student_id=pr.core_student_id where r.id=p_reflection_id and pr.deleted_at is null and pr.superseded_by_import_id is null;
 if not found then raise exception '반성문 기록을 찾을 수 없습니다.'; end if;
 if v_rec.grade<=6 then raise exception '초등은 익일 등교 규칙을 사용합니다.'; end if;
 if v_rec.submitted then raise exception '이미 제출됐습니다.'; end if;
 v_target:=greatest(v_rec.due_at,private.reflection_extension_due(v_rec.recorded_at));
 update public.reflection_records set due_at=v_target,submission_deadline=(v_target at time zone 'Asia/Seoul')::date,deadline_changed_by=auth.uid(),deadline_change_reason=nullif(btrim(p_reason),'') where id=p_reflection_id;
 return v_target;
end $$;
revoke all on function public.extend_reflection_to_next_day(int,text) from public,anon;
grant execute on function public.extend_reflection_to_next_day(int,text) to authenticated;

create or replace view public.v_daily_discipline_notice with(security_invoker=true) as  SELECT pr.id AS point_record_id,
    pr.recorded_at,
    ds.legacy_student_id AS student_id,
    ds.core_student_id,
    ds.student_no,
    ds.name AS student_name,
    ds.grade,
    ds.homeroom,
    pr.item,
    pr.points,
    r.id AS reflection_id,
    r.submitted AS reflection_submitted,
    r.due_at AS reflection_due_at,
        CASE
            WHEN (r.id IS NULL) THEN NULL::text
            WHEN r.submitted THEN 'SUBMITTED'::text
            WHEN (r.due_at < now()) THEN 'DOUBLE'::text
            ELSE 'MISSING'::text
        END AS reflection_status
   FROM ((point_records pr
     JOIN v_discipline_students ds ON ((ds.core_student_id = pr.core_student_id)))
     LEFT JOIN reflection_records r ON ((r.point_record_id = pr.id)))
  WHERE ((pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL) AND (pr.type = 'NEGATIVE'::point_type));

create or replace view public.v_reflections with(security_invoker=true) as  SELECT r.id,
    r.point_record_id,
    s.id AS student_id,
    s.name AS student_name,
    s.grade,
    pr.item,
    pr.points,
    pr.recorded_at,
    r.submitted,
    r.submission_deadline,
    r.submitted_at,
        CASE
            WHEN r.submitted THEN 'SUBMITTED'::text
            WHEN (r.due_at < now()) THEN 'DOUBLE'::text
            ELSE 'MISSING'::text
        END AS status,
    r.due_at,
    r.deadline_change_reason,
        CASE
            WHEN ((s.grade >= 1) AND (s.grade <= 6)) THEN 'ELEMENTARY'::discipline_scope
            WHEN ((s.grade >= 7) AND (s.grade <= 9)) THEN 'MIDDLE'::discipline_scope
            ELSE 'HIGH'::discipline_scope
        END AS assigned_scope,
    pr.core_student_id
   FROM ((reflection_records r
     JOIN point_records pr ON (((pr.id = r.point_record_id) AND (pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL))))
     JOIN students s ON ((s.core_student_id = pr.core_student_id)));

create or replace view public.v_settlement_scores_core_shadow with(security_invoker=true) as  WITH period_students AS (
         SELECT sp.id AS period_id,
            sp.label AS period_label,
            sp.starts_on,
            COALESCE(sp.ends_on, private.kst_today()) AS effective_end,
            sp.ends_on,
            ds.legacy_student_id AS student_id,
            ds.core_student_id,
            ds.student_no,
            ds.name AS student_name,
            ds.grade,
            ds.homeroom
           FROM (settlement_periods sp
             CROSS JOIN v_discipline_students ds)
        ), period_totals AS (
         SELECT ps_1.period_id,
            ps_1.core_student_id,
            (COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'POSITIVE'::point_type)), (0)::bigint))::integer AS positive_points,
            (COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint))::integer AS negative_points
           FROM (period_students ps_1
             LEFT JOIN point_records pr ON (((pr.core_student_id = ps_1.core_student_id) AND (pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL) AND ((pr.recorded_at >= ps_1.starts_on) AND (pr.recorded_at <= ps_1.effective_end)))))
          GROUP BY ps_1.period_id, ps_1.core_student_id
        ), period_weekly AS (
         SELECT ps_1.period_id,
            ps_1.core_student_id,
            (date_trunc('week'::text, (pr.recorded_at)::timestamp without time zone))::date AS week_start,
            (COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'POSITIVE'::point_type)), (0)::bigint))::integer AS positive_points,
            (COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint))::integer AS negative_points,
            (COALESCE(count(*) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint))::integer AS penalty_incident_count
           FROM (period_students ps_1
             JOIN point_records pr ON (((pr.core_student_id = ps_1.core_student_id) AND (pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL) AND ((pr.recorded_at >= ps_1.starts_on) AND (pr.recorded_at <= ps_1.effective_end)))))
          GROUP BY ps_1.period_id, ps_1.core_student_id, ((date_trunc('week'::text, (pr.recorded_at)::timestamp without time zone))::date)
        ), training_counts AS (
         SELECT pw.period_id,
            pw.core_student_id,
            (count(*) FILTER (WHERE ((pw.penalty_incident_count >= 3) OR ((pw.negative_points - pw.positive_points) >= 8))))::integer AS physical_training_weeks
           FROM period_weekly pw
          GROUP BY pw.period_id, pw.core_student_id
        )
 SELECT ps.period_id,
    ps.period_label,
    ps.starts_on,
    ps.ends_on,
    ps.effective_end,
    (ps.ends_on IS NULL) AS is_open,
    ps.student_id,
    ps.core_student_id,
    ps.student_no,
    ps.student_name,
    ps.grade,
    ps.homeroom,
    pt.positive_points,
    pt.negative_points,
    (pt.negative_points - pt.positive_points) AS net_penalty_points,
    COALESCE(tc.physical_training_weeks, 0) AS physical_training_weeks,
    ((COALESCE(tc.physical_training_weeks, 0) >= 3) OR ((pt.negative_points - pt.positive_points) >= 20)) AS committee_required
   FROM ((period_students ps
     JOIN period_totals pt ON (((pt.period_id = ps.period_id) AND (pt.core_student_id = ps.core_student_id))))
     LEFT JOIN training_counts tc ON (((tc.period_id = ps.period_id) AND (tc.core_student_id = ps.core_student_id))));

create or replace view public.v_weekly_penalties_core_shadow with(security_invoker=true) as  SELECT s.id AS student_id,
    pr.core_student_id,
    (date_trunc('week'::text, (pr.recorded_at)::timestamp without time zone))::date AS week_start,
    (sum(pr.points))::integer AS penalty_points,
    (count(*))::integer AS record_count
   FROM (point_records pr
     JOIN students s ON ((s.core_student_id = pr.core_student_id)))
  WHERE ((pr.type = 'NEGATIVE'::point_type) AND (pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL))
  GROUP BY s.id, pr.core_student_id, ((date_trunc('week'::text, (pr.recorded_at)::timestamp without time zone))::date);

create or replace view public.v_weekly_scores_core_shadow with(security_invoker=true) as  SELECT s.id AS student_id,
    pr.core_student_id,
    (date_trunc('week'::text, (pr.recorded_at)::timestamp without time zone))::date AS week_start,
    (COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'POSITIVE'::point_type)), (0)::bigint))::integer AS positive_points,
    (COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint))::integer AS negative_points,
    ((COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint) - COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'POSITIVE'::point_type)), (0)::bigint)))::integer AS net_penalty_points,
    (COALESCE(count(*) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint))::integer AS penalty_incident_count,
    ((COALESCE(count(*) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint) >= 3) OR ((COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint) - COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'POSITIVE'::point_type)), (0)::bigint)) >= 8)) AS physical_training_required
   FROM (point_records pr
     JOIN students s ON ((s.core_student_id = pr.core_student_id)))
  WHERE (pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL)
  GROUP BY s.id, pr.core_student_id, ((date_trunc('week'::text, (pr.recorded_at)::timestamp without time zone))::date);

create or replace view public.v_student_summary_core_shadow with(security_invoker=true) as  WITH lifetime AS (
         SELECT ds_1.core_student_id,
            (COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'POSITIVE'::point_type)), (0)::bigint))::integer AS positive_points,
            (COALESCE(sum(pr.points) FILTER (WHERE (pr.type = 'NEGATIVE'::point_type)), (0)::bigint))::integer AS negative_points
           FROM (v_discipline_students ds_1
             LEFT JOIN point_records pr ON (((pr.core_student_id = ds_1.core_student_id) AND (pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL))))
          GROUP BY ds_1.core_student_id
        ), weekly AS (
         SELECT ws.core_student_id,
            ws.positive_points,
            ws.negative_points,
            ws.net_penalty_points,
            ws.penalty_incident_count,
            ws.physical_training_required
           FROM v_weekly_scores_core_shadow ws
          WHERE (ws.week_start = private.kst_week_start())
        ), settlement AS (
         SELECT ss.core_student_id,
            ss.period_id,
            ss.period_label,
            ss.starts_on,
            ss.positive_points,
            ss.negative_points,
            ss.net_penalty_points,
            ss.physical_training_weeks,
            ss.committee_required
           FROM v_settlement_scores_core_shadow ss
          WHERE ss.is_open
        ), refl AS (
         SELECT pr.core_student_id,
            bool_or(((NOT r_1.submitted) AND (r_1.due_at >= now()))) AS has_missing,
            bool_or(((NOT r_1.submitted) AND (r_1.due_at < now()))) AS has_double
           FROM (reflection_records r_1
             JOIN point_records pr ON (((pr.id = r_1.point_record_id) AND (pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL))))
          GROUP BY pr.core_student_id
        ), active_pun AS (
         SELECT DISTINCT ON (p.core_student_id) p.core_student_id,
            p.types,
            p.violated_at
           FROM punishments p
          WHERE ((p.start_date <= private.kst_today()) AND (p.end_date >= private.kst_today()))
          ORDER BY p.core_student_id, p.start_date DESC, p.id DESC
        ), weeks3 AS (
         SELECT wp.core_student_id,
            (count(*))::integer AS qualifying_weeks
           FROM v_weekly_penalties_core_shadow wp
          WHERE ((wp.week_start = ANY (ARRAY[private.kst_week_start(), (private.kst_week_start() - 7), (private.kst_week_start() - 14)])) AND (wp.penalty_points >= 5))
          GROUP BY wp.core_student_id
        )
 SELECT ds.legacy_student_id AS id,
    ds.name,
    ds.grade,
    ls.created_at,
    ls.updated_at,
    COALESCE(lt.positive_points, 0) AS positive_points,
    COALESCE(lt.negative_points, 0) AS negative_points,
    COALESCE(w.negative_points, 0) AS weekly_penalty_points,
    COALESCE(st.negative_points, 0) AS monthly_penalty_points,
    COALESCE(w.penalty_incident_count, 0) AS weekly_record_count,
        CASE
            WHEN (ap.core_student_id IS NOT NULL) THEN array_to_string(ap.types, ', '::text)
            ELSE NULL::text
        END AS punishment,
    (array_remove(ARRAY[
        CASE
            WHEN COALESCE(w.physical_training_required, false) THEN '체력훈련 대상'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(st.committee_required, false) THEN '징계위원회 대상'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(r.has_missing, false) THEN '반성문 미제출'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(r.has_double, false) THEN '반성문 2배 제출 대상'::text
            ELSE NULL::text
        END,
        CASE
            WHEN ((COALESCE(w.negative_points, 0) >= 5) AND (ap.core_student_id IS NULL)) THEN '처분 선택 필요'::text
            ELSE NULL::text
        END,
        CASE
            WHEN (COALESCE(w3.qualifying_weeks, 0) >= 3) THEN '귀가금지 조건 충족'::text
            ELSE NULL::text
        END], NULL::text) ||
        CASE
            WHEN (ap.core_student_id IS NULL) THEN ARRAY[]::text[]
            WHEN (ap.violated_at IS NOT NULL) THEN ARRAY['귀가금지'::text]
            ELSE ap.types
        END) AS statuses,
    ds.core_student_id,
    ds.student_no,
    ds.homeroom,
    COALESCE(w.positive_points, 0) AS weekly_positive_points,
    COALESCE(w.net_penalty_points, 0) AS weekly_net_penalty_points,
    COALESCE(w.physical_training_required, false) AS physical_training_required,
    st.period_id AS settlement_period_id,
    st.period_label AS settlement_period_label,
    st.starts_on AS settlement_starts_on,
    COALESCE(st.positive_points, 0) AS settlement_positive_points,
    COALESCE(st.negative_points, 0) AS settlement_penalty_points,
    COALESCE(st.net_penalty_points, 0) AS settlement_net_penalty_points,
    COALESCE(st.physical_training_weeks, 0) AS physical_training_weeks,
    COALESCE(st.committee_required, false) AS committee_required
   FROM (((((((v_discipline_students ds
     JOIN students ls ON ((ls.id = ds.legacy_student_id)))
     LEFT JOIN lifetime lt ON ((lt.core_student_id = ds.core_student_id)))
     LEFT JOIN weekly w ON ((w.core_student_id = ds.core_student_id)))
     LEFT JOIN settlement st ON ((st.core_student_id = ds.core_student_id)))
     LEFT JOIN refl r ON ((r.core_student_id = ds.core_student_id)))
     LEFT JOIN active_pun ap ON ((ap.core_student_id = ds.core_student_id)))
     LEFT JOIN weeks3 w3 ON ((w3.core_student_id = ds.core_student_id)));

create or replace view public.v_department_merit_status with(security_invoker=true) as  WITH current_week AS (
         SELECT private.kst_week_start() AS week_start
        )
 SELECT cw.week_start,
    d.id AS department_id,
    d.code AS department_code,
    d.name AS department_name,
    m.id AS membership_id,
    m.student_id AS core_student_id,
    cs.student_no,
    cs.name AS student_name,
    (c.grade)::integer AS grade,
    c.label AS homeroom,
    r.points,
    r.item_label,
    pr.id AS point_record_id,
    (pr.id IS NOT NULL) AS generated
   FROM ((((((((current_week cw
     JOIN core.department_memberships m ON (((m.starts_on <= cw.week_start) AND ((m.ends_on IS NULL) OR (m.ends_on >= cw.week_start)))))
     JOIN core.departments d ON (((d.id = m.department_id) AND d.is_active)))
     JOIN discipline.department_merit_rules r ON (((r.department_id = d.id) AND r.is_active AND (r.effective_from <= cw.week_start) AND ((r.effective_to IS NULL) OR (r.effective_to >= cw.week_start)))))
     JOIN core.students cs ON (((cs.id = m.student_id) AND cs.is_active)))
     LEFT JOIN core.academic_terms t ON (t.is_current))
     LEFT JOIN core.enrollments e ON (((e.student_id = cs.id) AND (e.term_id = t.id) AND (e.left_at IS NULL))))
     LEFT JOIN core.classes c ON ((c.id = e.class_id)))
     LEFT JOIN point_records pr ON ((pr.source_key = ((('department-weekly:'::text || (m.id)::text) || ':'::text) || (cw.week_start)::text))))
  ORDER BY d.name, cs.name;

create or replace view public.v_point_records with(security_invoker=true) as  SELECT pr.id,
    s.id AS student_id,
    s.name AS student_name,
    pr.type,
    pr.item,
    pr.points,
    pr.recorded_at,
    pr.entered_by_name,
    pr.created_at,
    r.id AS reflection_id,
    r.submitted AS reflection_submitted,
    r.submission_deadline AS reflection_deadline,
    r.submitted_at AS reflection_submitted_at,
        CASE
            WHEN (r.id IS NULL) THEN NULL::text
            WHEN r.submitted THEN 'SUBMITTED'::text
            WHEN (r.due_at < now()) THEN 'DOUBLE'::text
            ELSE 'MISSING'::text
        END AS reflection_status,
    r.due_at AS reflection_due_at,
    pr.core_student_id
   FROM ((point_records pr
     JOIN students s ON ((s.core_student_id = pr.core_student_id)))
     LEFT JOIN reflection_records r ON ((r.point_record_id = pr.id)))
  WHERE (pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL);

create function private.activate_discipline_history(p_term_id uuid,p_batch_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_settings discipline.history_settings%rowtype; v_term core.academic_terms%rowtype; v_count int; v_period bigint;
begin
 if auth.uid() is null or not private.current_admin_is_lead() then raise exception '선도부장 권한이 필요합니다.'; end if;
 select * into v_settings from discipline.history_settings where term_id=p_term_id for update;
 select * into v_term from core.academic_terms where id=p_term_id;
 if not found or v_settings.term_id is null or not exists(select 1 from discipline.history_import_batches where id=p_batch_id and term_id=p_term_id) then raise exception '학기·이관 배치를 확인하세요.'; end if;
 if v_settings.activated_at is not null then return jsonb_build_object('already_active',true); end if;
 if exists(select 1 from generate_series(date_trunc('week',v_term.starts_on::timestamp),v_settings.daily_starts_on-7,interval '1 week') w where not exists(select 1 from discipline.history_calendar c where c.term_id=p_term_id and c.week_start=w::date)) then raise exception '확정 주차 또는 비운영 주차가 누락됐습니다.'; end if;
 update public.point_records pr set superseded_by_import_id=p_batch_id
 where pr.superseded_by_import_id is null and pr.recorded_at>=v_term.starts_on and pr.recorded_at<v_settings.daily_starts_on
 and exists(select 1 from public.students s where s.core_student_id=pr.core_student_id and s.grade between v_settings.min_grade and v_settings.max_grade);
 get diagnostics v_count=row_count;
 update discipline.history_settings set activated_at=now(),activated_by=auth.uid() where term_id=p_term_id;
 select id into v_period from public.settlement_periods where ends_on is null for update;
 if v_period is not null then
   if (select starts_on from public.settlement_periods where id=v_period)<v_settings.daily_starts_on then
    update public.settlement_periods set ends_on=v_settings.daily_starts_on-1,closed_at=now(),closed_by=auth.uid() where id=v_period;
    v_period:=null;
   end if;
 end if;
 if v_period is null then insert into public.settlement_periods(label,starts_on,created_by) values(to_char(v_settings.daily_starts_on,'YYYY-MM-DD')||' 일별 기록 정산',v_settings.daily_starts_on,auth.uid()) returning id into v_period; end if;
 return jsonb_build_object('superseded_records',v_count,'settlement_period_id',v_period,'daily_starts_on',v_settings.daily_starts_on);
end $$;
revoke all on function private.activate_discipline_history(uuid,uuid) from public,anon;
grant execute on function private.activate_discipline_history(uuid,uuid) to authenticated;
create function public.activate_discipline_history(p_term_id uuid,p_batch_id uuid) returns jsonb language sql security invoker set search_path='' as $$select private.activate_discipline_history(p_term_id,p_batch_id)$$;
revoke all on function public.activate_discipline_history(uuid,uuid) from public,anon;
grant execute on function public.activate_discipline_history(uuid,uuid) to authenticated;

create function private.guard_discipline_history_cutover() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and old.superseded_by_import_id is not null then raise exception '주간 확정 원장으로 대체된 기록입니다. 원본은 감사용으로 보존합니다.'; end if;
 if exists(select 1 from discipline.history_settings h join core.academic_terms t on t.id=h.term_id join public.students s on s.core_student_id=new.core_student_id where h.activated_at is not null and s.grade between h.min_grade and h.max_grade and new.recorded_at>=t.starts_on and new.recorded_at<h.daily_starts_on) then raise exception '이 기간은 주간 확정 원장으로 관리합니다. 일별 입력은 전환일 이후만 가능합니다.'; end if;
 if new.recorded_at>private.kst_today() then raise exception '미래 날짜로 점수를 입력할 수 없습니다.'; end if;
 return new;
end $$;
revoke all on function private.guard_discipline_history_cutover() from public,anon,authenticated;
create trigger point_records_history_cutover before insert or update on public.point_records for each row execute function private.guard_discipline_history_cutover();

-- Old clients retain the RPC name but receive the new extension policy too.
create or replace function public.extend_reflection_to_21(p_reflection_id int,p_reason text) returns timestamptz language sql security invoker set search_path='' as $$ select public.extend_reflection_to_next_day(p_reflection_id,p_reason) $$;

create index history_aliases_student_idx on discipline.history_aliases(core_student_id);
create index history_batches_actor_idx on discipline.history_import_batches(created_by);
create index history_settings_actor_idx on discipline.history_settings(activated_by);

create function private.discipline_import_status() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_term uuid;
begin
 if auth.uid() is null or not private.current_admin_is_lead() then raise exception '선도부장 권한이 필요합니다.'; end if;
 select id into v_term from core.academic_terms where is_current limit 1;
 return jsonb_build_object(
 'settings',(select to_jsonb(h) from discipline.history_settings h where term_id=v_term),
 'aliases',coalesce((select jsonb_agg(to_jsonb(a)) from discipline.history_aliases a where term_id=v_term),'[]'),
 'batches',coalesce((select jsonb_agg(to_jsonb(b) order by b.created_at desc) from (
   select b.id,b.source_label,b.created_at,
   (select count(*) from discipline.history_source_rows r where r.batch_id=b.id) source_rows,
   (select count(*) from discipline.history_source_rows r where r.batch_id=b.id and r.core_student_id is null) unlinked,
   (select count(*) from discipline.weekly_balances w where w.batch_id=b.id and w.is_current) current_balances
   from discipline.history_import_batches b where b.term_id=v_term order by b.created_at desc limit 50) b),'[]'),
 'unlinked',coalesce((select jsonb_agg(to_jsonb(u)) from (
   select distinct r.source_name,r.grade,r.section,r.week_start,r.positive_points,r.negative_points from discipline.history_source_rows r
   join discipline.history_import_batches b on b.id=r.batch_id where b.term_id=v_term and r.core_student_id is null
   and exists(select 1 from discipline.weekly_balances w where w.batch_id=b.id and w.week_start=r.week_start and w.is_current))u),'[]'));
end $$;
revoke all on function private.discipline_import_status() from public,anon;
grant execute on function private.discipline_import_status() to authenticated;
create function public.get_discipline_import_status() returns jsonb language sql security invoker set search_path='' as $$ select private.discipline_import_status() $$;
revoke all on function public.get_discipline_import_status() from public,anon;
grant execute on function public.get_discipline_import_status() to authenticated;

-- Automatic grants respect the history boundary and concurrent retries.
create or replace function public.ensure_weekly_department_merits(
  p_week_start date default private.kst_week_start()
)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_inserted int := 0;
begin
  if private.current_admin_role() is distinct from 'SEONDO' then
    raise exception '선도부 관리자만 부서활동 주간 상점을 생성할 수 있습니다.';
  end if;

  if p_week_start <> date_trunc('week', p_week_start::timestamp)::date then
    raise exception '주 시작일은 월요일이어야 합니다.';
  end if;

  insert into public.point_records (
    core_student_id,
    type,
    item,
    points,
    entered_by_name,
    recorded_at,
    source_type,
    source_key
  )
  select
    m.student_id,
    'POSITIVE'::public.point_type,
    r.item_label,
    r.points,
    'SYSTEM · DEPARTMENT',
    p_week_start,
    'DEPARTMENT_WEEKLY',
    'department-weekly:' || m.id::text || ':' || p_week_start::text
  from core.department_memberships m
  join core.departments d
    on d.id = m.department_id
   and d.is_active
  join discipline.department_merit_rules r
    on r.department_id = m.department_id
   and r.is_active
   and r.effective_from <= p_week_start
   and (r.effective_to is null or r.effective_to >= p_week_start)
  join public.v_discipline_students ds
    on ds.core_student_id = m.student_id
  where m.starts_on <= p_week_start
    and (m.ends_on is null or m.ends_on >= p_week_start)
    and not exists (select 1 from discipline.history_settings h join core.academic_terms t on t.id=h.term_id where h.activated_at is not null and p_week_start+6>=t.starts_on and p_week_start<h.daily_starts_on and ds.grade between h.min_grade and h.max_grade)
    and not exists (
      select 1
      from public.point_records pr
      where pr.source_key = 'department-weekly:' || m.id::text || ':' || p_week_start::text
    )
  on conflict (source_key) where source_key is not null do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

