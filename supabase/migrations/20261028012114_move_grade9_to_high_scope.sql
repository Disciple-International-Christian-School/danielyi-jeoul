-- Production migration 20261028012114, applied to jgrzsfomcwfiukkaqtos.
-- Grade 9 is HIGH responsibility; original student grade and NET calculation unchanged.
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
    pr.core_student_id
   FROM reflection_records r
     JOIN point_records pr ON pr.id = r.point_record_id AND pr.deleted_at IS NULL AND pr.superseded_by_import_id IS NULL
     JOIN v_reflection_eligible_penalties e ON e.point_record_id = pr.id
     JOIN students s ON s.core_student_id = pr.core_student_id;

CREATE OR REPLACE FUNCTION private.discipline_history(p_student_id uuid, p_start date, p_end date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_role public.admin_role; v_scope public.discipline_scope; v_result jsonb; v_term uuid;
begin
 if v_uid is null then raise exception '로그인이 필요합니다.'; end if;
 v_role:=private.current_admin_role(); v_scope:=private.current_admin_scope();
 if v_role is null and (p_student_id is null or not exists(select 1 from core.students where id=p_student_id and auth_user_id=v_uid)) then raise exception '본인 이력만 조회할 수 있습니다.'; end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>800 then raise exception '조회 기간을 확인하세요.'; end if;
 select id into v_term from core.academic_terms where is_current limit 1;
 with identities as (
   select s.id,s.student_no,s.name,s.is_active,coalesce(c.grade,h.grade) grade,coalesce(c.label,h.source_class) homeroom
   from core.students s left join core.enrollments e on e.student_id=s.id and e.term_id=v_term left join core.classes c on c.id=e.class_id
   left join lateral(select grade,source_class from discipline.weekly_balances where core_student_id=s.id and term_id=v_term and is_current order by week_start desc limit 1) h on true
   where (p_student_id is null or s.id=p_student_id)
 ), allowed as (
   select * from identities i where (v_role is null and i.id=p_student_id) or (v_role is not null and (v_scope='ALL' or (v_scope='ELEMENTARY' and i.grade between 1 and 6) or (v_scope='MIDDLE' and i.grade between 7 and 8) or (v_scope='HIGH' and i.grade between 9 and 12)))
 ), balances as (
   select w.core_student_id,w.week_start,(w.week_start+6) week_end,w.positive_points,w.negative_points,w.source_net net,
     null::int incident_count,'WEEKLY'::text source,w.review_note,w.batch_id::text source_id
   from discipline.weekly_balances w join allowed a on a.id=w.core_student_id
   where w.is_current and w.term_id=v_term and w.week_start<=p_end and w.week_start+6>=p_start
   union all
   select pr.core_student_id,date_trunc('week',pr.recorded_at::timestamp)::date,date_trunc('week',pr.recorded_at::timestamp)::date+6,
     coalesce(sum(pr.points) filter(where pr.type='POSITIVE'),0)::int,coalesce(sum(pr.points) filter(where pr.type='NEGATIVE'),0)::int,
     (coalesce(sum(pr.points) filter(where pr.type='POSITIVE'),0)-coalesce(sum(pr.points) filter(where pr.type='NEGATIVE'),0))::int,
     count(*) filter(where pr.type='NEGATIVE')::int,'DAILY',null,null
   from public.point_records pr join allowed a on a.id=pr.core_student_id where pr.deleted_at is null and pr.superseded_by_import_id is null and pr.recorded_at between p_start and p_end
   group by pr.core_student_id,date_trunc('week',pr.recorded_at::timestamp)::date
 )
 select jsonb_build_object('rows',coalesce((select jsonb_agg(to_jsonb(x) order by x.week_start,x.student_name) from(select b.*,a.name student_name,a.student_no,a.homeroom,a.grade,a.is_active from balances b join allowed a on a.id=b.core_student_id) x),'[]'),
 'students',coalesce((select jsonb_agg(to_jsonb(a)) from allowed a),'[]'),
 'calendar',coalesce((select jsonb_agg(to_jsonb(c) order by c.week_start) from discipline.history_calendar c where c.term_id=v_term and c.week_start<=p_end and c.week_start+6>=p_start),'[]'),
 'daily_starts_on',(select daily_starts_on from discipline.history_settings where term_id=v_term and activated_at is not null)) into v_result;
 return v_result;
end $function$
;

COMMENT ON COLUMN public.admins.discipline_scope IS
'SEONDO responsibility scope: ELEMENTARY G1-6, MIDDLE G7-8, HIGH G9-12, ALL for lead/shared legacy.';
