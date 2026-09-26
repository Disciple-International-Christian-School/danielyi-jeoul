-- Pin search_path on functions (advisor: function_search_path_mutable)
-- and grant RPCs to authenticated. Applied on the live project 2026-09-21.

alter function private.touch_updated_at() set search_path = '';
alter function private.kst_today() set search_path = '';
alter function private.kst_week_start() set search_path = '';
alter function private.kst_month_start() set search_path = '';
alter function private.validate_point_record() set search_path = '';
alter function private.create_reflection_for_penalty() set search_path = '';
alter function private.validate_point_item() set search_path = '';
alter function public.create_point_record(int, public.point_type, text, int, text, date, boolean) set search_path = '';
alter function public.update_point_record(int, text, int, text, date, boolean) set search_path = '';
alter function public.create_punishment(int, text[], date, date, text) set search_path = '';
alter function public.set_punishment_violation(int, boolean) set search_path = '';

grant execute on function public.create_point_record(int, public.point_type, text, int, text, date, boolean) to authenticated;
grant execute on function public.update_point_record(int, text, int, text, date, boolean) to authenticated;
grant execute on function public.create_punishment(int, text[], date, date, text) to authenticated;
grant execute on function public.set_punishment_violation(int, boolean) to authenticated;
