-- 2026-09-25
-- Aggregate external identity migration status, intentionally PII-free.

create or replace view public.v_external_auth_mapping_status
with (security_invoker = true) as
select
  x.source_system,
  x.source_project_ref,
  count(*)::int as linked_students,
  count(*) filter (where x.is_active)::int as active_links,
  count(*) filter (where x.last_verified_at is not null)::int as verified_links,
  max(x.last_verified_at) as last_verified_at
from core.external_auth_identities x
group by x.source_system, x.source_project_ref
order by x.source_system, x.source_project_ref;

comment on view public.v_external_auth_mapping_status is
  'PII-free aggregate progress for external/legacy Auth identity consolidation.';

grant select on public.v_external_auth_mapping_status to authenticated;
