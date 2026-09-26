-- 2026-09-27
-- Avoid per-row auth/function re-evaluation in the admin roster RLS policy.

drop policy if exists admins_read_self_or_lead on public.admins;

create policy admins_read_self_or_lead
  on public.admins
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.current_admin_is_lead())
  );
