-- 2026-09-25
-- Secure external-auth identity linking for verified cross-project mappings.
--
-- No passwords/PINs are accepted.
-- This function does not infer identity from names.
-- The caller must supply an already-verified school student_no and external
-- identity. Conflicting mappings are rejected rather than overwritten.

create or replace function public.link_external_auth_identity(
  p_student_no text,
  p_source_system text,
  p_source_project_ref text,
  p_external_user_id text,
  p_external_login_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_id uuid;
  v_existing core.external_auth_identities%rowtype;
  v_id uuid;
begin
  if not private.current_admin_is_lead() then
    raise exception '선도부장 권한이 필요합니다.';
  end if;

  if nullif(btrim(p_student_no), '') is null then
    raise exception 'student_no가 필요합니다.';
  end if;

  if nullif(btrim(p_source_system), '') is null then
    raise exception 'source_system이 필요합니다.';
  end if;

  if nullif(btrim(p_external_user_id), '') is null then
    raise exception 'external_user_id가 필요합니다.';
  end if;

  select s.id
  into v_student_id
  from core.students s
  where s.student_no = btrim(p_student_no);

  if v_student_id is null then
    raise exception '해당 student_no의 Core 학생을 찾을 수 없습니다.';
  end if;

  -- An external account must never be silently moved between students.
  select *
  into v_existing
  from core.external_auth_identities x
  where x.source_system = upper(btrim(p_source_system))
    and x.external_user_id = btrim(p_external_user_id)
  limit 1;

  if v_existing.id is not null
     and v_existing.student_id <> v_student_id then
    raise exception '이 외부 identity는 이미 다른 Core 학생에 연결되어 있습니다.';
  end if;

  -- Likewise, one student may not silently acquire a second account for the
  -- same source system. Such cases require explicit investigation.
  select *
  into v_existing
  from core.external_auth_identities x
  where x.source_system = upper(btrim(p_source_system))
    and x.student_id = v_student_id
  limit 1;

  if v_existing.id is not null
     and v_existing.external_user_id <> btrim(p_external_user_id) then
    raise exception '이 Core 학생은 동일 source_system의 다른 외부 identity와 이미 연결되어 있습니다.';
  end if;

  insert into core.external_auth_identities (
    student_id,
    source_system,
    source_project_ref,
    external_user_id,
    external_login_id,
    is_active,
    linked_at,
    last_verified_at
  )
  values (
    v_student_id,
    upper(btrim(p_source_system)),
    nullif(btrim(p_source_project_ref), ''),
    btrim(p_external_user_id),
    nullif(btrim(p_external_login_id), ''),
    true,
    now(),
    now()
  )
  on conflict (source_system, external_user_id)
  do update
  set source_project_ref = excluded.source_project_ref,
      external_login_id = excluded.external_login_id,
      is_active = true,
      last_verified_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

comment on function public.link_external_auth_identity(text, text, text, text, text) is
  'Lead-only verified mapping from an external project identity to canonical core.students. Rejects conflicting reassignment and never accepts credentials.';

grant execute on function public.link_external_auth_identity(text, text, text, text, text)
  to authenticated;
