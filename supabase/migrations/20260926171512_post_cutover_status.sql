-- 2026-09-27
-- Record and expose the verified post-cutover state.

insert into discipline.core_cutover_evidence (
  stage,
  point_records_total,
  point_records_core_linked,
  point_records_mismatch,
  punishments_total,
  punishments_core_linked,
  punishments_mismatch,
  weekly_legacy_rows,
  weekly_core_rows,
  weekly_mismatches,
  weekly_penalty_legacy_rows,
  weekly_penalty_core_rows,
  weekly_penalty_mismatches,
  settlement_legacy_rows,
  settlement_core_rows,
  settlement_mismatches,
  summary_legacy_rows,
  summary_core_rows,
  summary_mismatches
)
select
  'POST_LEGACY_COLUMN_DROP_VERIFIED',
  fk.point_records_total,
  fk.point_records_core_linked,
  fk.point_records_mismatch,
  fk.punishments_total,
  fk.punishments_core_linked,
  fk.punishments_mismatch,
  e.weekly_legacy_rows,
  e.weekly_core_rows,
  e.weekly_mismatches,
  e.weekly_penalty_legacy_rows,
  e.weekly_penalty_core_rows,
  e.weekly_penalty_mismatches,
  e.settlement_legacy_rows,
  e.settlement_core_rows,
  e.settlement_mismatches,
  e.summary_legacy_rows,
  e.summary_core_rows,
  e.summary_mismatches
from public.v_discipline_core_fk_readiness fk
cross join lateral (
  select *
  from discipline.core_cutover_evidence
  order by captured_at desc, id desc
  limit 1
) e;

create or replace view public.v_discipline_core_cutover_status
with (security_invoker = true) as
with latest as (
  select *
  from discipline.core_cutover_evidence
  order by captured_at desc, id desc
  limit 1
),
column_state as (
  select
    not exists (
      select 1
      from information_schema.columns
      where table_schema='public'
        and table_name='point_records'
        and column_name='student_id'
    )
    and not exists (
      select 1
      from information_schema.columns
      where table_schema='public'
        and table_name='punishments'
        and column_name='student_id'
    ) as legacy_columns_removed
)
select
  latest.stage,
  latest.captured_at,
  cs.legacy_columns_removed,
  fk.point_records_total,
  fk.point_records_core_linked,
  fk.point_records_mismatch,
  fk.punishments_total,
  fk.punishments_core_linked,
  fk.punishments_mismatch,
  latest.weekly_mismatches,
  latest.weekly_penalty_mismatches,
  latest.settlement_mismatches,
  latest.summary_mismatches,
  (
    cs.legacy_columns_removed
    and fk.point_records_total = fk.point_records_core_linked
    and fk.point_records_mismatch = 0
    and fk.punishments_total = fk.punishments_core_linked
    and fk.punishments_mismatch = 0
    and latest.weekly_mismatches = 0
    and latest.weekly_penalty_mismatches = 0
    and latest.settlement_mismatches = 0
    and latest.summary_mismatches = 0
  ) as cutover_completed
from latest
cross join column_state cs
cross join public.v_discipline_core_fk_readiness fk;

grant select on public.v_discipline_core_cutover_status to authenticated;

comment on view public.v_discipline_core_cutover_status is
  'Current discipline canonical-identity cut-over state plus aggregate pre-drop parity evidence.';
