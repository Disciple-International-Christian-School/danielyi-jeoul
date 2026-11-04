-- Shared staff identities and class assignments. Operational identity data is seeded outside Git.
create table core.staff_accounts (
 id uuid primary key default gen_random_uuid(), display_name text not null,
 login_emails text[] not null, is_active boolean not null default true
);
create table core.homeroom_staff (
 class_id uuid references core.classes(id), staff_id uuid references core.staff_accounts(id),
 primary key(class_id,staff_id)
);
alter table core.staff_accounts enable row level security;
alter table core.homeroom_staff enable row level security;
revoke all on core.staff_accounts,core.homeroom_staff from anon,authenticated;

create function private.current_homeroom_staff() returns uuid language sql stable security definer set search_path='' as $$
 select s.id from core.staff_accounts s join auth.users u on u.id=auth.uid()
 where s.is_active and u.email_confirmed_at is not null and lower(u.email)=any(s.login_emails) limit 1
$$;
revoke all on function private.current_homeroom_staff() from public;

create table private.web_push_config (
 id boolean primary key default true check(id), public_key text not null,
 private_key text not null, dispatch_token text not null
);
create table private.web_push_subscriptions (
 id uuid primary key default gen_random_uuid(), staff_id uuid not null references core.staff_accounts,
 user_id uuid not null references auth.users, endpoint text not null unique, p256dh text not null, auth text not null,
 enabled_at timestamptz not null default now(), active boolean not null default true
);
create table private.reflection_push_events (
 reflection_id text, kind text, observed_at timestamptz not null default now(), primary key(reflection_id,kind)
);
create table private.web_push_deliveries (
 id uuid primary key default gen_random_uuid(), subscription_id uuid not null references private.web_push_subscriptions,
 reflection_id text, kind text not null, created_at timestamptz not null default now(),
 state text not null default 'PENDING' check(state in ('PENDING','SENT','CANCELLED','FAILED')),
 attempts int not null default 0, retry_at timestamptz not null default now(), last_code int,
 unique(subscription_id,reflection_id,kind)
);
alter table private.web_push_config enable row level security;
alter table private.web_push_subscriptions enable row level security;
alter table private.reflection_push_events enable row level security;
alter table private.web_push_deliveries enable row level security;
revoke all on private.web_push_config,private.web_push_subscriptions,private.reflection_push_events,private.web_push_deliveries from public,anon,authenticated;

create function public.homeroom_portal() returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.current_homeroom_staff(); result jsonb;
begin
 if sid is null then raise exception '등록된 담임 계정으로 로그인해주세요.' using errcode='42501'; end if;
 select jsonb_build_object('name',s.display_name,'classes',(
 select coalesce(jsonb_agg(c.label order by c.grade,c.section),'[]') from core.homeroom_staff h join core.classes c on c.id=h.class_id join core.academic_terms t on t.id=c.term_id and t.is_current where h.staff_id=sid),
 'publicKey',(select public_key from private.web_push_config),
 'reflections',(select coalesce(jsonb_agg(x order by x.recorded_at desc),'[]') from (
 select distinct r.id,r.student_name,r.item,r.recorded_at,r.status,r.submitted,r.due_at,c.label as homeroom
 from public.v_reflections r join core.enrollments e on e.student_id=r.core_student_id and e.left_at is null
 join core.classes c on c.id=e.class_id join core.academic_terms t on t.id=c.term_id and t.is_current
 join core.homeroom_staff h on h.class_id=c.id and h.staff_id=sid
 ) x)) into result from core.staff_accounts s where s.id=sid;
 return result;
end $$;
revoke all on function public.homeroom_portal() from public;
grant execute on function public.homeroom_portal() to authenticated;

create function public.register_homeroom_push(p_subscription jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.current_homeroom_staff(); subid uuid; ep text:=p_subscription->>'endpoint';
begin
 if sid is null then raise exception '담임 권한이 필요합니다.' using errcode='42501'; end if;
 if ep !~ '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com)/' or length(ep)>2048
 or coalesce(p_subscription#>>'{keys,p256dh}','') !~ '^[A-Za-z0-9_-]{87,88}$'
 or coalesce(p_subscription#>>'{keys,auth}','') !~ '^[A-Za-z0-9_-]{22,24}$' then raise exception '올바른 푸시 구독이 아닙니다.'; end if;
 insert into private.web_push_subscriptions(staff_id,user_id,endpoint,p256dh,auth)
 values(sid,auth.uid(),ep,p_subscription#>>'{keys,p256dh}',p_subscription#>>'{keys,auth}')
 on conflict(endpoint) do update set p256dh=excluded.p256dh,auth=excluded.auth,active=true,
 enabled_at=case when private.web_push_subscriptions.active then private.web_push_subscriptions.enabled_at else now() end
 where private.web_push_subscriptions.user_id=auth.uid() and private.web_push_subscriptions.staff_id=sid returning id into subid;
 if subid is null then raise exception '다른 계정에 등록된 기기입니다. 기존 계정에서 알림을 해제해주세요.'; end if;
 return subid;
end $$;
revoke all on function public.register_homeroom_push(jsonb) from public;
grant execute on function public.register_homeroom_push(jsonb) to authenticated;

create function public.disable_homeroom_push(p_endpoint text) returns void language sql security definer set search_path='' as $$
 update private.web_push_subscriptions set active=false where endpoint=p_endpoint and user_id=auth.uid()
$$;
revoke all on function public.disable_homeroom_push(text) from public;
grant execute on function public.disable_homeroom_push(text) to authenticated;

create function public.test_homeroom_push(p_endpoint text) returns void language plpgsql security definer set search_path='' as $$
declare subid uuid;
begin
 select id into subid from private.web_push_subscriptions where endpoint=p_endpoint and user_id=auth.uid() and staff_id=private.current_homeroom_staff() and active;
 if subid is null then raise exception '알림을 먼저 등록해주세요.'; end if;
 if exists(select 1 from private.web_push_deliveries where subscription_id=subid and kind='TEST' and created_at>now()-interval '1 minute') then raise exception '1분 후 다시 시도해주세요.'; end if;
 insert into private.web_push_deliveries(subscription_id,kind) values(subid,'TEST');
end $$;
revoke all on function public.test_homeroom_push(text) from public;
grant execute on function public.test_homeroom_push(text) to authenticated;

-- Baseline existing eligible statuses so rollout never broadcasts historic cases.
insert into private.reflection_push_events(reflection_id,kind)
 select id::text,status from public.v_reflections where not submitted on conflict do nothing;

create function public.claim_homeroom_push() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 with new_events as (
 insert into private.reflection_push_events(reflection_id,kind)
 select id::text,status from public.v_reflections where not submitted on conflict do nothing returning *
 ) insert into private.web_push_deliveries(subscription_id,reflection_id,kind)
 select distinct sub.id,ev.reflection_id,ev.kind from new_events ev
 join public.v_reflections r on r.id::text=ev.reflection_id and r.status=ev.kind
 join core.enrollments e on e.student_id=r.core_student_id and e.left_at is null
 join core.classes c on c.id=e.class_id join core.academic_terms t on t.id=c.term_id and t.is_current
 join core.homeroom_staff h on h.class_id=c.id join core.staff_accounts s on s.id=h.staff_id and s.is_active
 join private.web_push_subscriptions sub on sub.staff_id=s.id and sub.active and sub.enabled_at<=ev.observed_at
 on conflict do nothing;
 -- Check current eligibility, account revocation and class assignment again before delivery.
 update private.web_push_deliveries d set state='CANCELLED' where d.state='PENDING' and not exists (
 select 1 from private.web_push_subscriptions sub join core.staff_accounts s on s.id=sub.staff_id and s.is_active
 join auth.users u on u.id=sub.user_id and u.email_confirmed_at is not null and lower(u.email)=any(s.login_emails)
 where sub.id=d.subscription_id and sub.active and (d.kind='TEST' or exists(
 select 1 from public.v_reflections r join core.enrollments e on e.student_id=r.core_student_id and e.left_at is null
 join core.classes c on c.id=e.class_id join core.academic_terms t on t.id=c.term_id and t.is_current
 join core.homeroom_staff h on h.class_id=c.id and h.staff_id=s.id
 where r.id::text=d.reflection_id and r.status=d.kind and not r.submitted)));
 with claimed as (
 select id from private.web_push_deliveries where state='PENDING' and attempts<5 and retry_at<=now() order by created_at for update skip locked limit 10
 ), leased as (
 update private.web_push_deliveries d set attempts=attempts+1,retry_at=now()+interval '2 minutes' from claimed where d.id=claimed.id returning d.*
 ) select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'kind',d.kind,'endpoint',s.endpoint,'keys',jsonb_build_object('p256dh',s.p256dh,'auth',s.auth))),'[]') into result from leased d join private.web_push_subscriptions s on s.id=d.subscription_id;
 return result;
end $$;
create function public.finish_homeroom_push(p_id uuid,p_code int) returns void language plpgsql security definer set search_path='' as $$
begin
 update private.web_push_deliveries set last_code=p_code,state=case when p_code between 200 and 299 then 'SENT' when p_code in(404,410) or attempts>=5 then 'FAILED' else 'PENDING' end where id=p_id and state='PENDING';
 if p_code in(404,410) then update private.web_push_subscriptions set active=false where id=(select subscription_id from private.web_push_deliveries where id=p_id); end if;
end $$;
create function public.homeroom_push_config() returns jsonb language sql security definer set search_path='' as $$
 select to_jsonb(c) from private.web_push_config c
$$;
revoke all on function public.claim_homeroom_push(),public.finish_homeroom_push(uuid,int),public.homeroom_push_config() from public,anon,authenticated;
grant execute on function public.claim_homeroom_push(),public.finish_homeroom_push(uuid,int),public.homeroom_push_config() to service_role;
