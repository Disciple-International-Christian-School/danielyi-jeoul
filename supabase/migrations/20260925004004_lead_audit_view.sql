-- 2026-09-25
-- Lead-only audit log projection for operational review.

drop policy if exists discipline_audit_logs_read_admin on discipline.audit_logs;
drop policy if exists discipline_audit_logs_read_lead on discipline.audit_logs;

create policy discipline_audit_logs_read_lead on discipline.audit_logs
  for select to authenticated
  using (private.current_admin_is_lead());

create or replace view public.v_discipline_audit_logs
with (security_invoker = true) as
select
  l.id,
  l.actor_user_id,
  coalesce(a.display_name, 'SYSTEM / LEGACY') as actor_name,
  a.role as actor_role,
  l.action,
  l.entity_type,
  l.entity_id,
  l.before_data,
  l.after_data,
  l.created_at
from discipline.audit_logs l
left join public.admins a
  on a.user_id = l.actor_user_id
order by l.created_at desc, l.id desc;

comment on view public.v_discipline_audit_logs is
  'Lead-only discipline audit history with resolved admin display names.';

grant select on public.v_discipline_audit_logs to authenticated;
