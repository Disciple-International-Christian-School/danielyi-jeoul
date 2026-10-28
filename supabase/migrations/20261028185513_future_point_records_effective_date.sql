-- Effective-date projection of future point records.
-- Raw point_records are saved/audited immediately, but current scores and actionable
-- reflections exclude future records until local KST recorded_at is reached.
CREATE OR REPLACE VIEW public.v_weekly_scores_core_shadow WITH (security_invoker = true) AS
SELECT s.id AS student_id,
    pr.core_student_id,
    date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date AS week_start,
    COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'POSITIVE'::point_type), 0::bigint)::integer AS positive_points,
    COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint)::integer AS negative_points,
    (COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint) - COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'POSITIVE'::point_type), 0::bigint))::integer AS net_penalty_points,
    COALESCE(count(*) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint)::integer AS penalty_incident_count,
    COALESCE(count(*) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint) >= 3 OR (COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint) - COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'POSITIVE'::point_type), 0::bigint)) >= 8 AS physical_training_required
   FROM point_records pr
     JOIN students s ON s.core_student_id = pr.core_student_id
  WHERE pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at <= private.kst_today()
  GROUP BY s.id, pr.core_student_id, (date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date);

CREATE OR REPLACE VIEW public.v_weekly_penalties_core_shadow WITH (security_invoker = true) AS
SELECT s.id AS student_id,
    pr.core_student_id,
    date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date AS week_start,
    sum(pr.points)::integer AS penalty_points,
    count(*)::integer AS record_count
   FROM point_records pr
     JOIN students s ON s.core_student_id = pr.core_student_id
  WHERE pr.type = 'NEGATIVE'::point_type AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at <= private.kst_today()
  GROUP BY s.id, pr.core_student_id, (date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date);

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
    x.week_start
   FROM sequenced x
     JOIN v_weekly_scores_core_shadow w ON w.core_student_id = x.core_student_id AND w.week_start = x.week_start
  WHERE x.type = 'NEGATIVE'::point_type AND x.net_at_entry < 0 AND w.net_penalty_points > 0;

CREATE OR REPLACE VIEW public.v_settlement_scores_core_shadow WITH (security_invoker = true) AS
WITH period_students AS (
         SELECT sp.id AS period_id,
            sp.label AS period_label,
            sp.starts_on,
            COALESCE(sp.ends_on, private.kst_today()) AS effective_end,
            sp.ends_on,
            ds.legacy_student_id AS student_id,
            ds.core_student_id,
            ds.student_no,
            ds.name AS student_name,
            ds.grade,
            ds.homeroom
           FROM settlement_periods sp
             CROSS JOIN v_discipline_students ds
        ), period_totals AS (
         SELECT ps_1.period_id,
            ps_1.core_student_id,
            COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'POSITIVE'::point_type), 0::bigint)::integer AS positive_points,
            COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint)::integer AS negative_points
           FROM period_students ps_1
             LEFT JOIN point_records pr ON pr.core_student_id = ps_1.core_student_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at >= ps_1.starts_on AND pr.recorded_at <= LEAST(ps_1.effective_end, private.kst_today())
          GROUP BY ps_1.period_id, ps_1.core_student_id
        ), period_weekly AS (
         SELECT ps_1.period_id,
            ps_1.core_student_id,
            date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date AS week_start,
            COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'POSITIVE'::point_type), 0::bigint)::integer AS positive_points,
            COALESCE(sum(pr.points) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint)::integer AS negative_points,
            COALESCE(count(*) FILTER (WHERE pr.type = 'NEGATIVE'::point_type), 0::bigint)::integer AS penalty_incident_count
           FROM period_students ps_1
             JOIN point_records pr ON pr.core_student_id = ps_1.core_student_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at >= (( SELECT academic_terms.starts_on
                   FROM core.academic_terms
                  WHERE academic_terms.is_current
                 LIMIT 1)) AND pr.recorded_at <= LEAST(ps_1.effective_end, private.kst_today())
          GROUP BY ps_1.period_id, ps_1.core_student_id, (date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date)
        ), training_weeks AS (
         SELECT pw.period_id,
            pw.core_student_id,
            pw.week_start
           FROM period_weekly pw
          WHERE pw.penalty_incident_count >= 3 OR (pw.negative_points - pw.positive_points) >= 8
        UNION
         SELECT ps_1.period_id,
            overdue.core_student_id,
            overdue.training_week_start
           FROM period_students ps_1
             JOIN v_reflection_training_overdue overdue ON overdue.core_student_id = ps_1.core_student_id
          WHERE overdue.training_on >= (( SELECT academic_terms.starts_on
                   FROM core.academic_terms
                  WHERE academic_terms.is_current
                 LIMIT 1)) AND overdue.training_on <= ps_1.effective_end
        ), training_runs AS (
         SELECT pw.period_id,
            pw.core_student_id,
            pw.week_start - (7 * row_number() OVER (PARTITION BY pw.period_id, pw.core_student_id ORDER BY pw.week_start))::integer AS run_key
           FROM training_weeks pw
        ), training_counts AS (
         SELECT runs.period_id,
            runs.core_student_id,
            max(runs.run_length)::integer AS physical_training_weeks
           FROM ( SELECT training_runs.period_id,
                    training_runs.core_student_id,
                    training_runs.run_key,
                    count(*) AS run_length
                   FROM training_runs
                  GROUP BY training_runs.period_id, training_runs.core_student_id, training_runs.run_key) runs
          GROUP BY runs.period_id, runs.core_student_id
        )
 SELECT ps.period_id,
    ps.period_label,
    ps.starts_on,
    ps.ends_on,
    ps.effective_end,
    ps.ends_on IS NULL AS is_open,
    ps.student_id,
    ps.core_student_id,
    ps.student_no,
    ps.student_name,
    ps.grade,
    ps.homeroom,
    pt.positive_points,
    pt.negative_points,
    pt.negative_points - pt.positive_points AS net_penalty_points,
    COALESCE(tc.physical_training_weeks, 0) AS physical_training_weeks,
    COALESCE(tc.physical_training_weeks, 0) >= 3 AS committee_required
   FROM period_students ps
     JOIN period_totals pt ON pt.period_id = ps.period_id AND pt.core_student_id = ps.core_student_id
     LEFT JOIN training_counts tc ON tc.period_id = ps.period_id AND tc.core_student_id = ps.core_student_id;

CREATE OR REPLACE VIEW public.v_student_summary_core_shadow WITH (security_invoker = true) AS
WITH lifetime AS (
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
            ss.net_penalty_points,
            ss.physical_training_weeks,
            ss.committee_required
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
            WHEN COALESCE(st.committee_required, false) THEN '징계위원회 대상'::text
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
    COALESCE(st.physical_training_weeks, 0) AS physical_training_weeks,
    COALESCE(st.committee_required, false) AS committee_required,
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
     LEFT JOIN refl r ON r.core_student_id = ds.core_student_id
     LEFT JOIN active_pun ap ON ap.core_student_id = ds.core_student_id
     LEFT JOIN weeks3 w3 ON w3.core_student_id = ds.core_student_id
     LEFT JOIN training_overdue tov ON tov.core_student_id = ds.core_student_id;
