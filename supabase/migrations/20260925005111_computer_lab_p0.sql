-- Prepared migration: apply ONLY to the selected central student database.
-- This module never creates or copies a student roster.
-- Required central contract: core.students(id UUID, auth_user_id UUID UNIQUE,
-- student_no TEXT UNIQUE, name TEXT, is_active boolean), plus
-- public.v_core_current_students for the current enrollment/grade projection.
begin;
do $$
begin
 if to_regclass('core.students') is null then
  raise exception 'Central roster core.students is missing. Complete the central identity mapping first; do not create a module-local roster.';
 end if;
 if (select count(*) from information_schema.columns where table_schema='core' and table_name='students'
     and column_name in ('id','auth_user_id','student_no','name','is_active'))<>5 then
  raise exception 'Central student contract differs. Review the integration adapter before applying this migration.';
 end if;
 if to_regclass('public.v_core_current_students') is null then
  raise exception 'Central current-enrollment projection is missing.';
 end if;
end $$;

create schema if not exists computer_lab;
create table computer_lab.server_keys (
 id text primary key,
 token_hash text not null unique check(token_hash ~ '^[a-f0-9]{64}$'),
 enabled boolean not null default true,
 created_at timestamptz not null default now()
);
create table computer_lab.admins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check(length(display_name) between 1 and 60)
);
create table computer_lab.devices (
 id text primary key check(id ~ '^[A-Z0-9-]{3,40}$'),
 label text not null check(length(label) between 2 and 60),
 device_group text not null check(device_group in ('lab','media','laptop')),
 ownership text not null check(ownership in ('school','personal')),
 enabled boolean not null default true,
 created_at timestamptz not null default now()
);
insert into computer_lab.devices(id,label,device_group,ownership)
select 'PC-'||lpad(i::text,2,'0'),i||'번 PC','lab','school' from generate_series(1,24) i;

create table computer_lab.browser_sessions (
 token_hash text primary key check(token_hash ~ '^[a-f0-9]{64}$'),
 owner_id uuid not null references auth.users(id) on delete cascade,
 role text not null check(role in ('admin','kiosk')),
 device_id text references computer_lab.devices(id),
 expires_at timestamptz not null,
 created_at timestamptz not null default now()
);
create index browser_sessions_expiry on computer_lab.browser_sessions(expires_at);
create index browser_sessions_owner on computer_lab.browser_sessions(owner_id);
create index browser_sessions_device on computer_lab.browser_sessions(device_id) where role='kiosk';
create table computer_lab.visits (
 id uuid primary key,
 student_id uuid not null references core.students(id) on delete restrict,
 student_no text not null,
 student_name text not null,
 grade text not null,
 device_id text not null references computer_lab.devices(id),
 purpose text not null check(length(purpose) between 2 and 300),
 internet text not null check(length(internet) between 1 and 300),
 supervisor text not null check(length(supervisor) between 1 and 60),
 started_at timestamptz not null default now(),
 ended_at timestamptz,
 reviewed_at timestamptz,
 reviewed_by text,
 close_reason text,
 notice_version text not null,
 notice_acknowledged_at timestamptz not null default now(),
 check(ended_at is null or ended_at>=started_at)
);
create unique index visits_one_active_student on computer_lab.visits(student_id) where ended_at is null;
create unique index visits_one_active_device on computer_lab.visits(device_id) where ended_at is null;
create index visits_started on computer_lab.visits(started_at desc,id desc);
create index visits_student_started on computer_lab.visits(student_id,started_at desc);
create index visits_device_started on computer_lab.visits(device_id,started_at desc);
create table computer_lab.audits (
 id bigint generated always as identity primary key,
 visit_id uuid references computer_lab.visits(id),
 actor_id uuid not null,
 action text not null,
 detail text not null,
 created_at timestamptz not null default now()
);
create index audits_visit on computer_lab.audits(visit_id,created_at);
create table computer_lab.rate_limits (
 key_hash text not null check(key_hash ~ '^[a-f0-9]{64}$'),
 bucket bigint not null,
 attempts integer not null,
 primary key(key_hash,bucket)
);
create index rate_limits_bucket on computer_lab.rate_limits(bucket);
create table computer_lab.revision (id integer primary key check(id=1),value bigint not null);
insert into computer_lab.revision values(1,1);

-- Browser clients have no direct table access, even if authenticated in another app.
alter table computer_lab.server_keys enable row level security;
alter table computer_lab.admins enable row level security;
alter table computer_lab.devices enable row level security;
alter table computer_lab.browser_sessions enable row level security;
alter table computer_lab.visits enable row level security;
alter table computer_lab.audits enable row level security;
alter table computer_lab.rate_limits enable row level security;
alter table computer_lab.revision enable row level security;
revoke all on schema computer_lab from public,anon,authenticated;
revoke all on all tables in schema computer_lab from public,anon,authenticated,service_role;
revoke all on all sequences in schema computer_lab from public,anon,authenticated,service_role;

create function computer_lab.visit_json(v computer_lab.visits) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('id',v.id,'student_id',v.student_id,'student_no',v.student_no,
 'name',v.student_name,'grade',v.grade,'device_id',v.device_id,
 'device_group',(select d.device_group from computer_lab.devices d where d.id=v.device_id),
 'purpose',v.purpose,'internet',v.internet,'supervisor',v.supervisor,
 'started',v.started_at,'ended',v.ended_at,'reviewed',v.reviewed_at,'reviewed_by',v.reviewed_by,
 'close_reason',v.close_reason,'notice_version',v.notice_version)
$$;
revoke all on function computer_lab.visit_json(computer_lab.visits) from public,anon,authenticated;

-- Only the scoped Netlify server key can authorize this RPC. Caller-supplied
-- Auth IDs are accepted after that server performs Supabase authentication.
create function public.dics_device_rpc(p_action text,p_session text,p_body jsonb,p_server_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 s computer_lab.browser_sessions%rowtype;
 pupil record;
 pupil_grade integer;
 v computer_lab.visits%rowtype;
 admin_name text;
 device text;
 result jsonb;
 start_time timestamptz;
 finish_time timestamptz;
 page_no integer;
 total_count bigint;
 window_no bigint;
 tries integer;
 changed boolean:=false;
begin
 if p_server_key is null or p_server_key !~ '^[a-f0-9]{64}$' or not exists(
  select 1 from computer_lab.server_keys k where k.enabled
    and k.token_hash=encode(sha256(convert_to(p_server_key,'utf8')),'hex')
 ) then return jsonb_build_object('error','서버 연결 인증이 필요합니다.','status',403);end if;
 select * into s from computer_lab.browser_sessions where token_hash=p_session and expires_at>now();
 if s.token_hash is not null and not exists(select 1 from computer_lab.admins a where a.user_id=s.owner_id) then
  delete from computer_lab.browser_sessions where token_hash=s.token_hash;
  s:=null;
 end if;
 if s.role='admin' then select display_name into admin_name from computer_lab.admins where user_id=s.owner_id;end if;

 if p_action='rate' then
  window_no:=floor(extract(epoch from now())/900);
  delete from computer_lab.rate_limits where bucket<window_no-96;
  insert into computer_lab.rate_limits as r(key_hash,bucket,attempts) values(p_body->>'key',window_no,1)
   on conflict(key_hash,bucket) do update set attempts=r.attempts+1 returning attempts into tries;
  if tries>(p_body->>'limit')::integer then return jsonb_build_object('error','인증 시도 횟수를 초과했습니다. 15분 후 다시 시도해 주세요.','status',429);end if;
  return jsonb_build_object('ok',true);
 end if;
 if p_action='create_admin_session' then
  if not exists(select 1 from computer_lab.admins where user_id=(p_body->>'userId')::uuid) then
   return jsonb_build_object('error','기기 관리 권한이 없는 계정입니다.','status',403);
  end if;
  delete from computer_lab.browser_sessions where expires_at<=now() or token_hash=p_session;
  insert into computer_lab.browser_sessions(token_hash,owner_id,role,expires_at)
   values(p_body->>'tokenHash',(p_body->>'userId')::uuid,'admin',now()+interval '1 hour');
  return jsonb_build_object('ok',true);
 end if;
 if p_action='status' then
  return jsonb_build_object('configured',true,'centralReady',true,'role',s.role,'boundDevice',s.device_id,
   'revision',(select value::text from computer_lab.revision where id=1),
   'devices',case when s.role is null then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object(
     'id',id,'label',label,'group',device_group,'enabled',enabled,'ownership',ownership) order by device_group,id)
     from computer_lab.devices where enabled and (s.role='admin' or s.device_id is null or id=s.device_id)),'[]'::jsonb) end,
   'occupied',case when s.role is null then '[]'::jsonb else coalesce((select jsonb_agg(device_id order by device_id)
     from computer_lab.visits where ended_at is null and (s.role='admin' or s.device_id is null or device_id=s.device_id)),'[]'::jsonb) end);
 end if;
 if p_action='lock' then
  delete from computer_lab.browser_sessions where token_hash=p_session;
  return jsonb_build_object('ok',true);
 end if;
 if s.token_hash is null then return jsonb_build_object('error','관리자 로그인 또는 이 기기의 입력 연결이 필요합니다.','status',403);end if;

 if p_action in ('authorize_device','checkin','checkout') then
  device:=p_body->>'deviceId';
  if not exists(select 1 from computer_lab.devices d where d.id=device and d.enabled)
     or (s.role='kiosk' and s.device_id is not null and s.device_id<>device) then
   return jsonb_build_object('error','이 입력 화면에 연결된 기기를 사용해 주세요.','status',403);
  end if;
  if p_action='authorize_device' then return jsonb_build_object('ok',true);end if;
  select id,student_no,name,is_active into pupil from core.students where auth_user_id=(p_body->>'authUserId')::uuid and is_active;
  if pupil.id is null or pupil.student_no is null or lower(pupil.student_no)<>lower(p_body->>'studentNo') then
   return jsonb_build_object('error','중앙 명부에 등록된 활성 학생 계정인지 확인해 주세요.','status',403);
  end if;
  select grade into pupil_grade from public.v_core_current_students where student_id=pupil.id;
  if p_action='checkin' then
   if p_body->>'noticeVersion'<>'2026-09-24-p0' or p_body->>'noticeVersion' is null then
    return jsonb_build_object('error','현재 기록 안내를 확인해 주세요.','status',400);
   end if;
   -- Serialize retries of the same request, then use unique constraints for
   -- independent requests competing for one student or device.
   perform pg_advisory_xact_lock(hashtextextended(p_body->>'requestId',0));
   select * into v from computer_lab.visits where id=(p_body->>'requestId')::uuid;
   if v.id is not null then
    if v.student_id<>pupil.id or v.device_id<>device or v.purpose<>p_body->>'purpose'
      or v.internet<>p_body->>'internet' or v.supervisor<>p_body->>'supervisor' then
     return jsonb_build_object('error','기존 요청과 입력 내용이 다릅니다. 입력을 다시 시작해 주세요.','status',409);
    end if;
    return jsonb_build_object('ok',true);
   end if;
   begin
    insert into computer_lab.visits(id,student_id,student_no,student_name,grade,device_id,purpose,internet,supervisor,notice_version)
    values((p_body->>'requestId')::uuid,pupil.id,pupil.student_no,pupil.name,coalesce('G'||pupil_grade,'학년 미등록'),device,p_body->>'purpose',p_body->>'internet',p_body->>'supervisor',p_body->>'noticeVersion') returning * into v;
   exception when unique_violation then
    return jsonb_build_object('error','이미 입실한 학생이거나 사용 중인 기기입니다. 퇴실 기록을 확인해 주세요.','status',409);
   end;
   insert into computer_lab.audits(visit_id,actor_id,action,detail) values(v.id,pupil.id,'checkin','학생 입력 · 기록 안내 확인');
  else
   update computer_lab.visits set ended_at=now() where student_id=pupil.id and device_id=device and ended_at is null returning * into v;
   if v.id is null then return jsonb_build_object('error','이 학생과 기기의 입실 기록이 없습니다.','status',404);end if;
   insert into computer_lab.audits(visit_id,actor_id,action,detail) values(v.id,pupil.id,'checkout','학생 퇴실 입력');
  end if;
  update computer_lab.revision set value=value+1 where id=1;
  return jsonb_build_object('ok',true);
 end if;
 if admin_name is null then return jsonb_build_object('error','관리자 인증이 필요합니다.','status',403);end if;

 if p_action='kiosk' then
  device:=p_body->>'deviceId';
  if device is not null and not exists(select 1 from computer_lab.devices where id=device and enabled) then
   return jsonb_build_object('error','등록된 기기를 선택해 주세요.','status',400);
  end if;
  insert into computer_lab.browser_sessions(token_hash,owner_id,role,device_id,expires_at)
   values(p_body->>'tokenHash',s.owner_id,'kiosk',device,now()+interval '14 days');
  delete from computer_lab.browser_sessions where token_hash=p_session;
  insert into computer_lab.audits(actor_id,action,detail) values(s.owner_id,'kiosk',coalesce(device,'입구 공용 입력'));
  return jsonb_build_object('ok',true);
 end if;
 if p_action='revoke_kiosks' then
  delete from computer_lab.browser_sessions where role='kiosk' and device_id is not distinct from p_body->>'deviceId';
  insert into computer_lab.audits(actor_id,action,detail) values(s.owner_id,'revoke_kiosks',coalesce(p_body->>'deviceId','입구 공용 입력'));
  return jsonb_build_object('ok',true);
 end if;
 if p_action='add_device' then
  if p_body->>'group' not in ('media','laptop') or (select count(*) from computer_lab.devices)>=500 then
   return jsonb_build_object('error','기기 그룹 또는 등록 한도를 확인해 주세요.','status',400);
  end if;
  begin
   insert into computer_lab.devices(id,label,device_group,ownership) values(p_body->>'id',p_body->>'label',p_body->>'group',p_body->>'ownership');
  exception when unique_violation then return jsonb_build_object('error','이미 등록된 기기 ID입니다.','status',409);end;
  insert into computer_lab.audits(actor_id,action,detail) values(s.owner_id,'add_device',p_body->>'id');
  update computer_lab.revision set value=value+1 where id=1;
  return jsonb_build_object('ok',true);
 end if;
 if p_action in ('review','close') then
  select * into v from computer_lab.visits where id=(p_body->>'id')::uuid for update;
  if v.id is null then return jsonb_build_object('error','기록이 없습니다.','status',404);end if;
  if p_action='review' and v.reviewed_at is null then
   update computer_lab.visits set reviewed_at=now(),reviewed_by=admin_name where id=v.id;
   insert into computer_lab.audits(visit_id,actor_id,action,detail) values(v.id,s.owner_id,'review','관리자 확인');changed:=true;
  elsif p_action='close' and v.ended_at is null then
   if length(trim(coalesce(p_body->>'reason','')))<2 then return jsonb_build_object('error','종료 사유를 입력해 주세요.','status',400);end if;
   update computer_lab.visits set ended_at=now(),close_reason=p_body->>'reason' where id=v.id;
   insert into computer_lab.audits(visit_id,actor_id,action,detail) values(v.id,s.owner_id,'close',p_body->>'reason');changed:=true;
  end if;
  if changed then update computer_lab.revision set value=value+1 where id=1;end if;
  return jsonb_build_object('ok',true);
 end if;
 if p_action='student' then
  start_time:=now()-interval '30 days';
  select count(*) into total_count from computer_lab.visits where student_id=(p_body->>'studentId')::uuid and started_at>=start_time;
  select coalesce(jsonb_agg(computer_lab.visit_json(t) order by t.started_at desc,t.id desc),'[]'::jsonb) into result
   from (select * from computer_lab.visits where student_id=(p_body->>'studentId')::uuid and started_at>=start_time order by started_at desc,id desc limit 100) t;
  insert into computer_lab.audits(actor_id,action,detail) values(s.owner_id,'student_history',p_body->>'studentId');
  return jsonb_build_object('records',result,'total',total_count,'truncated',total_count>100,'periodDays',30,
   'integration',jsonb_build_object('identity','central_student_id','studyProgress','not_connected','points','not_connected'));
 end if;
 if p_action='dashboard' then
  start_time:=(p_body->>'date')::date::timestamp at time zone 'Asia/Seoul';finish_time:=start_time+interval '1 day';
  page_no:=greatest(0,least(10000,coalesce((p_body->>'page')::integer,0)));
  select count(*) into total_count from computer_lab.visits where started_at>=start_time and started_at<finish_time;
  select coalesce(jsonb_agg(computer_lab.visit_json(t) order by t.started_at desc,t.id desc),'[]'::jsonb) into result
   from (select * from computer_lab.visits where started_at>=start_time and started_at<finish_time order by started_at desc,id desc limit 50 offset page_no*50) t;
  return jsonb_build_object('records',result,'total',total_count,'page',page_no,'pageSize',50,'truncated',total_count>50,'serverTime',now(),
   'unreviewed',(select count(*) from computer_lab.visits where started_at>=start_time and started_at<finish_time and reviewed_at is null),
   'active',coalesce((select jsonb_agg(computer_lab.visit_json(t) order by t.started_at) from computer_lab.visits t where t.ended_at is null),'[]'::jsonb));
 end if;
 return jsonb_build_object('error','지원하지 않는 요청입니다.','status',400);
end $$;
revoke all on function public.dics_device_rpc(text,text,jsonb,text) from public,anon,authenticated;
-- The public key alone grants no access: the scoped server key is checked before every action.
grant execute on function public.dics_device_rpc(text,text,jsonb,text) to anon,authenticated;
comment on schema computer_lab is 'DICS 기기 사용 기록. 중앙 core.students 참조; 자체 명부 없음. P0: 자가 신고 입퇴실만 기록.';
commit;
