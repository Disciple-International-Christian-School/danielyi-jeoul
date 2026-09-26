-- 2026-09-25
-- Harden exposed Core-admin SECURITY DEFINER RPC privileges.
--
-- Each function already performs server-side lead checks, but PostgreSQL
-- functions are executable by PUBLIC by default unless explicitly revoked.
-- Remove anonymous/public execution at the privilege layer as defense in depth.

revoke all on function public.initialize_current_academic_term(text, text, date, date)
  from public;
revoke all on function public.initialize_current_academic_term(text, text, date, date)
  from anon;
grant execute on function public.initialize_current_academic_term(text, text, date, date)
  to authenticated;

revoke all on function public.assign_current_grade9_section(integer, text)
  from public;
revoke all on function public.assign_current_grade9_section(integer, text)
  from anon;
grant execute on function public.assign_current_grade9_section(integer, text)
  to authenticated;

revoke all on function public.link_external_auth_identity(text, text, text, text, text)
  from public;
revoke all on function public.link_external_auth_identity(text, text, text, text, text)
  from anon;
grant execute on function public.link_external_auth_identity(text, text, text, text, text)
  to authenticated;
