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

export const PUNISHMENT_TYPES = ['운동금지', '간식금지', '면회금지'] as const;
export type PunishmentType = (typeof PUNISHMENT_TYPES)[number];

export interface StudentSummary {
  id: number;
  name: string;
  grade: number;
  createdAt: string;
  updatedAt: string;
  positivePoints: number;
  negativePoints: number;
  weeklyPenaltyPoints: number;
  monthlyPenaltyPoints: number;
  weeklyRecordCount: number;
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
  submittedAt: string | null;
  status: ReflectionStatus;
}

export interface DashboardCounts {
  students: number;
  weeklyTargets: number;
  missingReflections: number;
  doubleReflections: number;
  activePunishments: number;
}

export interface Dashboard {
  counts: DashboardCounts;
  students: StudentSummary[];
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
  id: number; name: string; grade: number; created_at: string; updated_at: string;
  positive_points: number; negative_points: number; weekly_penalty_points: number;
  monthly_penalty_points: number; weekly_record_count: number;
  punishment: string | null; statuses: string[] | null;
}
interface ReflectionRow {
  id: number; point_record_id: number; student_id: number; student_name: string;
  grade: number; item: string; points: number; recorded_at: string;
  submitted: boolean; submission_deadline: string; submitted_at: string | null;
  status: ReflectionStatus;
}
interface DashboardCountsRow {
  students: number; weekly_targets: number; missing_reflections: number;
  double_reflections: number; active_punishments: number;
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
    name: row.name,
    grade: row.grade,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    positivePoints: row.positive_points,
    negativePoints: row.negative_points,
    weeklyPenaltyPoints: row.weekly_penalty_points,
    monthlyPenaltyPoints: row.monthly_penalty_points,
    weeklyRecordCount: row.weekly_record_count,
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
    submittedAt: row.submitted_at,
    status: row.status,
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

// ---------------------------------------------------------------------------
// Reads
// ---------------------------------------------------------------------------

async function fetchStudentSummaries(): Promise<StudentSummary[]> {
  const rows = unwrap<StudentSummaryRow[]>(
    await supabase.from('v_student_summary').select('*').order('negative_points', { ascending: false }),
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
