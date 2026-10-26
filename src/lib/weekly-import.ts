export interface WeeklySourceRow {
  week_start: string; source_key: string; source_name: string; grade: number; section: string;
  positive_points: number; negative_points: number; source_net: number;
  raw: { sheet: string; row: number; cells: unknown[] };
}
export interface WeeklyWorkbook { sheet: string; data: unknown[][] }
export interface WeeklyPreview {
  rows: WeeklySourceRow[]; notes: { sheet: string; row: number; cells: unknown[] }[];
  weeks: { start: string; label: string; rows: number; students: number; positive: number; negative: number }[];
  warnings: string[]; skipped: string[];
}

const text = (value: unknown) => value == null ? '' : String(value).trim();
function date(year: number, month: number, day: number) {
  const result = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  const parsed = new Date(result + 'T12:00:00Z');
  if (!Number.isFinite(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== result) throw new Error('유효하지 않은 주차 날짜입니다.');
  return result;
}
export function parseWeeklyWorkbook(sheets: WeeklyWorkbook[], cutover: string): WeeklyPreview {
  const result: WeeklyPreview = { rows: [], notes: [], weeks: [], warnings: [], skipped: [] };
  const knownClasses = new Map<string, Set<string>>();
  for (const s of sheets) for (const cells of s.data.slice(1)) for (const column of [0, 5, 10]) {
    const label = text(cells[column]).toUpperCase(), name = text(cells[column + 1]);
    if (name && /^G(7|8|9|10|11|12)(?:-[A-Z])?$/.test(label)) knownClasses.set(name, new Set([...(knownClasses.get(name) ?? []), label]));
  }
  for (const sheet of sheets) {
    const match = sheet.sheet.trim().match(/^(\d{2}|\d{4})\/(\d{1,2})\/(\d{1,2})\s*[~～–-]\s*(\d{1,2})\/(\d{1,2})$/);
    if (!match) { result.skipped.push(sheet.sheet); continue; }
    const year = Number(match[1]) + (match[1].length === 2 ? 2000 : 0);
    const start = date(year, +match[2], +match[3]);
    const end = date(year + (+match[4] < +match[2] ? 1 : 0), +match[4], +match[5]);
    if (new Date(start + 'T12:00Z').getUTCDay() !== 1 || Date.parse(end) - Date.parse(start) !== 6 * 86400000) throw new Error(`${sheet.sheet}: 월~일 7일 주차가 아닙니다.`);
    if (start >= cutover) { result.skipped.push(sheet.sheet); continue; }
    if (result.weeks.some(w => w.start === start)) throw new Error(`${start}: 같은 주차의 탭이 두 개입니다.`);
    const groups = new Map<string, WeeklySourceRow[]>();
    for (let row = 1; row < sheet.data.length; row++) {
      const cells = sheet.data[row];
      for (const column of [0, 5, 10]) {
        let className = text(cells[column]);
        const name = text(cells[column + 1]);
        if (!name && [2, 3, 4].every(offset => !text(cells[column + offset]) || Number(cells[column + offset]) === 0)) continue;
        if (!/^G(7|8|9|10|11|12)(?:-[A-Z])?$/i.test(className) && knownClasses.get(name)?.size === 1) {
          const original = className;
          className = [...knownClasses.get(name)!][0];
          result.warnings.push(`${sheet.sheet} ${name}: 학년 셀 “${original}”을 다른 탭의 일치 반 ${className}으로 연결 (원본 보존)`);
        }
        const classMatch = className.match(/^G(7|8|9|10|11|12)(?:-([A-Z]))?$/i);
        if (!classMatch || !name) throw new Error(`${sheet.sheet} ${row + 1}행: 학년/반과 이름을 확인하세요.`);
        const numbers = [2, 3, 4].map(offset => text(cells[column + offset]) === '' ? 0 : Number(cells[column + offset]));
        if (numbers.some(n => !Number.isSafeInteger(n)) || numbers[0] < 0 || numbers[1] < 0 || Math.max(numbers[0], numbers[1]) > 1000 || numbers[2] !== numbers[0] - numbers[1]) throw new Error(`${sheet.sheet} ${row + 1}행 ${name}: 상점·벌점·최종값을 확인하세요.`);
        const entry: WeeklySourceRow = {
          week_start: start, source_key: `${sheet.sheet}!${String.fromCharCode(65 + column)}${row + 1}`,
          source_name: name, grade: +classMatch[1], section: classMatch[2]?.toUpperCase() ?? '',
          positive_points: numbers[0], negative_points: numbers[1], source_net: numbers[2],
          raw: { sheet: sheet.sheet, row: row + 1, cells: cells.slice(column, column + 5) },
        };
        result.rows.push(entry);
        const key = `${entry.grade}:${entry.section}:${name}`;
        groups.set(key, [...(groups.get(key) ?? []), entry]);
        if (Math.max(...numbers) >= 100) result.warnings.push(`${sheet.sheet} ${name}: 큰 점수 ${numbers[0]}/${numbers[1]}점, 원본값 유지`);
      }
      if (cells.slice(15).some(v => text(v))) result.notes.push({ sheet: sheet.sheet, row: row + 1, cells: cells.slice(15) });
    }
    let positive = 0, negative = 0, count = 0;
    for (const group of groups.values()) {
      const distinct = new Set(group.filter(r => r.positive_points || r.negative_points).map(r => `${r.positive_points}/${r.negative_points}`));
      if (distinct.size > 1) throw new Error(`${sheet.sheet} ${group[0].source_name}: 중복 행의 확정값이 서로 다릅니다.`);
      if (group.length > 1) result.warnings.push(`${sheet.sheet} ${group[0].source_name}: ${group.length}개 중복 행 통합`);
      positive += Math.max(...group.map(r => r.positive_points));
      negative += Math.max(...group.map(r => r.negative_points));
      count += group.length;
    }
    if (!count) throw new Error(`${sheet.sheet}: 학생 행이 없습니다.`);
    result.weeks.push({ start, label: sheet.sheet, rows: count, students: groups.size, positive, negative });
  }
  if (!result.rows.length) throw new Error('전환일 이전의 주간 확정 탭이 없습니다. 탭 이름은 26/8/24~8/30 형식이어야 합니다.');
  return result;
}
