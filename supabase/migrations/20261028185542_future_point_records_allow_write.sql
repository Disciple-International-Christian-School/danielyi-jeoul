-- Retain immutable historical-cutover rule. Remove only the pre-existing
-- blanket prohibition on future-dated point records.
CREATE OR REPLACE FUNCTION private.guard_discipline_history_cutover()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF tg_op = 'UPDATE' AND old.superseded_by_import_id IS NOT NULL THEN
    RAISE EXCEPTION '주간 확정 원장으로 대체된 기록입니다. 원본은 감사용으로 보존합니다.';
  END IF;
  RETURN new;
END
$function$;