// Thin data layer over supabase-js. Hook names and call shapes mimic the old
// orval-generated client (@workspace/api-client-react) so page components
// changed minimally during the port. Reads go to views, writes to tables/RPCs;
// all business rules live in Postgres.
import { useMutation, useQuery } from '@tanstack/react-query';

import { supabase } from './supabase';

// ---------------------------------------------------------------------------
// Domain types (hand-written; no codegen)
// ---------------------------------------------------------------------------

export type Role = 'SEONDO' | 'SASAENG';
export type PointType = 'POSITIVE' | 'NEGATIVE';
export type ReflectionStatus = 'SUBMITTED' | 'MISSING' | 'DOUBLE';
export type DisciplineScope = 'ALL' | 'ELEMENTARY' | 'MIDDLE' | 'HIGH';

export const PUNISHMENT_TYPES = ['운동금지', '간식금지', '면회금지'] as const;
export type PunishmentType = (typeof PUNISHMENT_TYPES)[number];

export interface StudentSummary {
  /** Legacy integer route id until discipline FK cut-over. */
  id: number;
  /** Canonical DICS Core student UUID; null until legacy mapping is complete. */
  coreStudentId: string | null;
  studentNo: string | null;
  name: string;
  grade: number;
  homeroom: string | null;
  createdAt: string;
  updatedAt: string;

  // Lifetime raw totals.
  positivePoints: number;
  negativePoints: number;

  // Current Monday-based week.
  weeklyPositivePoints: number;
  weeklyPenaltyPoints: number;
  weeklyNetPenaltyPoints: number;
  weeklyRecordCount: number;
  physicalTrainingRequired: boolean;

  // Current admin-controlled settlement period.
  settlementPeriodId: number | null;
  settlementPeriodLabel: string | null;
  settlementStartsOn: string | null;
  settlementPositivePoints: number;
  settlementPenaltyPoints: number;
  settlementNetPenaltyPoints: number;
  physicalTrainingWeeks: number;
  committeeRequired: boolean;

  /** Legacy compatibility alias. Do not use for new UI. */
  monthlyPenaltyPoints: number;

  punishment: string | null;
  statuses: string[];
}

export interface StudentDetail extends StudentSummary {
  punishments: Punishment[];
}

export interface PointRecordReflection {
  id: number;
  submitted: boolean;
  deadline: string | null;
  submittedAt: string | null;
  status: ReflectionStatus;
}

export interface PointRecord {
  id: number;
  studentId: number;
  studentName: string;
  type: PointType;
  item: string;
  points: number;
  recordedAt: string;
  enteredByName: string;
  createdAt: string;
  reflection: PointRecordReflection | null;
}

export interface Reflection {
  id: number;
  pointRecordId: number;
  studentId: number;
  studentName: string;
  grade: number;
  item: string;
  points: number;
  recordedAt: string;
  submitted: boolean;
  submissionDeadline: string;
  dueAt: string;
  deadlineChangeReason: string | null;
  submittedAt: string | null;
  status: ReflectionStatus;
  assignedScope: Exclude<DisciplineScope, 'ALL'>;
}

export interface DashboardCounts {
  students: number;
  weeklyTargets: number;
  committeeTargets: number;
  missingReflections: number;
  doubleReflections: number;
  activePunishments: number;
}

export interface Dashboard {
  counts: DashboardCounts;
  students: StudentSummary[];
}

export interface CoreSetupStatus {
  termId: string;
  termCode: string;
  termName: string;
  startsOn: string;
  endsOn: string;
  classCount: number;
  enrollmentCount: number;
  grade9Total: number;
  grade9Assigned: number;
  grade9Pending: number;
}

export interface Grade9Assignment {
  studentId: number;
  coreStudentId: string;
  studentName: string;
  grade: number;
  section: string | null;
  homeroom: string | null;
}

export interface SettlementPeriod {
  id: number;
  label: string;
  startsOn: string;
  endsOn: string | null;
  createdAt: string;
}

export interface DailyDisciplineNotice {
  pointRecordId: number;
  recordedAt: string;
  studentId: number;
  coreStudentId: string | null;
  studentNo: string | null;
  studentName: string;
  grade: number;
  homeroom: string | null;
  item: string;
  points: number;
  reflectionId: number | null;
  reflectionSubmitted: boolean | null;
  reflectionDueAt: string | null;
  reflectionStatus: ReflectionStatus | null;
}

export interface DisciplineAuditLog {
  id: number;
  actorUserId: string | null;
  actorName: string;
  actorRole: Role | null;
  action: 'INSERT' | 'UPDATE' | 'DELETE';
  entityType: string;
  entityId: string | null;
  beforeData: Record<string, unknown> | null;
  afterData: Record<string, unknown> | null;
  createdAt: string;
}

export interface CoreMigrationReadiness {
  coreTotal: number;
  activeStudents: number;
  studentNoAssigned: number;
  authLinked: number;
  termCount: number;
  currentTermCount: number;
  classCount: number;
  currentEnrollmentCount: number;
  danielBridgeCount: number;
}

export interface CoreStudentReadiness {
  coreStudentId: string;
  studentNo: string | null;
  name: string;
  grade: number;
  hasStudentNo: boolean;
  hasAuthLink: boolean;
  hasCurrentEnrollment: boolean;
  homeroom: string | null;
  readinessStatus: 'READY' | 'PARTIAL' | 'CORE_ONLY';
}

export interface DepartmentMeritStatus {
  weekStart: string;
  departmentId: string;
  departmentCode: string;
  departmentName: string;
  membershipId: string;
  coreStudentId: string;
  studentNo: string | null;
  studentName: string;
  grade: number | null;
  homeroom: string | null;
  points: number;
  itemLabel: string;
  pointRecordId: number | null;
  generated: boolean;
}

export interface WeeklyDisciplineReport {
  weekStart: string;
  studentId: number;
  coreStudentId: string | null;
  studentNo: string | null;
  studentName: string;
  grade: number;
  homeroom: string | null;
  weeklyPositivePoints: number;
  weeklyPenaltyPoints: number;
  weeklyNetPenaltyPoints: number;
  penaltyIncidentCount: number;
  physicalTrainingRequired: boolean;
  settlementPeriodId: number | null;
  settlementPeriodLabel: string | null;
  settlementStartsOn: string | null;
  settlementPositivePoints: number;
  settlementPenaltyPoints: number;
  settlementNetPenaltyPoints: number;
  physicalTrainingWeeks: number;
  committeeRequired: boolean;
  statuses: string[];
}

export interface Punishment {
  id: number;
  studentId: number;
  studentName: string;
  grade: number;
  types: string[];
  startDate: string;
  endDate: string;
  enteredByName: string;
  violated: boolean;
  createdAt: string;
}

export interface PointItem {
  id: number;
  name: string;
  type: PointType;
  fixedPoints: number | null;
  isFixed: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

// Write payloads
export interface StudentInput { name: string; grade: number; }
export interface PointItemInput {
  name: string;
  type: PointType;
  fixedPoints: number | null;
  isFixed: boolean;
  isActive: boolean;
}
export interface PointItemImportRow { name: string; fixedPoints: number | null; }
export interface PointRecordInput {
  studentId: number;
  type: PointType;
  item: string;
  points: number;
  recordedAt: string;
  enteredByName: string;
  /** NEGATIVE only — null/undefined for POSITIVE records. */
  reflectionSubmitted?: boolean | null;
}
export interface PointRecordUpdateInput {
  points: number;
  item: string;
  recordedAt: string;
  enteredByName: string;
  reflectionSubmitted?: boolean | null;
}
export interface PunishmentInput {
  studentId: number;
  types: string[];
  startDate: string;
  endDate: string;
  enteredByName: string;
}

// ---------------------------------------------------------------------------
// DB row shapes (snake_case, exactly as the views/tables return them)
// ---------------------------------------------------------------------------

interface StudentSummaryRow {
  id: number;
  core_student_id: string | null;
  student_no: string | null;
  name: string;
  grade: number;
  homeroom: string | null;
  created_at: string;
  updated_at: string;

  positive_points: number;
  negative_points: number;

  weekly_positive_points: number;
  weekly_penalty_points: number;
  weekly_net_penalty_points: number;
  weekly_record_count: number;
  physical_training_required: boolean;

  settlement_period_id: number | null;
  settlement_period_label: string | null;
  settlement_starts_on: string | null;
  settlement_positive_points: number;
  settlement_penalty_points: number;
  settlement_net_penalty_points: number;
  physical_training_weeks: number;
  committee_required: boolean;

  monthly_penalty_points: number;
  punishment: string | null;
  statuses: string[] | null;
}
interface ReflectionRow {
  id: number; point_record_id: number; student_id: number; student_name: string;
  grade: number; item: string; points: number; recorded_at: string;
  submitted: boolean; submission_deadline: string; due_at: string;
  deadline_change_reason: string | null; submitted_at: string | null;
  status: ReflectionStatus;
  assigned_scope: Exclude<DisciplineScope, 'ALL'>;
}
interface DashboardCountsRow {
  students: number;
  weekly_targets: number;
  committee_targets: number;
  missing_reflections: number;
  double_reflections: number;
  active_punishments: number;
}

interface CoreSetupStatusRow {
  term_id: string;
  term_code: string;
  term_name: string;
  starts_on: string;
  ends_on: string;
  class_count: number;
  enrollment_count: number;
  grade9_total: number;
  grade9_assigned: number;
  grade9_pending: number;
}

interface Grade9AssignmentRow {
  student_id: number;
  core_student_id: string;
  student_name: string;
  grade: number;
  section: string | null;
  homeroom: string | null;
}

interface SettlementPeriodRow {
  id: number;
  label: string;
  starts_on: string;
  ends_on: string | null;
  created_at: string;
}

interface CoreMigrationReadinessRow {
  core_total: number;
  active_students: number;
  student_no_assigned: number;
  auth_linked: number;
  term_count: number;
  current_term_count: number;
  class_count: number;
  current_enrollment_count: number;
  daniel_bridge_count: number;
}

interface CoreStudentReadinessRow {
  core_student_id: string;
  student_no: string | null;
  name: string;
  grade: number;
  has_student_no: boolean;
  has_auth_link: boolean;
  has_current_enrollment: boolean;
  homeroom: string | null;
  readiness_status: 'READY' | 'PARTIAL' | 'CORE_ONLY';
}

interface DailyDisciplineNoticeRow {
  point_record_id: number;
  recorded_at: string;
  student_id: number;
  core_student_id: string | null;
  student_no: string | null;
  student_name: string;
  grade: number;
  homeroom: string | null;
  item: string;
  points: number;
  reflection_id: number | null;
  reflection_submitted: boolean | null;
  reflection_due_at: string | null;
  reflection_status: ReflectionStatus | null;
}

interface DisciplineAuditLogRow {
  id: number;
  actor_user_id: string | null;
  actor_name: string;
  actor_role: Role | null;
  action: 'INSERT' | 'UPDATE' | 'DELETE';
  entity_type: string;
  entity_id: string | null;
  before_data: Record<string, unknown> | null;
  after_data: Record<string, unknown> | null;
  created_at: string;
}

interface DepartmentMeritStatusRow {
  week_start: string;
  department_id: string;
  department_code: string;
  department_name: string;
  membership_id: string;
  core_student_id: string;
  student_no: string | null;
  student_name: string;
  grade: number | null;
  homeroom: string | null;
  points: number;
  item_label: string;
  point_record_id: number | null;
  generated: boolean;
}

interface WeeklyDisciplineReportRow {
  week_start: string;
  student_id: number;
  core_student_id: string | null;
  student_no: string | null;
  student_name: string;
  grade: number;
  homeroom: string | null;
  weekly_positive_points: number;
  weekly_penalty_points: number;
  weekly_net_penalty_points: number;
  penalty_incident_count: number;
  physical_training_required: boolean;
  settlement_period_id: number | null;
  settlement_period_label: string | null;
  settlement_starts_on: string | null;
  settlement_positive_points: number;
  settlement_penalty_points: number;
  settlement_net_penalty_points: number;
  physical_training_weeks: number;
  committee_required: boolean;
  statuses: string[] | null;
}
interface PunishmentRow {
  id: number; student_id: number; student_name: string; grade: number;
  types: string[] | null; start_date: string; end_date: string;
  entered_by_name: string; violated: boolean; created_at: string;
}
interface PointRecordRow {
  id: number; student_id: number; student_name: string; type: PointType;
  item: string; points: number; recorded_at: string; entered_by_name: string;
  created_at: string; reflection_id: number | null;
  reflection_submitted: boolean | null; reflection_deadline: string | null;
  reflection_submitted_at: string | null; reflection_status: ReflectionStatus | null;
}
interface PointItemRow {
  id: number; name: string; type: PointType; fixed_points: number | null;
  is_fixed: boolean; is_active: boolean; created_at: string; updated_at: string;
}

// ---------------------------------------------------------------------------
// Mappers (snake_case rows → camelCase app types)
// ---------------------------------------------------------------------------

function mapStudent(row: StudentSummaryRow): StudentSummary {
  return {
    id: row.id,
    coreStudentId: row.core_student_id,
    studentNo: row.student_no,
    name: row.name,
    grade: row.grade,
    homeroom: row.homeroom,
    createdAt: row.created_at,
    updatedAt: row.updated_at,

    positivePoints: row.positive_points,
    negativePoints: row.negative_points,

    weeklyPositivePoints: row.weekly_positive_points,
    weeklyPenaltyPoints: row.weekly_penalty_points,
    weeklyNetPenaltyPoints: row.weekly_net_penalty_points,
    weeklyRecordCount: row.weekly_record_count,
    physicalTrainingRequired: row.physical_training_required,

    settlementPeriodId: row.settlement_period_id,
    settlementPeriodLabel: row.settlement_period_label,
    settlementStartsOn: row.settlement_starts_on,
    settlementPositivePoints: row.settlement_positive_points,
    settlementPenaltyPoints: row.settlement_penalty_points,
    settlementNetPenaltyPoints: row.settlement_net_penalty_points,
    physicalTrainingWeeks: row.physical_training_weeks,
    committeeRequired: row.committee_required,

    monthlyPenaltyPoints: row.monthly_penalty_points,
    punishment: row.punishment,
    statuses: row.statuses ?? [],
  };
}

function mapReflection(row: ReflectionRow): Reflection {
  return {
    id: row.id,
    pointRecordId: row.point_record_id,
    studentId: row.student_id,
    studentName: row.student_name,
    grade: row.grade,
    item: row.item,
    points: row.points,
    recordedAt: row.recorded_at,
    submitted: row.submitted,
    submissionDeadline: row.submission_deadline,
    dueAt: row.due_at,
    deadlineChangeReason: row.deadline_change_reason,
    submittedAt: row.submitted_at,
    status: row.status,
    assignedScope: row.assigned_scope,
  };
}

function mapDisciplineAuditLog(row: DisciplineAuditLogRow): DisciplineAuditLog {
  return {
    id: row.id,
    actorUserId: row.actor_user_id,
    actorName: row.actor_name,
    actorRole: row.actor_role,
    action: row.action,
    entityType: row.entity_type,
    entityId: row.entity_id,
    beforeData: row.before_data,
    afterData: row.after_data,
    createdAt: row.created_at,
  };
}

function mapCoreMigrationReadiness(row: CoreMigrationReadinessRow): CoreMigrationReadiness {
  return {
    coreTotal: row.core_total,
    activeStudents: row.active_students,
    studentNoAssigned: row.student_no_assigned,
    authLinked: row.auth_linked,
    termCount: row.term_count,
    currentTermCount: row.current_term_count,
    classCount: row.class_count,
    currentEnrollmentCount: row.current_enrollment_count,
    danielBridgeCount: row.daniel_bridge_count,
  };
}

function mapCoreStudentReadiness(row: CoreStudentReadinessRow): CoreStudentReadiness {
  return {
    coreStudentId: row.core_student_id,
    studentNo: row.student_no,
    name: row.name,
    grade: row.grade,
    hasStudentNo: row.has_student_no,
    hasAuthLink: row.has_auth_link,
    hasCurrentEnrollment: row.has_current_enrollment,
    homeroom: row.homeroom,
    readinessStatus: row.readiness_status,
  };
}

function mapDepartmentMeritStatus(row: DepartmentMeritStatusRow): DepartmentMeritStatus {
  return {
    weekStart: row.week_start,
    departmentId: row.department_id,
    departmentCode: row.department_code,
    departmentName: row.department_name,
    membershipId: row.membership_id,
    coreStudentId: row.core_student_id,
    studentNo: row.student_no,
    studentName: row.student_name,
    grade: row.grade,
    homeroom: row.homeroom,
    points: row.points,
    itemLabel: row.item_label,
    pointRecordId: row.point_record_id,
    generated: row.generated,
  };
}

function mapDailyDisciplineNotice(row: DailyDisciplineNoticeRow): DailyDisciplineNotice {
  return {
    pointRecordId: row.point_record_id,
    recordedAt: row.recorded_at,
    studentId: row.student_id,
    coreStudentId: row.core_student_id,
    studentNo: row.student_no,
    studentName: row.student_name,
    grade: row.grade,
    homeroom: row.homeroom,
    item: row.item,
    points: row.points,
    reflectionId: row.reflection_id,
    reflectionSubmitted: row.reflection_submitted,
    reflectionDueAt: row.reflection_due_at,
    reflectionStatus: row.reflection_status,
  };
}

function mapWeeklyDisciplineReport(row: WeeklyDisciplineReportRow): WeeklyDisciplineReport {
  return {
    weekStart: row.week_start,
    studentId: row.student_id,
    coreStudentId: row.core_student_id,
    studentNo: row.student_no,
    studentName: row.student_name,
    grade: row.grade,
    homeroom: row.homeroom,
    weeklyPositivePoints: row.weekly_positive_points,
    weeklyPenaltyPoints: row.weekly_penalty_points,
    weeklyNetPenaltyPoints: row.weekly_net_penalty_points,
    penaltyIncidentCount: row.penalty_incident_count,
    physicalTrainingRequired: row.physical_training_required,
    settlementPeriodId: row.settlement_period_id,
    settlementPeriodLabel: row.settlement_period_label,
    settlementStartsOn: row.settlement_starts_on,
    settlementPositivePoints: row.settlement_positive_points,
    settlementPenaltyPoints: row.settlement_penalty_points,
    settlementNetPenaltyPoints: row.settlement_net_penalty_points,
    physicalTrainingWeeks: row.physical_training_weeks,
    committeeRequired: row.committee_required,
    statuses: row.statuses ?? [],
  };
}

function mapCoreSetupStatus(row: CoreSetupStatusRow): CoreSetupStatus {
  return {
    termId: row.term_id,
    termCode: row.term_code,
    termName: row.term_name,
    startsOn: row.starts_on,
    endsOn: row.ends_on,
    classCount: row.class_count,
    enrollmentCount: row.enrollment_count,
    grade9Total: row.grade9_total,
    grade9Assigned: row.grade9_assigned,
    grade9Pending: row.grade9_pending,
  };
}

function mapGrade9Assignment(row: Grade9AssignmentRow): Grade9Assignment {
  return {
    studentId: row.student_id,
    coreStudentId: row.core_student_id,
    studentName: row.student_name,
    grade: row.grade,
    section: row.section,
    homeroom: row.homeroom,
  };
}

function mapSettlementPeriod(row: SettlementPeriodRow): SettlementPeriod {
  return {
    id: row.id,
    label: row.label,
    startsOn: row.starts_on,
    endsOn: row.ends_on,
    createdAt: row.created_at,
  };
}

function mapPunishment(row: PunishmentRow): Punishment {
  return {
    id: row.id,
    studentId: row.student_id,
    studentName: row.student_name,
    grade: row.grade,
    types: row.types ?? [],
    startDate: row.start_date,
    endDate: row.end_date,
    enteredByName: row.entered_by_name,
    violated: row.violated,
    createdAt: row.created_at,
  };
}

function mapPointRecord(row: PointRecordRow): PointRecord {
  return {
    id: row.id,
    studentId: row.student_id,
    studentName: row.student_name,
    type: row.type,
    item: row.item,
    points: row.points,
    recordedAt: row.recorded_at,
    enteredByName: row.entered_by_name,
    createdAt: row.created_at,
    reflection: row.reflection_id == null ? null : {
      id: row.reflection_id,
      submitted: row.reflection_submitted ?? false,
      deadline: row.reflection_deadline,
      submittedAt: row.reflection_submitted_at,
      status: row.reflection_status ?? 'MISSING',
    },
  };
}

function mapPointItem(row: PointItemRow): PointItem {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    fixedPoints: row.fixed_points,
    isFixed: row.is_fixed,
    isActive: row.is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** PostgREST errors (incl. RPC business-rule failures) carry Korean messages
 *  in error.message — throw them so react-query surfaces them to the toast. */
function unwrap<T>(result: { data: T | null; error: { message: string } | null }): T {
  if (result.error) throw new Error(result.error.message);
  if (result.data == null) throw new Error('요청을 처리하지 못했습니다.');
  return result.data;
}

// ---------------------------------------------------------------------------
// Query keys (names kept from the orval client for minimal page diffs)
// ---------------------------------------------------------------------------

export const getGetDashboardQueryKey = () => ['dashboard'] as const;
export const getListStudentsQueryKey = () => ['students'] as const;
export const getGetStudentQueryKey = (id: number) => ['students', id] as const;
export const getListPointRecordsQueryKey = (params: { studentId: number; limit?: number }) =>
  ['point-records', params] as const;
export const getListPointItemsQueryKey = (params?: { type?: PointType; includeInactive?: boolean }) =>
  ['point-items', params ?? {}] as const;
export const getListReflectionsQueryKey = () => ['reflections'] as const;
export const getListPunishmentsQueryKey = () => ['punishments'] as const;
export const getCurrentSettlementQueryKey = () => ['settlement', 'current'] as const;
export const getDailyDisciplineNoticeQueryKey = (recordedAt: string) => ['reports', 'daily-notice', recordedAt] as const;
export const getWeeklyDisciplineReportQueryKey = () => ['reports', 'weekly'] as const;
export const getDepartmentMeritStatusQueryKey = () => ['department-merits', 'current-week'] as const;
export const getCoreMigrationReadinessQueryKey = () => ['core', 'migration-readiness'] as const;
export const getCoreStudentReadinessQueryKey = () => ['core', 'student-readiness'] as const;
export const getDisciplineAuditLogsQueryKey = () => ['audit-logs', 'discipline'] as const;
export const getCoreSetupStatusQueryKey = () => ['core-setup', 'status'] as const;
export const getGrade9AssignmentsQueryKey = () => ['core-setup', 'grade9'] as const;

// ---------------------------------------------------------------------------
// Reads
// ---------------------------------------------------------------------------

async function fetchStudentSummaries(): Promise<StudentSummary[]> {
  const rows = unwrap<StudentSummaryRow[]>(
    await supabase.from('v_student_summary').select('*').order('weekly_net_penalty_points', { ascending: false }),
  );
  return rows.map(mapStudent);
}

export function useListStudents() {
  return useQuery({ queryKey: getListStudentsQueryKey(), queryFn: fetchStudentSummaries });
}

export function useGetDashboard() {
  return useQuery({
    queryKey: getGetDashboardQueryKey(),
    queryFn: async (): Promise<Dashboard> => {
      const [countsRes, students] = await Promise.all([
        supabase.from('v_dashboard_counts').select('*').single(),
        fetchStudentSummaries(),
      ]);
      const counts = unwrap<DashboardCountsRow>(countsRes as { data: DashboardCountsRow | null; error: { message: string } | null });
      return {
        counts: {
          students: counts.students,
          weeklyTargets: counts.weekly_targets,
          committeeTargets: counts.committee_targets,
          missingReflections: counts.missing_reflections,
          doubleReflections: counts.double_reflections,
          activePunishments: counts.active_punishments,
        },
        students,
      };
    },
  });
}

export function useGetStudent(id: number) {
  return useQuery({
    queryKey: getGetStudentQueryKey(id),
    queryFn: async (): Promise<StudentDetail> => {
      const [summaryRes, punishmentsRes] = await Promise.all([
        supabase.from('v_student_summary').select('*').eq('id', id).single(),
        supabase.from('v_punishments').select('*').eq('student_id', id).order('created_at', { ascending: false }),
      ]);
      const summary = unwrap<StudentSummaryRow>(summaryRes as { data: StudentSummaryRow | null; error: { message: string } | null });
      const punishments = unwrap<PunishmentRow[]>(punishmentsRes);
      return { ...mapStudent(summary), punishments: punishments.map(mapPunishment) };
    },
    enabled: Number.isFinite(id),
  });
}

export function useListPointRecords(params: { studentId: number; limit?: number }) {
  return useQuery({
    queryKey: getListPointRecordsQueryKey(params),
    queryFn: async (): Promise<PointRecord[]> => {
      const rows = unwrap<PointRecordRow[]>(
        await supabase
          .from('v_point_records')
          .select('*')
          .eq('student_id', params.studentId)
          .order('recorded_at', { ascending: false })
          .limit(params.limit ?? 100),
      );
      return rows.map(mapPointRecord);
    },
    enabled: Number.isFinite(params.studentId),
  });
}

export function useListPointItems(params?: { type?: PointType; includeInactive?: boolean }) {
  return useQuery({
    queryKey: getListPointItemsQueryKey(params),
    queryFn: async (): Promise<PointItem[]> => {
      let query = supabase.from('point_items').select('*');
      if (params?.type) query = query.eq('type', params.type);
      if (!params?.includeInactive) query = query.eq('is_active', true);
      const rows = unwrap<PointItemRow[]>(await query.order('created_at', { ascending: true }));
      return rows.map(mapPointItem);
    },
  });
}

/** Fetches every reflection row; the page filters ALL/SUBMITTED/MISSING/DOUBLE
 *  client-side (status is computed in the view, so it is always current). */
export function useListReflections() {
  return useQuery({
    queryKey: getListReflectionsQueryKey(),
    queryFn: async (): Promise<Reflection[]> => {
      const rows = unwrap<ReflectionRow[]>(
        await supabase.from('v_reflections').select('*').order('recorded_at', { ascending: false }),
      );
      return rows.map(mapReflection);
    },
  });
}

export function useListPunishments() {
  return useQuery({
    queryKey: getListPunishmentsQueryKey(),
    queryFn: async (): Promise<Punishment[]> => {
      const rows = unwrap<PunishmentRow[]>(
        await supabase.from('v_punishments').select('*').order('created_at', { ascending: false }),
      );
      return rows.map(mapPunishment);
    },
  });
}

export function useDisciplineAuditLogs() {
  return useQuery({
    queryKey: getDisciplineAuditLogsQueryKey(),
    queryFn: async (): Promise<DisciplineAuditLog[]> => {
      const rows = unwrap<DisciplineAuditLogRow[]>(
        await supabase
          .from('v_discipline_audit_logs')
          .select('*')
          .order('created_at', { ascending: false })
          .limit(200),
      );
      return rows.map(mapDisciplineAuditLog);
    },
  });
}

export function useCoreMigrationReadiness() {
  return useQuery({
    queryKey: getCoreMigrationReadinessQueryKey(),
    queryFn: async (): Promise<CoreMigrationReadiness> => {
      const row = unwrap<CoreMigrationReadinessRow>(
        await supabase.from('v_core_migration_readiness').select('*').single(),
      );
      return mapCoreMigrationReadiness(row);
    },
  });
}

export function useCoreStudentReadiness() {
  return useQuery({
    queryKey: getCoreStudentReadinessQueryKey(),
    queryFn: async (): Promise<CoreStudentReadiness[]> => {
      const rows = unwrap<CoreStudentReadinessRow[]>(
        await supabase
          .from('v_core_student_readiness')
          .select('*')
          .order('grade', { ascending: true })
          .order('name', { ascending: true }),
      );
      return rows.map(mapCoreStudentReadiness);
    },
  });
}

export function useDepartmentMeritStatus() {
  return useQuery({
    queryKey: getDepartmentMeritStatusQueryKey(),
    queryFn: async (): Promise<DepartmentMeritStatus[]> => {
      const rows = unwrap<DepartmentMeritStatusRow[]>(
        await supabase
          .from('v_department_merit_status')
          .select('*')
          .order('department_name', { ascending: true })
          .order('student_name', { ascending: true }),
      );
      return rows.map(mapDepartmentMeritStatus);
    },
  });
}

export function useEnsureWeeklyDepartmentMerits() {
  return useMutation({
    mutationFn: async () => {
      const { data, error } = await supabase.rpc('ensure_weekly_department_merits');
      if (error) throw new Error(error.message);
      return data as number;
    },
  });
}

export function useDailyDisciplineNotice(recordedAt: string) {
  return useQuery({
    queryKey: getDailyDisciplineNoticeQueryKey(recordedAt),
    queryFn: async (): Promise<DailyDisciplineNotice[]> => {
      const rows = unwrap<DailyDisciplineNoticeRow[]>(
        await supabase
          .from('v_daily_discipline_notice')
          .select('*')
          .eq('recorded_at', recordedAt)
          .order('grade', { ascending: true })
          .order('homeroom', { ascending: true, nullsFirst: false })
          .order('student_name', { ascending: true }),
      );
      return rows.map(mapDailyDisciplineNotice);
    },
    enabled: Boolean(recordedAt),
  });
}

export function useWeeklyDisciplineReport() {
  return useQuery({
    queryKey: getWeeklyDisciplineReportQueryKey(),
    queryFn: async (): Promise<WeeklyDisciplineReport[]> => {
      const rows = unwrap<WeeklyDisciplineReportRow[]>(
        await supabase
          .from('v_weekly_discipline_report')
          .select('*')
          .order('grade', { ascending: true })
          .order('homeroom', { ascending: true, nullsFirst: false })
          .order('student_name', { ascending: true }),
      );
      return rows.map(mapWeeklyDisciplineReport);
    },
  });
}

export function useCoreSetupStatus() {
  return useQuery({
    queryKey: getCoreSetupStatusQueryKey(),
    queryFn: async (): Promise<CoreSetupStatus | null> => {
      const { data, error } = await supabase
        .from('v_core_setup_status')
        .select('*')
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data ? mapCoreSetupStatus(data as CoreSetupStatusRow) : null;
    },
  });
}

export function useGrade9Assignments() {
  return useQuery({
    queryKey: getGrade9AssignmentsQueryKey(),
    queryFn: async (): Promise<Grade9Assignment[]> => {
      const rows = unwrap<Grade9AssignmentRow[]>(
        await supabase
          .from('v_grade9_current_assignments')
          .select('*')
          .order('student_name', { ascending: true }),
      );
      return rows.map(mapGrade9Assignment);
    },
  });
}

export function useInitializeCurrentAcademicTerm() {
  return useMutation({
    mutationFn: async ({
      code,
      name,
      startsOn,
      endsOn,
    }: {
      code: string;
      name: string;
      startsOn: string;
      endsOn: string;
    }) => {
      const { data, error } = await supabase.rpc('initialize_current_academic_term', {
        p_code: code,
        p_name: name,
        p_starts_on: startsOn,
        p_ends_on: endsOn,
      });
      if (error) throw new Error(error.message);
      return data as {
        term_id: string;
        classes_created: number;
        enrollments_created: number;
        grade9_pending: number;
      };
    },
  });
}

export function useAssignCurrentGrade9Section() {
  return useMutation({
    mutationFn: async ({ studentId, section }: { studentId: number; section: 'A' | 'B' }) => {
      const { error } = await supabase.rpc('assign_current_grade9_section', {
        p_student_id: studentId,
        p_section: section,
      });
      if (error) throw new Error(error.message);
    },
  });
}

export function useCurrentSettlement() {
  return useQuery({
    queryKey: getCurrentSettlementQueryKey(),
    queryFn: async (): Promise<SettlementPeriod | null> => {
      const { data, error } = await supabase
        .from('v_current_settlement')
        .select('id,label,starts_on,ends_on,created_at')
        .maybeSingle();
      if (error) throw new Error(error.message);
      return data ? mapSettlementPeriod(data as SettlementPeriodRow) : null;
    },
  });
}

export function useStartSettlementPeriod() {
  return useMutation({
    mutationFn: async ({ startsOn, label }: { startsOn: string; label: string }) => {
      const { data, error } = await supabase.rpc('start_settlement_period', {
        p_starts_on: startsOn,
        p_label: label,
      });
      if (error) throw new Error(error.message);
      return data as number;
    },
  });
}

export function useCloseSettlementPeriod() {
  return useMutation({
    mutationFn: async ({
      periodId,
      endDate,
      openNext = true,
      nextLabel = null,
    }: {
      periodId: number;
      endDate: string;
      openNext?: boolean;
      nextLabel?: string | null;
    }) => {
      const { data, error } = await supabase.rpc('close_settlement_period', {
        p_period_id: periodId,
        p_end_date: endDate,
        p_open_next: openNext,
        p_next_label: nextLabel,
      });
      if (error) throw new Error(error.message);
      return data as number | null;
    },
  });
}

// ---------------------------------------------------------------------------
// Writes — students
// ---------------------------------------------------------------------------

export function useCreateStudent() {
  return useMutation({
    mutationFn: async ({ data }: { data: StudentInput }) => {
      const { error } = await supabase.from('students').insert({ name: data.name, grade: data.grade });
      if (error) throw new Error(error.message);
    },
  });
}

export function useUpdateStudent() {
  return useMutation({
    mutationFn: async ({ id, data }: { id: number; data: StudentInput }) => {
      const { error } = await supabase.from('students').update({ name: data.name, grade: data.grade }).eq('id', id);
      if (error) throw new Error(error.message);
    },
  });
}

export function useDeleteStudent() {
  return useMutation({
    mutationFn: async ({ id }: { id: number }) => {
      // Soft delete — history must stay queryable.
      const { error } = await supabase.from('students').update({ deleted_at: new Date().toISOString() }).eq('id', id);
      if (error) throw new Error(error.message);
    },
  });
}

// ---------------------------------------------------------------------------
// Writes — point records (business rules enforced by the RPCs)
// ---------------------------------------------------------------------------

export function useCreatePointRecord() {
  return useMutation({
    mutationFn: async ({ data }: { data: PointRecordInput }) => {
      const { data: id, error } = await supabase.rpc('create_point_record', {
        p_student_id: data.studentId,
        p_type: data.type,
        p_item: data.item,
        p_points: data.points,
        p_entered_by_name: data.enteredByName,
        p_recorded_at: data.recordedAt,
        p_reflection_submitted: data.reflectionSubmitted ?? null,
      });
      if (error) throw new Error(error.message);
      return id as number;
    },
  });
}

export function useUpdatePointRecord() {
  return useMutation({
    mutationFn: async ({ id, data }: { id: number; data: PointRecordUpdateInput }) => {
      const { error } = await supabase.rpc('update_point_record', {
        p_id: id,
        p_points: data.points,
        p_item: data.item,
        p_entered_by_name: data.enteredByName,
        p_recorded_at: data.recordedAt,
        p_reflection_submitted: data.reflectionSubmitted ?? null,
      });
      if (error) throw new Error(error.message);
    },
  });
}

export function useDeletePointRecord() {
  return useMutation({
    mutationFn: async ({ id }: { id: number }) => {
      const { error } = await supabase.from('point_records').update({ deleted_at: new Date().toISOString() }).eq('id', id);
      if (error) throw new Error(error.message);
    },
  });
}

// ---------------------------------------------------------------------------
// Writes — reflections
// ---------------------------------------------------------------------------

export function useExtendReflectionTo21() {
  return useMutation({
    mutationFn: async ({ id, reason }: { id: number; reason: string }) => {
      const { data, error } = await supabase.rpc('extend_reflection_to_21', {
        p_reflection_id: id,
        p_reason: reason,
      });
      if (error) throw new Error(error.message);
      return data as string;
    },
  });
}

export function useUpdateReflection() {
  return useMutation({
    mutationFn: async ({ id, data }: { id: number; data: { submitted: boolean } }) => {
      const { error } = await supabase
        .from('reflection_records')
        .update({ submitted: data.submitted, submitted_at: data.submitted ? new Date().toISOString() : null })
        .eq('id', id);
      if (error) throw new Error(error.message);
    },
  });
}

// ---------------------------------------------------------------------------
// Writes — punishments (validation lives in the RPCs)
// ---------------------------------------------------------------------------

export function useCreatePunishment() {
  return useMutation({
    mutationFn: async ({ data }: { data: PunishmentInput }) => {
      const { error } = await supabase.rpc('create_punishment', {
        p_student_id: data.studentId,
        p_types: data.types,
        p_start_date: data.startDate,
        p_end_date: data.endDate,
        p_entered_by_name: data.enteredByName,
      });
      if (error) throw new Error(error.message);
    },
  });
}

export function useSetPunishmentViolation() {
  return useMutation({
    mutationFn: async ({ id, violated }: { id: number; violated: boolean }) => {
      const { error } = await supabase.rpc('set_punishment_violation', { p_id: id, p_violated: violated });
      if (error) throw new Error(error.message);
    },
  });
}

// ---------------------------------------------------------------------------
// Writes — point items
// ---------------------------------------------------------------------------

function pointItemPayload(data: PointItemInput) {
  return {
    name: data.name,
    type: data.type,
    fixed_points: data.fixedPoints,
    is_fixed: data.isFixed,
    is_active: data.isActive,
  };
}

export function useCreatePointItem() {
  return useMutation({
    mutationFn: async ({ data }: { data: PointItemInput }) => {
      const { error } = await supabase.from('point_items').insert(pointItemPayload(data));
      if (error) throw new Error(error.message);
    },
  });
}

export function useUpdatePointItem() {
  return useMutation({
    mutationFn: async ({ id, data }: { id: number; data: PointItemInput }) => {
      const { error } = await supabase.from('point_items').update(pointItemPayload(data)).eq('id', id);
      if (error) throw new Error(error.message);
    },
  });
}

export function useDeletePointItem() {
  return useMutation({
    mutationFn: async ({ id }: { id: number }) => {
      // Deactivate instead of delete so existing records keep their context.
      const { error } = await supabase.from('point_items').update({ is_active: false }).eq('id', id);
      if (error) throw new Error(error.message);
    },
  });
}

export function useImportPointItems() {
  return useMutation({
    mutationFn: async ({ data }: { data: { items: PointItemImportRow[] } }) => {
      // CSV import is for penalty items (spec §20): type NEGATIVE, a row with a
      // score becomes a fixed-point item, one without stays manual-entry.
      const rows = data.items.map((item) => ({
        name: item.name,
        type: 'NEGATIVE' as PointType,
        fixed_points: item.fixedPoints,
        is_fixed: item.fixedPoints != null,
        is_active: true,
      }));
      const { error } = await supabase.from('point_items').insert(rows);
      if (error) throw new Error(error.message);
    },
  });
}
