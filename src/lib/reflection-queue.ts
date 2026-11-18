// Shared, read-only queue criteria for reflection actions and status filters.
// The TODAY tab is intentionally a subset of pending items. MISSING includes DOUBLE.
export type ReflectionListFilter = 'ALL' | 'TODAY' | 'MISSING' | 'DOUBLE' | 'SUBMITTED';

export interface ReflectionQueueRecord {
  status: 'MISSING' | 'DOUBLE' | 'SUBMITTED';
  isCurrentStudent: boolean;
  reflectionPages: number | null;
  seondoNoticeDay: string | null;
  recordedAt: string;
  submissionDeadline: string;
  dueAt: string;
  submittedAt: string | null;
}

export function isDoubleReflection(row: Pick<ReflectionQueueRecord, 'status' | 'dueAt' | 'submittedAt'>): boolean {
  if (row.status === 'DOUBLE') return true;
  // Once a double obligation is submitted, v_reflections returns SUBMITTED.
  // Preserve its doubled pages/label using the recorded submission timestamp.
  return row.status === 'SUBMITTED' && row.submittedAt !== null
    && Date.parse(row.submittedAt) > Date.parse(row.dueAt);
}

export function reflectionIsOnNotice(
  reflection: ReflectionQueueRecord, date: string, today: string, managed = false,
): boolean {
  if (!reflection.isCurrentStudent || reflection.status === 'SUBMITTED' || !((reflection.reflectionPages ?? 0) > 0)) return false;
  if (managed) return reflection.seondoNoticeDay === date;
  return reflection.recordedAt === date
    || (date === today && reflection.recordedAt < date
      && (reflection.status === 'DOUBLE' || reflection.submissionDeadline === date));
}

export function reflectionMatchesFilter(
  reflection: ReflectionQueueRecord,
  filter: ReflectionListFilter,
  today: string,
  managed = false,
): boolean {
  if (!reflection.isCurrentStudent) return false;
  // An offset/waiver can leave a historical reflection row with zero pages.
  // It remains in the student audit record, not in the active action queues.
  if (reflection.status !== 'SUBMITTED' && !((reflection.reflectionPages ?? 0) > 0)) return false;
  if (filter === 'TODAY') return reflectionIsOnNotice(reflection, today, today, managed);
  if (filter === 'MISSING') return reflection.status === 'MISSING' || reflection.status === 'DOUBLE';
  if (filter === 'DOUBLE') return reflection.status === 'DOUBLE';
  if (filter === 'SUBMITTED') return reflection.status === 'SUBMITTED';
  return true;
}
