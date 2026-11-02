-- Production restoration executed on 2026-11-02.
-- The 2026-10-27 staff-requested score-screen reset marked all historical
-- weekly_balances as is_current=false, unintentionally hiding the 8-week
-- term history. Restore only that previously approved batch for history queries.
-- No point_records, reflection records, settlement balances or other
-- enforcement/discipline calculations are modified.
DO $$
DECLARE
  v_term uuid := '5a2d13ab-b3ce-4d12-b09d-835b0bbc447c';
  v_batch uuid := '08c0e90a-0e56-4b97-92bf-03da5580fed6';
  v_rows integer;
BEGIN
  SELECT count(*) INTO v_rows
  FROM discipline.weekly_balances
  WHERE term_id=v_term AND batch_id=v_batch AND is_current=false;
  IF v_rows <> 873 THEN
    RAISE EXCEPTION 'Historical import activation aborted: expected 873 preserved inactive weekly rows, found %',v_rows;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM discipline.weekly_balances w
    JOIN discipline.weekly_balances existing
      ON existing.term_id=w.term_id
     AND existing.core_student_id=w.core_student_id
     AND existing.week_start=w.week_start
     AND existing.is_current
    WHERE w.term_id=v_term AND w.batch_id=v_batch AND NOT w.is_current
  ) THEN
    RAISE EXCEPTION 'Historical import activation aborted: overlapping current weekly balance';
  END IF;

  UPDATE discipline.weekly_balances
  SET is_current=true
  WHERE term_id=v_term AND batch_id=v_batch AND is_current=false;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 873 THEN
    RAISE EXCEPTION 'Historical import activation mismatch: %',v_rows;
  END IF;
END
$$;
