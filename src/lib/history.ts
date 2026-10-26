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
