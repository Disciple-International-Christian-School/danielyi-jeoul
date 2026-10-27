-- Period totals and academic-term consecutive training weeks are independent.
-- Training: >=3 penalty occurrences OR merit-minus-penalty <= -8.
-- Discipline: three adjacent Monday-based qualifying weeks. Gaps break runs.
create or replace view public.v_settlement_scores_core_shadow with(security_invoker=true) as
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
             JOIN point_records pr ON pr.core_student_id = ps_1.core_student_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL AND pr.recorded_at >= (select starts_on from core.academic_terms where is_current limit 1) AND pr.recorded_at <= ps_1.effective_end
          GROUP BY ps_1.period_id, ps_1.core_student_id, (date_trunc('week'::text, pr.recorded_at::timestamp without time zone)::date)
        ), training_runs AS (
 select pw.period_id,pw.core_student_id,
 pw.week_start - (7 * row_number() over(partition by pw.period_id,pw.core_student_id order by pw.week_start))::int as run_key
 from period_weekly pw where pw.penalty_incident_count>=3 or pw.negative_points-pw.positive_points>=8
), training_counts AS (
 select period_id,core_student_id,max(run_length)::int as physical_training_weeks
 from (select period_id,core_student_id,run_key,count(*) run_length from training_runs group by period_id,core_student_id,run_key) runs
 group by period_id,core_student_id
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
comment on view public.v_settlement_scores_core_shadow is 'Period totals; maximum consecutive training weeks in the current term through period end. Committee requires >=3 consecutive weeks only.';
