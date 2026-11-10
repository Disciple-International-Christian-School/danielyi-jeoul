-- Page counts reflect the incremental negative balance at the time of the incident.
-- Apply the timed waiver to incidents from November 11 KST onward so old resolved
-- incidents cannot reappear when the new policy is released.
CREATE OR REPLACE VIEW public.v_reflection_eligible_penalties WITH (security_invoker = true) AS
WITH sequenced AS (
  SELECT pr.id AS point_record_id,
         pr.core_student_id,
         date_trunc('week', pr.recorded_at::timestamp)::date AS week_start,
         pr.recorded_at,
         pr.created_at,
         pr.type,
         pr.points,
         sum(CASE WHEN pr.type = 'POSITIVE' THEN pr.points ELSE -pr.points END) OVER (
           PARTITION BY pr.core_student_id, date_trunc('week', pr.recorded_at::timestamp)
           ORDER BY pr.created_at, pr.id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
         ) AS net_at_entry
  FROM public.point_records pr
  WHERE pr.deleted_at IS NULL
    AND pr.superseded_by_import_id IS NULL
    AND pr.recorded_at <= private.kst_today()
), with_waiver AS (
  SELECT q.*,
         min(greatest(q.created_at, q.recorded_at::timestamp AT TIME ZONE 'Asia/Seoul'))
           FILTER (WHERE q.type = 'POSITIVE' AND q.net_at_entry >= 0
                    AND (q.created_at AT TIME ZONE 'Asia/Seoul')::date <= q.recorded_at)
           OVER (
             PARTITION BY q.core_student_id, q.recorded_at
             ORDER BY q.created_at, q.point_record_id
             ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
           ) AS same_day_waiver_at
  FROM sequenced q
)
SELECT q.point_record_id,
       q.core_student_id,
       q.week_start,
       w.positive_points - w.negative_points AS weekly_net,
       least(q.points, -q.net_at_entry)::int AS reflection_pages
FROM with_waiver q
JOIN public.v_weekly_scores_core_shadow w
  ON w.core_student_id = q.core_student_id AND w.week_start = q.week_start
LEFT JOIN public.reflection_records r ON r.point_record_id = q.point_record_id
WHERE q.type = 'NEGATIVE'
  AND q.net_at_entry < 0
  AND CASE
    WHEN q.recorded_at < date '2026-11-11' THEN w.net_penalty_points > 0
    ELSE r.submitted OR q.same_day_waiver_at IS NULL OR q.same_day_waiver_at > r.due_at
  END;

COMMENT ON VIEW public.v_reflection_eligible_penalties IS
  'Incident-time negative NET determines pages. From November 11 KST, same-day merits reaching zero before the due time waive an unsubmitted reflection.';

-- Append the per-incident page count without changing existing view columns.
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
    ds.core_student_id IS NOT NULL AS is_current_student,
    e.reflection_pages
   FROM reflection_records r
     JOIN point_records pr ON pr.id = r.point_record_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
     JOIN v_reflection_eligible_penalties e ON e.point_record_id = pr.id
     JOIN students s ON s.core_student_id = pr.core_student_id
     LEFT JOIN v_discipline_students ds ON ds.legacy_student_id = s.id;
