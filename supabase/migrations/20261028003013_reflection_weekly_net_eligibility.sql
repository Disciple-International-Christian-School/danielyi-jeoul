-- Applied to production project jgrzsfomcwfiukkaqtos, migration 20261028003013.
-- Reflection eligibility: only weekly merit-minus-penalty NET < 0, and the
-- incident must have moved the running NET below zero at entry time.
-- All other point records remain unchanged for audit and weekly score history.
-- The shadow weekly score uses penalty-minus-merit, so > 0 means user-facing NET < 0.


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
          WHERE pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
        )
 SELECT x.point_record_id,
    x.core_student_id,
    x.week_start
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
            WHEN s.grade >= 7 AND s.grade <= 9 THEN 'MIDDLE'::discipline_scope
            ELSE 'HIGH'::discipline_scope
        END AS assigned_scope,
    pr.core_student_id
   FROM reflection_records r
     JOIN point_records pr ON pr.id = r.point_record_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
     JOIN v_reflection_eligible_penalties e ON e.point_record_id = pr.id
     JOIN students s ON s.core_student_id = pr.core_student_id;

CREATE OR REPLACE VIEW public.v_point_records WITH (security_invoker = true) AS
SELECT pr.id,
    s.id AS student_id,
    s.name AS student_name,
    pr.type,
    pr.item,
    pr.points,
    pr.recorded_at,
    pr.entered_by_name,
    pr.created_at,
    r.id AS reflection_id,
    r.submitted AS reflection_submitted,
    r.submission_deadline AS reflection_deadline,
    r.submitted_at AS reflection_submitted_at,
        CASE
            WHEN r.id IS NULL THEN NULL::text
            WHEN r.submitted THEN 'SUBMITTED'::text
            WHEN r.due_at < now() THEN 'DOUBLE'::text
            ELSE 'MISSING'::text
        END AS reflection_status,
    r.due_at AS reflection_due_at,
    pr.core_student_id
   FROM point_records pr
     JOIN students s ON s.core_student_id = pr.core_student_id
     LEFT JOIN reflection_records r ON r.point_record_id = pr.id AND (EXISTS ( SELECT 1
           FROM v_reflection_eligible_penalties e
          WHERE e.point_record_id = pr.id))
  WHERE pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL;

CREATE OR REPLACE VIEW public.v_daily_discipline_notice WITH (security_invoker = true) AS
SELECT pr.id AS point_record_id,
    pr.recorded_at,
    ds.legacy_student_id AS student_id,
    ds.core_student_id,
    ds.student_no,
    ds.name AS student_name,
    ds.grade,
    ds.homeroom,
    pr.item,
    pr.points,
    r.id AS reflection_id,
    r.submitted AS reflection_submitted,
    r.due_at AS reflection_due_at,
        CASE
            WHEN r.id IS NULL THEN NULL::text
            WHEN r.submitted THEN 'SUBMITTED'::text
            WHEN r.due_at < now() THEN 'DOUBLE'::text
            ELSE 'MISSING'::text
        END AS reflection_status
   FROM point_records pr
     JOIN v_discipline_students ds ON ds.core_student_id = pr.core_student_id
     LEFT JOIN reflection_records r ON r.point_record_id = pr.id AND (EXISTS ( SELECT 1
           FROM v_reflection_eligible_penalties e
          WHERE e.point_record_id = pr.id))
  WHERE pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.type = 'NEGATIVE'::point_type;

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
           FROM v_weekly_scores_core_shadow ws
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
            WHEN COALESCE(w.physical_training_required, false) THEN '체력훈련 대상'::text
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
    COALESCE(w.physical_training_required, false) AS physical_training_required,
    st.period_id AS settlement_period_id,
    st.period_label AS settlement_period_label,
    st.starts_on AS settlement_starts_on,
    COALESCE(st.positive_points, 0) AS settlement_positive_points,
    COALESCE(st.negative_points, 0) AS settlement_penalty_points,
    COALESCE(st.net_penalty_points, 0) AS settlement_net_penalty_points,
    COALESCE(st.physical_training_weeks, 0) AS physical_training_weeks,
    COALESCE(st.committee_required, false) AS committee_required
   FROM v_discipline_students ds
     JOIN students ls ON ls.id = ds.legacy_student_id
     LEFT JOIN lifetime lt ON lt.core_student_id = ds.core_student_id
     LEFT JOIN weekly w ON w.core_student_id = ds.core_student_id
     LEFT JOIN settlement st ON st.core_student_id = ds.core_student_id
     LEFT JOIN refl r ON r.core_student_id = ds.core_student_id
     LEFT JOIN active_pun ap ON ap.core_student_id = ds.core_student_id
     LEFT JOIN weeks3 w3 ON w3.core_student_id = ds.core_student_id;

GRANT SELECT ON public.v_reflection_eligible_penalties TO authenticated;

COMMENT ON VIEW public.v_reflection_eligible_penalties IS 'Weekly merit-minus-penalty NET negative now, and penalty was negative at entry; earlier covered penalties do not become retroactively due.';

COMMENT ON VIEW public.v_reflections IS 'Operational reflections eligible by current weekly NET and NET at the penalty entry.';
