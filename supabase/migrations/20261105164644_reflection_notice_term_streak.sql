-- Show the signed NET of the incident week and evaluate committee referral across the current term.

CREATE OR REPLACE VIEW public.v_reflection_eligible_penalties WITH (security_invoker = true) AS
WITH sequenced AS (
         SELECT pr.id AS point_record_id,
            pr.core_student_id,
            date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date AS week_start,
            pr.type,
            sum(
                CASE
                    WHEN pr.type = 'POSITIVE'::point_type THEN pr.points
                    ELSE - pr.points
                END) OVER (PARTITION BY pr.core_student_id, (date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date) ORDER BY pr.created_at, pr.id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS net_at_entry
           FROM point_records pr
          WHERE pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at <= private.kst_today()
        )
 SELECT x.point_record_id,
    x.core_student_id,
    x.week_start,
    w.positive_points - w.negative_points AS weekly_net
   FROM sequenced x
     JOIN v_weekly_scores_core_shadow w ON w.core_student_id = x.core_student_id AND w.week_start = x.week_start
  WHERE x.type = 'NEGATIVE'::point_type AND x.net_at_entry < 0 AND w.net_penalty_points > 0;

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
      + TIME '17:00') AT TIME ZONE 'Asia/Seoul') AS double_submit_deadline
   FROM reflection_records r
     JOIN point_records pr ON pr.id = r.point_record_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
     JOIN v_reflection_eligible_penalties e ON e.point_record_id = pr.id
     JOIN students s ON s.core_student_id = pr.core_student_id
     LEFT JOIN v_discipline_students ds ON ds.legacy_student_id = s.id;

CREATE OR REPLACE VIEW public.v_reflection_training_overdue WITH (security_invoker = true) AS
 SELECT r.id AS reflection_id,
    r.core_student_id,
    r.due_at,
    (r.double_submit_deadline AT TIME ZONE 'Asia/Seoul')::date AS double_submit_date,
    r.double_submit_deadline,
    (r.double_submit_deadline AT TIME ZONE 'Asia/Seoul')::date + 1 AS training_on,
    date_trunc('week', (r.double_submit_deadline AT TIME ZONE 'Asia/Seoul')::date + 1)::date AS training_week_start
   FROM public.v_reflections r
  WHERE r.status = 'DOUBLE' AND NOT r.submitted;

CREATE OR REPLACE VIEW public.v_student_summary_core_shadow WITH (security_invoker = true) AS
WITH current_term AS (
    SELECT starts_on, LEAST(ends_on, private.kst_today()) AS effective_end
    FROM core.academic_terms
    WHERE is_current
), term_penalty_weeks AS (
    SELECT pr.core_student_id, date_trunc('week', pr.recorded_at::timestamp)::date AS week_start
    FROM public.point_records pr
    CROSS JOIN current_term t
    WHERE pr.core_student_id IS NOT NULL
      AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
      AND pr.recorded_at BETWEEN t.starts_on AND t.effective_end
    GROUP BY pr.core_student_id, date_trunc('week', pr.recorded_at::timestamp)::date
    HAVING count(*) FILTER (WHERE pr.type = 'NEGATIVE') >= 3
       OR coalesce(sum(CASE WHEN pr.type = 'NEGATIVE' THEN pr.points ELSE -pr.points END), 0) >= 8
), term_training_weeks AS (
    SELECT core_student_id, week_start FROM term_penalty_weeks
    UNION
    SELECT o.core_student_id, o.training_week_start
    FROM public.v_reflection_training_overdue o
    CROSS JOIN current_term t
    WHERE o.training_on BETWEEN t.starts_on AND t.effective_end
), term_training_runs AS (
    SELECT core_student_id,
           week_start - (7 * row_number() OVER (PARTITION BY core_student_id ORDER BY week_start))::integer AS run_key
    FROM term_training_weeks
), term_training_streaks AS (
    SELECT core_student_id, max(run_length)::integer AS longest_run
    FROM (
        SELECT core_student_id, count(*) AS run_length
        FROM term_training_runs
        GROUP BY core_student_id, run_key
    ) runs
    GROUP BY core_student_id
), lifetime AS (
         SELECT ds_1.core_student_id,
            COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'POSITIVE'::point_type), 0::bigint)::integer AS positive_points,
            COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint)::integer AS negative_points
           FROM v_discipline_students ds_1
             LEFT JOIN point_records pr ON pr.core_student_id = ds_1.core_student_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at <= private.kst_today()
          GROUP BY ds_1.core_student_id
        ), weekly AS (
         SELECT ws.core_student_id,
            ws.positive_points,
            ws.negative_points,
            ws.net_penalty_points,
            ws.penalty_incident_count,
            ws.physical_training_required
           FROM v_training_weekly_eligibility ws
          WHERE ws.week_start = private.kst_week_start()
        ), settlement AS (
         SELECT ss.core_student_id,
            ss.period_id,
            ss.period_label,
            ss.starts_on,
            ss.positive_points,
            ss.negative_points,
            ss.net_penalty_points
           FROM v_settlement_scores_core_shadow ss
          WHERE ss.is_open
        ), training_overdue AS (
         SELECT v_reflection_training_overdue.core_student_id,
            bool_or(true) AS has_unsubmitted_training
           FROM v_reflection_training_overdue
          WHERE v_reflection_training_overdue.training_on <= private.kst_today()
          GROUP BY v_reflection_training_overdue.core_student_id
        ), refl AS (
         SELECT r_1.core_student_id,
            bool_or(r_1.status = 'MISSING'::text) AS has_missing,
            bool_or(r_1.status = 'DOUBLE'::text) AS has_double
           FROM v_reflections r_1
          WHERE NOT r_1.submitted
          GROUP BY r_1.core_student_id
        ), active_pun AS (
         SELECT DISTINCT ON (p.core_student_id) p.core_student_id,
            p.types,
            p.violated_at
           FROM punishments p
          WHERE p.start_date <= private.kst_today() AND p.end_date >= private.kst_today()
          ORDER BY p.core_student_id, p.start_date DESC, p.id DESC
        ), weeks3 AS (
         SELECT wp.core_student_id,
            count(*)::integer AS qualifying_weeks
           FROM v_weekly_penalties_core_shadow wp
          WHERE (wp.week_start = ANY (ARRAY[private.kst_week_start(), private.kst_week_start() - 7, private.kst_week_start() - 14])) AND wp.penalty_points >= 5
          GROUP BY wp.core_student_id
        )
 SELECT ds.legacy_student_id AS id,
    ds.name,
    ds.grade,
    ls.created_at,
    ls.updated_at,
    COALESCE(lt.positive_points, 0) AS positive_points,
    COALESCE(lt.negative_points, 0) AS negative_points,
    COALESCE(w.negative_points, 0) AS weekly_penalty_points,
    COALESCE(st.negative_points, 0) AS monthly_penalty_points,
    COALESCE(w.penalty_incident_count, 0) AS weekly_record_count,
        CASE
            WHEN ap.core_student_id IS NOT NULL THEN array_to_string(ap.types, ', '::text)
            ELSE NULL::text
        END AS punishment,
    array_remove(ARRAY[
        CASE
            WHEN COALESCE(w.physical_training_required, false) OR COALESCE(tov.has_unsubmitted_training, false) THEN '체력훈련 대상'::text
            ELSE NULL::text
        END,
        CASE
            WHEN (COALESCE(ts.longest_run, 0) >= 3) THEN '징계위원회 대상'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(r.has_missing, false) THEN '반성문 미제출'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(r.has_double, false) THEN '반성문 2배 제출 대상'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(w.negative_points, 0) >= 5 AND ap.core_student_id IS NULL THEN '처분 선택 필요'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(w3.qualifying_weeks, 0) >= 3 THEN '귀가금지 조건 충족'::text
            ELSE NULL::text
        END], NULL::text) ||
        CASE
            WHEN ap.core_student_id IS NULL THEN ARRAY[]::text[]
            WHEN ap.violated_at IS NOT NULL THEN ARRAY['귀가금지'::text]
            ELSE ap.types
        END AS statuses,
    ds.core_student_id,
    ds.student_no,
    ds.homeroom,
    COALESCE(w.positive_points, 0) AS weekly_positive_points,
    COALESCE(w.net_penalty_points, 0) AS weekly_net_penalty_points,
    COALESCE(w.physical_training_required, false) OR COALESCE(tov.has_unsubmitted_training, false) AS physical_training_required,
    st.period_id AS settlement_period_id,
    st.period_label AS settlement_period_label,
    st.starts_on AS settlement_starts_on,
    COALESCE(st.positive_points, 0) AS settlement_positive_points,
    COALESCE(st.negative_points, 0) AS settlement_penalty_points,
    COALESCE(st.net_penalty_points, 0) AS settlement_net_penalty_points,
    COALESCE(ts.longest_run, 0) AS physical_training_weeks,
    (COALESCE(ts.longest_run, 0) >= 3) AS committee_required,
    array_remove(ARRAY[
        CASE
            WHEN COALESCE(w.penalty_incident_count, 0) >= 3 THEN '주간 벌점 3회 이상'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(w.net_penalty_points, 0) >= 8 THEN '주간 상벌NET -8점 이하'::text
            ELSE NULL::text
        END,
        CASE
            WHEN COALESCE(tov.has_unsubmitted_training, false) THEN '2배 반성문 17시 미제출 (익일)'::text
            ELSE NULL::text
        END], NULL::text) AS physical_training_reasons
   FROM v_discipline_students ds
     JOIN students ls ON ls.id = ds.legacy_student_id
     LEFT JOIN lifetime lt ON lt.core_student_id = ds.core_student_id
     LEFT JOIN weekly w ON w.core_student_id = ds.core_student_id
     LEFT JOIN settlement st ON st.core_student_id = ds.core_student_id
     LEFT JOIN term_training_streaks ts ON ts.core_student_id = ds.core_student_id
     LEFT JOIN refl r ON r.core_student_id = ds.core_student_id
     LEFT JOIN active_pun ap ON ap.core_student_id = ds.core_student_id
     LEFT JOIN weeks3 w3 ON w3.core_student_id = ds.core_student_id
     LEFT JOIN training_overdue tov ON tov.core_student_id = ds.core_student_id;
