-- Future-dated point entries: verify immediate storage and delayed activation.
-- All test inserts roll back. Run as an authorized, active SEONDO account.
BEGIN;
SELECT set_config('request.jwt.claim.sub',(SELECT user_id::text FROM public.admins WHERE role='SEONDO' AND is_active AND is_lead ORDER BY id LIMIT 1),true);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE sid uuid; next_day date:=private.kst_today()+1;
        future_positive int; future_negative int;
        baseline public.v_student_summary%rowtype;
        after_save public.v_student_summary%rowtype;
        n int;
BEGIN
 SELECT ds.core_student_id INTO sid FROM public.v_discipline_students ds
 WHERE ds.grade=7 LIMIT 1;
 IF sid IS NULL THEN RAISE EXCEPTION 'Active Grade 7 student required'; END IF;
 SELECT * INTO baseline FROM public.v_student_summary WHERE core_student_id=sid;
 future_positive:=public.create_point_record_once(sid,'POSITIVE','FUTURE-MERIT-ROLLBACK',4,next_day,gen_random_uuid(),false);
 future_negative:=public.create_point_record_once(sid,'NEGATIVE','FUTURE-PENALTY-ROLLBACK',8,next_day,gen_random_uuid(),false);
 SELECT count(*) INTO n FROM public.point_records WHERE id IN (future_positive,future_negative) AND recorded_at=next_day;
 IF n<>2 THEN RAISE EXCEPTION 'Future records were not saved'; END IF;
 SELECT count(*) INTO n FROM public.reflection_records WHERE point_record_id=future_negative;
 IF n<>1 THEN RAISE EXCEPTION 'Raw future reflection audit entry missing'; END IF;
 SELECT count(*) INTO n FROM public.v_reflections WHERE point_record_id=future_negative;
 IF n<>0 THEN RAISE EXCEPTION 'Future penalty created actionable reflection too early'; END IF;
 SELECT * INTO after_save FROM public.v_student_summary WHERE core_student_id=sid;
 IF after_save.weekly_penalty_points IS DISTINCT FROM baseline.weekly_penalty_points OR
    after_save.weekly_positive_points IS DISTINCT FROM baseline.weekly_positive_points OR
    after_save.physical_training_required IS DISTINCT FROM baseline.physical_training_required OR
    after_save.positive_points IS DISTINCT FROM baseline.positive_points OR
    after_save.negative_points IS DISTINCT FROM baseline.negative_points OR
    after_save.committee_required IS DISTINCT FROM baseline.committee_required THEN
    RAISE EXCEPTION 'Future events contaminated currently effective points/discipline';
 END IF;
END $test$;
RESET ROLE;
SELECT 'future +/- stored; current score, reflection, training, committee unchanged' result;
ROLLBACK;
