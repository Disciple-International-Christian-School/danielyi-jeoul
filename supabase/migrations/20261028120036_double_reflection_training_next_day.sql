-- Production migration 20261028120036, applied to jgrzsfomcwfiukkaqtos.
-- 3rd rule: unresolved double-paper after 17:00 => physical training next KST day.
-- First double-submit day is the original deadline day if before 17:00, otherwise next day.
-- A single overdue event counts once in the first training week, never every pending week.
-- Preserve existing NET/occurrence rules, academic-term three-week streak, Core IDs and audit records.
CREATE OR REPLACE VIEW public.v_reflection_training_overdue WITH (security_invoker = true) AS
 WITH pending AS (
         SELECT r.id AS reflection_id,
            r.core_student_id,
            r.due_at,
            (r.due_at AT TIME ZONE 'Asia/Seoul'::text)::date AS initial_due_date,
            (r.due_at AT TIME ZONE 'Asia/Seoul'::text)::time without time zone AS initial_due_time
           FROM v_reflections r
          WHERE r.status = 'DOUBLE'::text AND NOT r.submitted
        ), scheduled AS (
         SELECT pending.reflection_id,
            pending.core_student_id,
            pending.due_at,
            pending.initial_due_date +
                CASE
                    WHEN pending.initial_due_time >= '17:00:00'::time without time zone THEN 1
                    ELSE 0
                END AS double_submit_date
           FROM pending
        )
 SELECT reflection_id,
    core_student_id,
    due_at,
    double_submit_date,
    ((double_submit_date + '17:00:00'::time without time zone) AT TIME ZONE 'Asia/Seoul'::text) AS double_submit_deadline,
    double_submit_date + 1 AS training_on,
    date_trunc('week'::text, (double_submit_date + 1)::timestamp without time zone)::date AS training_week_start
   FROM scheduled;

CREATE OR REPLACE VIEW public.v_training_weekly_eligibility WITH (security_invoker = true) AS
 WITH overdue_weeks AS (
         SELECT v_reflection_training_overdue.core_student_id,
            v_reflection_training_overdue.training_week_start AS week_start,
            min(v_reflection_training_overdue.training_on) AS first_training_on
           FROM v_reflection_training_overdue
          WHERE v_reflection_training_overdue.training_on <= private.kst_today()
          GROUP BY v_reflection_training_overdue.core_student_id, v_reflection_training_overdue.training_week_start
        )
 SELECT s.id AS student_id,
    s.core_student_id,
    COALESCE(w.week_start, o.week_start) AS week_start,
    COALESCE(w.positive_points, 0) AS positive_points,
    COALESCE(w.negative_points, 0) AS negative_points,
    COALESCE(w.net_penalty_points, 0) AS net_penalty_points,
    COALESCE(w.penalty_incident_count, 0) AS penalty_incident_count,
    COALESCE(w.physical_training_required, false) OR o.core_student_id IS NOT NULL AS physical_training_required,
    o.first_training_on AS reflection_training_on
   FROM v_weekly_scores_core_shadow w
     FULL JOIN overdue_weeks o ON o.core_student_id = w.core_student_id AND o.week_start = w.week_start
     JOIN students s ON s.core_student_id = COALESCE(w.core_student_id, o.core_student_id);

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
             LEFT JOIN point_records pr ON pr.core_student_id = ps_1.core_student_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at >= ps_1.starts_on AND pr.recorded_at <= ps_1.effective_end
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
                 LIMIT 1)) AND pr.recorded_at <= ps_1.effective_end
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
             LEFT JOIN point_records pr ON pr.core_student_id = ds_1.core_student_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
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

CREATE OR REPLACE VIEW public.v_student_summary WITH (security_invoker = true) AS
 SELECT id,
    name,
    grade,
    created_at,
    updated_at,
    positive_points,
    negative_points,
    weekly_penalty_points,
    monthly_penalty_points,
    weekly_record_count,
    punishment,
    statuses,
    core_student_id,
    student_no,
    homeroom,
    weekly_positive_points,
    weekly_net_penalty_points,
    physical_training_required,
    settlement_period_id,
    settlement_period_label,
    settlement_starts_on,
    settlement_positive_points,
    settlement_penalty_points,
    settlement_net_penalty_points,
    physical_training_weeks,
    committee_required,
    physical_training_reasons
   FROM v_student_summary_core_shadow;

CREATE OR REPLACE VIEW public.v_weekly_discipline_report WITH (security_invoker = true) AS
 SELECT private.kst_week_start() AS week_start,
    id AS student_id,
    core_student_id,
    student_no,
    name AS student_name,
    grade,
    homeroom,
    weekly_positive_points,
    weekly_penalty_points,
    weekly_net_penalty_points,
    weekly_record_count AS penalty_incident_count,
    physical_training_required,
    settlement_period_id,
    settlement_period_label,
    settlement_starts_on,
    settlement_positive_points,
    settlement_penalty_points,
    settlement_net_penalty_points,
    physical_training_weeks,
    committee_required,
    statuses,
    physical_training_reasons
   FROM v_student_summary s;
GRANT SELECT ON public.v_reflection_training_overdue TO authenticated;
GRANT SELECT ON public.v_training_weekly_eligibility TO authenticated;
COMMENT ON VIEW public.v_reflection_training_overdue IS 'Pending 2x papers; double submission by 17:00 on first actionable day; training from following KST day.';
COMMENT ON VIEW public.v_training_weekly_eligibility IS 'Weekly training conditions: overdue 2x-paper counts once in the week of first training obligation.';
