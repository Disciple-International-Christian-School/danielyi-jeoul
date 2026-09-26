-- 2026-09-27
-- The legacy integer G9 assignment RPC only resolves a compatibility ID and
-- delegates to the Core UUID implementation. It does not need elevated rights.

alter function public.assign_current_grade9_section(integer, text)
  security invoker;

revoke all on function public.assign_current_grade9_section(integer, text)
  from public, anon;
grant execute on function public.assign_current_grade9_section(integer, text)
  to authenticated;

comment on function public.assign_current_grade9_section(integer, text) is
  'Legacy compatibility wrapper. Runs as caller and delegates authorized writes to the Core UUID RPC.';
