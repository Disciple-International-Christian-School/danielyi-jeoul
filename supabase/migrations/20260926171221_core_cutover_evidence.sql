-- 2026-09-27
-- Aggregate-only evidence for the discipline Core UUID cut-over.
-- No student names, student numbers, Auth UUIDs, or per-student mappings.

create table if not exists discipline.core_cutover_evidence (
  id bigint generated always as identity primary key,
  stage text not null,
  captured_at timestamptz not null default now(),

  point_records_total int not null,
  point_records_core_linked int not null,
  point_records_mismatch int not null,
  punishments_total int not null,
  punishments_core_linked int not null,
  punishments_mismatch int not null,

  weekly_legacy_rows int not null,
  weekly_core_rows int not null,
  weekly_mismatches int not null,
  weekly_penalty_legacy_rows int not null,
  weekly_penalty_core_rows int not null,
  weekly_penalty_mismatches int not null,
  settlement_legacy_rows int not null,
  settlement_core_rows int not null,
  settlement_mismatches int not null,

  summary_legacy_rows int not null,
  summary_core_rows int not null,
  summary_mismatches int not null
);

alter table discipline.core_cutover_evidence enable row level security;

drop policy if exists core_cutover_evidence_read_lead
  on discipline.core_cutover_evidence;

create policy core_cutover_evidence_read_lead
  on discipline.core_cutover_evidence
  for select
  to authenticated
  using (private.current_admin_is_lead());

create or replace view public.v_discipline_core_cutover_evidence_latest
with (security_invoker = true) as
select
  id,
  stage,
  captured_at,
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
from discipline.core_cutover_evidence
order by captured_at desc, id desc
limit 1;

grant select on public.v_discipline_core_cutover_evidence_latest to authenticated;

comment on table discipline.core_cutover_evidence is
  'Aggregate-only checkpoints proving discipline Core UUID cut-over readiness. Contains no per-student identity data.';
