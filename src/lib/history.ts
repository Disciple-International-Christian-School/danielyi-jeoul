/** Date-only arithmetic is UTC-based, independent of the operator's timezone. */
export function shiftDate(date: string, days: number) {
  const value = new Date(date + 'T12:00:00Z');
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

export function weekStart(date: string) {
  const day = new Date(date + 'T12:00:00Z').getUTCDay();
  return shiftDate(date, -((day + 6) % 7));
}

/** Count calendar days with discipline operations, including zero-point days. */
export function operatingDays(start: string, end: string, calendar: { week_start: string; kind: string }[]) {
  const closedWeeks = new Set(calendar.filter(week => week.kind === 'NO_SCHOOL').map(week => week.week_start));
  let count = 0;
  for (let date = start; date <= end; date = shiftDate(date, 1)) {
    if (!closedWeeks.has(weekStart(date))) count++;
  }
  return count;
}
