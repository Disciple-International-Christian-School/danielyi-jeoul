-- Run after applying the notice_day_isolation migration, with an authorized
-- SEONDO lead connection. This script never creates/publishes a notice.
-- It verifies that today cannot accidentally choose yesterday's draft.
begin;
select set_config('request.jwt.claim.sub',
  (select a.user_id::text from public.admins a
   where a.role = 'SEONDO' and a.is_lead and a.is_active limit 1), true);
select
  selected.day,
  selected.notice->>'notice_day' as echoed_day,
  selected.notice->'batch'->>'day' as batch_day,
  jsonb_array_length(selected.notice->'entries') as saved_entries,
  jsonb_array_length(selected.notice->'preview_entries') as preview_entries,
  selected.notice->>'blocked_by_unpublished_day' as prior_unpublished_day
from (
  select d.day, public.get_seondo_notice(d.day) as notice
  from (values ('2026-11-18'::date), ('2026-11-19'::date)) d(day)
) selected
order by selected.day;
rollback;
