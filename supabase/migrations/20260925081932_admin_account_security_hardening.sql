-- 2026-09-25
-- Harden personal admin provisioning:
-- - lead accounts always have ALL discipline scope
-- - clients cannot clear must_change_password directly

create or replace function public.register_admin_profile(
  p_user_id uuid,
  p_login_id text,
  p_display_name text,
  p_role public.admin_role,
  p_scope public.discipline_scope,
  p_is_lead boolean
)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_login text := lower(btrim(p_login_id));
  v_email text;
  v_id int;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  if v_login !~ '^[a-z0-9][a-z0-9._-]{2,31}$' then
    raise exception '로그인 ID 형식을 확인해주세요.';
  end if;

  if nullif(btrim(p_display_name), '') is null then
    raise exception '표시 이름이 필요합니다.';
  end if;

  if p_role = 'SEONDO' then
    if p_is_lead then
      p_scope := 'ALL'::public.discipline_scope;
    elsif p_scope is null then
      raise exception '선도부 계정은 담당 범위가 필요합니다.';
    end if;
  else
    if p_is_lead then
      raise exception '사생회 계정은 선도부장 권한을 가질 수 없습니다.';
    end if;
    p_scope := null;
  end if;

  select lower(email)
  into v_email
  from auth.users
  where id = p_user_id;

  if v_email is null then
    raise exception 'Auth 계정을 찾을 수 없습니다.';
  end if;

  if v_email <> (v_login || '@scale.dics.kr') then
    raise exception 'Auth 이메일과 login_id가 일치하지 않습니다.';
  end if;

  insert into public.admins (
    user_id,
    login_id,
    display_name,
    role,
    discipline_scope,
    is_lead,
    is_active,
    must_change_password,
    provisioned_by,
    updated_at
  )
  values (
    p_user_id,
    v_login,
    btrim(p_display_name),
    p_role,
    p_scope,
    case when p_role = 'SEONDO' then p_is_lead else false end,
    true,
    true,
    auth.uid(),
    now()
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.update_admin_profile(
  p_admin_id int,
  p_display_name text,
  p_role public.admin_role,
  p_scope public.discipline_scope,
  p_is_lead boolean,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.admins%rowtype;
  v_other_active_leads int;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  select *
  into v_target
  from public.admins
  where id = p_admin_id
  for update;

  if v_target.id is null then
    raise exception '관리자 계정을 찾을 수 없습니다.';
  end if;

  if nullif(btrim(p_display_name), '') is null then
    raise exception '표시 이름이 필요합니다.';
  end if;

  if p_role = 'SEONDO' then
    if p_is_lead then
      p_scope := 'ALL'::public.discipline_scope;
    elsif p_scope is null then
      raise exception '선도부 계정은 담당 범위가 필요합니다.';
    end if;
  else
    p_scope := null;
    p_is_lead := false;
  end if;

  if v_target.is_active
     and v_target.role = 'SEONDO'
     and v_target.is_lead
     and (not p_is_active or p_role <> 'SEONDO' or not p_is_lead) then
    select count(*)::int
    into v_other_active_leads
    from public.admins
    where id <> p_admin_id
      and is_active
      and role = 'SEONDO'
      and is_lead;

    if v_other_active_leads = 0 then
      raise exception '마지막 활성 선도부장 계정은 해제할 수 없습니다.';
    end if;
  end if;

  update public.admins
  set display_name = btrim(p_display_name),
      role = p_role,
      discipline_scope = p_scope,
      is_lead = p_is_lead,
      is_active = p_is_active,
      updated_at = now()
  where id = p_admin_id;
end;
$$;

-- Password-change completion is now owned by the JWT-required Edge Function.
revoke all on function public.mark_admin_password_changed() from public, anon, authenticated;
drop function if exists public.mark_admin_password_changed();

revoke all on function public.register_admin_profile(uuid, text, text, public.admin_role, public.discipline_scope, boolean)
  from public, anon;
grant execute on function public.register_admin_profile(uuid, text, text, public.admin_role, public.discipline_scope, boolean)
  to authenticated;

revoke all on function public.update_admin_profile(int, text, public.admin_role, public.discipline_scope, boolean, boolean)
  from public, anon;
grant execute on function public.update_admin_profile(int, text, public.admin_role, public.discipline_scope, boolean, boolean)
  to authenticated;
