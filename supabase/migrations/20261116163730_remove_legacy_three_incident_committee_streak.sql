-- Stop treating historical weeks with three low-point incidents as training weeks.
-- This corrects derived old committee streaks without changing any student records.
-- Full calendar-month committee settlements remain controlled by seondo_policy.
create or replace view public.v_student_summary_core_shadow with (security_invoker = true) as
 WITH current_term AS (
         SELECT academic_terms.starts_on,
            LEAST(academic_terms.ends_on, private.kst_today()) AS effective_end
           FROM core.academic_terms
          WHERE academic_terms.is_current
        ), term_penalty_weeks AS (
         SELECT pr.core_student_id,
            date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date AS week_start
           FROM point_records pr
             CROSS JOIN current_term t
          WHERE pr.core_student_id IS NOT NULL AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at >= t.starts_on AND pr.recorded_at <= t.effective_end
          GROUP BY pr.core_student_id, (date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date)
         HAVING COALESCE(sum(
                CASE
                    WHEN pr.type = 'NEGATIVE'::point_type THEN pr.points
                    ELSE - pr.points
                END), 0::bigint) >= 8
        ), term_training_weeks AS (
         SELECT term_penalty_weeks.core_student_id,
            term_penalty_weeks.week_start
           FROM term_penalty_weeks
        UNION
         SELECT o.core_student_id,
            o.training_week_start
           FROM v_reflection_training_overdue o
             CROSS JOIN current_term t
          WHERE o.training_on >= t.starts_on AND o.training_on <= t.effective_end
        ), term_training_runs AS (
         SELECT term_training_weeks.core_student_id,
            term_training_weeks.week_start - (7 * row_number() OVER (PARTITION BY term_training_weeks.core_student_id ORDER BY term_training_weeks.week_start))::integer AS run_key
           FROM term_training_weeks
        ), term_training_streaks AS (
         SELECT runs.core_student_id,
            max(runs.run_length)::integer AS longest_run
           FROM ( SELECT term_training_runs.core_student_id,
                    count(*) AS run_length
                   FROM term_training_runs
                  GROUP BY term_training_runs.core_student_id, term_training_runs.run_key) runs
          GROUP BY runs.core_student_id
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
            WHEN COALESCE(ts.longest_run, 0) >= 3 THEN '징계위원회 대상'::text
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
    COALESCE(ts.longest_run, 0) >= 3 AS committee_required,
    array_remove(ARRAY[
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
