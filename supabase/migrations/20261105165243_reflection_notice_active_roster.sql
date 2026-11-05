-- Keep historical reflections visible while excluding inactive students from active notices.
CREATE OR REPLACE VIEW public.v_reflections WITH (security_invoker = true) AS
 SELECT r.id,
    r.point_record_id,
    s.id AS student_id,
    s.name AS student_name,
    s.grade,
    pr.item,
    pr.points,
    pr.recorded_at,
    r.submitted,
    r.submission_deadline,
    r.submitted_at,
        CASE
            WHEN r.submitted THEN 'SUBMITTED'::text
            WHEN r.due_at < now() THEN 'DOUBLE'::text
            ELSE 'MISSING'::text
        END AS status,
    r.due_at,
    r.deadline_change_reason,
        CASE
            WHEN s.grade >= 1 AND s.grade <= 6 THEN 'ELEMENTARY'::discipline_scope
            WHEN s.grade >= 7 AND s.grade <= 8 THEN 'MIDDLE'::discipline_scope
            ELSE 'HIGH'::discipline_scope
        END AS assigned_scope,
    pr.core_student_id,
    e.week_start,
    e.weekly_net,
    ds.homeroom,
    (((r.due_at AT TIME ZONE 'Asia/Seoul')::date
      + CASE WHEN (r.due_at AT TIME ZONE 'Asia/Seoul')::time >= TIME '17:00' THEN 1 ELSE 0 END
      + TIME '17:00') AT TIME ZONE 'Asia/Seoul') AS double_submit_deadline,
    ds.core_student_id IS NOT NULL AS is_current_student
   FROM reflection_records r
     JOIN point_records pr ON pr.id = r.point_record_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
     JOIN v_reflection_eligible_penalties e ON e.point_record_id = pr.id
     JOIN students s ON s.core_student_id = pr.core_student_id
     LEFT JOIN v_discipline_students ds ON ds.legacy_student_id = s.id;
