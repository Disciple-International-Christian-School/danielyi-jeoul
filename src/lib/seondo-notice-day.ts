// Both on-screen notice previews and the print DOM must consume one date-validated snapshot.
// A response with a different batch day is never displayable under the requested date.
import type { SeondoNotice, SeondoNoticeEntry } from './api';

export function selectNoticeForDay(notice: SeondoNotice, day: string, isToday: boolean): {
  valid: boolean; entries: SeondoNoticeEntry[]; preview: boolean;
} {
  const valid = notice.notice_day === day && (!notice.batch || notice.batch.day === day);
  const preview = valid && isToday && notice.managed_date && !notice.batch;
  return {
    valid,
    preview,
    entries: !valid ? [] : notice.batch ? notice.entries : preview ? notice.preview_entries ?? [] : [],
  };
}

/** Today's live notice is authoritative for an unsubmitted record's action state. */
export function previewReflectionStatus(isDouble: boolean): 'MISSING' | 'DOUBLE' {
  return isDouble ? 'DOUBLE' : 'MISSING';
}

/** Earlier unpublished drafts are informational, not a blocker for today's cutoff. */
export function canFinalizeDailyNotice(
  notice: SeondoNotice | undefined, selectedDay: string, todayDay: string,
  isLead: boolean, isPending: boolean,
): boolean {
  if (!notice || selectedDay !== todayDay || !isLead || isPending) return false;
  return selectNoticeForDay(notice, selectedDay, true).valid && !notice.batch?.published_at;
}

/** Frozen print rows cannot prove an obligation is still actionable. */
export function selectLiveReflectionEntries(notice: SeondoNotice, day: string): SeondoNoticeEntry[] {
  if (notice.notice_day !== day) return [];
  if (notice.live_entries != null) return notice.live_entries;
  // Compatibility while the database and frontend roll out separately.
  return notice.batch ? notice.entries : notice.preview_entries ?? [];
}
