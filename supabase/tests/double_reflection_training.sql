-- Rollback regression: creating/updating real students is not persisted.
BEGIN;
SELECT set_config('request.jwt.claim.sub',(SELECT user_id::text FROM public.admins WHERE role='SEONDO' AND is_active AND is_lead ORDER BY id LIMIT 1),true);
SET LOCAL ROLE authenticated;
DO $test$
DECLARE st uuid; wk date:=private.kst_week_start(); rid int; rf int; qualifies boolean; reasons text[]; n int;
BEGIN
 SELECT ds.core_student_id INTO st FROM public.v_discipline_students ds
 WHERE ds.grade=7 AND NOT EXISTS (SELECT 1 FROM public.point_records pr WHERE pr.core_student_id=ds.core_student_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL) LIMIT 1;
 IF st IS NULL THEN RAISE EXCEPTION 'Need a clean student'; END IF;
 rid:=public.create_point_record_once(st,'NEGATIVE','2x reflection regression',1,wk,gen_random_uuid(),false);
 SELECT id INTO rf FROM public.reflection_records WHERE point_record_id=rid;
 IF rf IS NULL THEN RAISE EXCEPTION 'Missing reflection'; END IF;
 UPDATE public.reflection_records SET due_at=((private.kst_today()-1+TIME '17:00') AT TIME ZONE 'Asia/Seoul') WHERE id=rf;
 SELECT physical_training_required,physical_training_reasons INTO qualifies,reasons FROM public.v_student_summary WHERE core_student_id=st;
 IF qualifies OR cardinality(reasons)<>0 THEN RAISE EXCEPTION 'Premature training'; END IF;
 UPDATE public.reflection_records SET due_at=((private.kst_today()-2+TIME '17:00') AT TIME ZONE 'Asia/Seoul') WHERE id=rf;
 SELECT physical_training_required,physical_training_reasons INTO qualifies,reasons FROM public.v_student_summary WHERE core_student_id=st;
 IF NOT qualifies OR cardinality(reasons)<>1 OR NOT ('2배 반성문 17시 미제출 (익일)'=ANY(reasons)) THEN RAISE EXCEPTION 'Missing overdue reason'; END IF;
 SELECT count(*) INTO n FROM public.v_training_weekly_eligibility WHERE core_student_id=st AND reflection_training_on IS NOT NULL;
 IF n<>1 THEN RAISE EXCEPTION 'Duplicate overdue training week: %',n; END IF;
 UPDATE public.reflection_records SET submitted=true,submitted_at=now() WHERE id=rf;
 SELECT physical_training_required,physical_training_reasons INTO qualifies,reasons FROM public.v_student_summary WHERE core_student_id=st;
 IF qualifies OR cardinality(reasons)<>0 THEN RAISE EXCEPTION 'Completed paper still triggers training'; END IF;
 UPDATE public.reflection_records SET submitted=false,submitted_at=null WHERE id=rf;
 PERFORM public.create_point_record_once(st,'NEGATIVE','3-way training',7,wk,gen_random_uuid(),false);
 PERFORM public.create_point_record_once(st,'NEGATIVE','3-way training',1,wk,gen_random_uuid(),false);
 SELECT physical_training_required,physical_training_reasons INTO qualifies,reasons FROM public.v_student_summary WHERE core_student_id=st;
 IF NOT qualifies OR cardinality(reasons)<>3 THEN RAISE EXCEPTION 'Expected 3 simultaneous reasons'; END IF;
END $test$;
RESET ROLE;
SELECT '3 training reasons / double 17:00 / next-day / submission / once-week passed' AS result;
ROLLBACK;
