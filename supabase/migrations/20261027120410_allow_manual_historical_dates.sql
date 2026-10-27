-- Manual entry dates follow occurrence dates, including dates before the weekly cutover.
-- Imported audit originals remain immutable. Future dates are still rejected.
create or replace function private.guard_discipline_history_cutover()
returns trigger language plpgsql security definer set search_path='' as $function$
begin
 if tg_op='UPDATE' and old.superseded_by_import_id is not null then
  raise exception '주간 확정 원장으로 대체된 기록입니다. 원본은 감사용으로 보존합니다.';
 end if;
 if new.recorded_at>private.kst_today() then
  raise exception '미래 날짜로 점수를 입력할 수 없습니다.';
 end if;
 return new;
end
$function$;
