import { useMemo, useState } from 'react';
import { Link } from 'wouter';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useCoreSetupStatus, useDisciplineHistory, usePointRecordArchive, type DisciplineScope, type StudentSummary } from '@/lib/api';
import { shiftDate, weekStart } from '@/lib/history';

export function PointHistory({ date, today, onDateChange, scope, studentId }: {
  date: string; today: string; onDateChange: (date: string) => void;
  students?: StudentSummary[]; scope?: DisciplineScope | null; studentId?: string;
}) {
  const [mode, setMode] = useState<'DAY' | 'WEEK' | 'TERM'>(studentId ? 'TERM' : 'WEEK');
  const [search, setSearch] = useState('');
  const term = useCoreSetupStatus();
  const start = mode === 'TERM' ? term.data?.startsOn ?? '' : mode === 'WEEK' ? weekStart(date) : date;
  const end = mode === 'TERM' ? (term.data ? [term.data.endsOn, today].sort()[0] : '') : mode === 'WEEK' ? [shiftDate(start, 6), today].sort()[0] : date;
  const history = useDisciplineHistory(start, end, studentId);
  const archive = usePointRecordArchive(start, end, studentId, mode === 'DAY');
  const matchesScope = (grade: number) => !scope || scope === 'ALL' || (scope === 'ELEMENTARY' ? grade <= 6 : scope === 'MIDDLE' ? grade >= 7 && grade <= 8 : grade >= 9);
  const needle = search.trim().toLowerCase();
  const identities = new Map((history.data?.students ?? []).map(s => [s.id, s]));
  const rows = (history.data?.rows ?? []).filter(r => matchesScope(r.grade) && (!needle || [r.student_name, r.student_no, r.homeroom].some(v => v?.toLowerCase().includes(needle))));
  const records = (archive.data ?? []).filter(r => {
    const person = identities.get(r.coreStudentId);
    return person && matchesScope(person.grade) && (!needle || [r.studentName, person.student_no, person.homeroom, r.item].some(v => v?.toLowerCase().includes(needle)));
  });
  const totals = new Map<string, { name: string; positive: number; negative: number; weeks: number }>();
  for (const row of rows) {
    const value = totals.get(row.core_student_id) ?? { name: row.student_name, positive: 0, negative: 0, weeks: 0 };
    value.positive += row.positive_points; value.negative += row.negative_points; value.weeks++;
    totals.set(row.core_student_id, value);
  }
  const positive = rows.reduce((sum, row) => sum + row.positive_points, 0);
  const negative = rows.reduce((sum, row) => sum + row.negative_points, 0);
  const secondary = scope !== 'ELEMENTARY' && (!studentId || (identities.get(studentId)?.grade ?? 7) >= 7);
  const calendar = secondary ? history.data?.calendar ?? [] : [];
  const weekly = rows.some(r => r.source === 'WEEKLY');
  const error = history.error ?? (mode === 'DAY' ? archive.error : null) ?? term.error;
  const pending = history.isLoading || (mode === 'DAY' && archive.isLoading) || (mode === 'TERM' && term.isLoading);
  const trend = useMemo(() => {
    if (!studentId || !start || !end) return [];
    const values = new Map((history.data?.rows ?? []).map(r => [r.week_start, r.net]));
    const breaks = new Map((history.data?.calendar ?? []).filter(c => c.kind === 'NO_SCHOOL').map(c => [c.week_start, c.label]));
    const points: { week: string; value: number | null; label?: string }[] = [];
    for (let week = weekStart(start); week <= end; week = shiftDate(week, 7)) points.push({ week, value: values.get(week) ?? null, label: breaks.get(week) });
    return points;
  }, [studentId, start, end, history.data]);
  const extent = Math.max(8, ...trend.map(p => Math.abs(p.value ?? 0)));
  return <section className="card card-pad point-history" id="point-history" aria-labelledby="point-history-title">
    <div className="section-row" style={{ margin: 0 }}>
      <div><h2 className="section-title" id="point-history-title">{studentId ? '학기 추이' : '지난 기록 · 학기 누계'}</h2>
        <p className="section-copy">주간 확정값과 일별 기록을 이어서 조회합니다. 최종값 = 상점 − 벌점.</p></div>
      <div className="desk-filter-tabs" role="group" aria-label="기록 조회 단위">
        {([['DAY', '일별'], ['WEEK', '주별'], ['TERM', '학기 누계']] as const).map(([value, label]) =>
          <button key={value} type="button" aria-pressed={mode === value} className={mode === value ? 'is-active' : ''} onClick={() => setMode(value)}>{label}</button>)}
      </div>
    </div>
    <div className="history-controls">
      {mode !== 'TERM' ? <>
        <button className="btn btn-icon btn-outline" aria-label="이전 기간" onClick={() => onDateChange(shiftDate(date, mode === 'WEEK' ? -7 : -1))}><ChevronLeft size={17} /></button>
        <input className="input" type="date" aria-label="기록 조회 날짜" max={today} value={date} onChange={e => { if (e.target.value && e.target.value <= today) onDateChange(e.target.value); }} />
        <button className="btn btn-icon btn-outline" aria-label="다음 기간" disabled={date >= today} onClick={() => onDateChange([shiftDate(date, mode === 'WEEK' ? 7 : 1), today].sort()[0])}><ChevronRight size={17} /></button>
        <button className="btn btn-outline" onClick={() => onDateChange(today)}>오늘</button>
      </> : <span>{term.data?.termName ?? '현재 학기'} · {start} – {end}</span>}
      {!studentId && <input className="input" aria-label="과거 기록 검색" placeholder="이름 · 학번 · 반" value={search} onChange={e => setSearch(e.target.value)} />}
    </div>
    {mode === 'WEEK' && <p className="section-copy">{start} – {end}</p>}
    {error ? <div role="alert"><p className="danger-text">기록 조회에 실패했습니다. 누계가 0이라는 뜻은 아닙니다.</p><button className="btn btn-outline" onClick={() => { history.refetch(); archive.refetch(); term.refetch(); }}>다시 시도</button></div>
      : pending ? <p role="status">기록을 불러오는 중입니다.</p> : <>
        <p className="history-totals" aria-live="polite">상점 <span className="success-text">{positive}점</span> · 벌점 <span className="danger-text">{negative}점</span> · {mode === 'TERM' ? '학기 누계' : '최종값'} <strong>{positive - negative}점</strong></p>
        {secondary && history.data?.daily_starts_on && <p className="section-copy">기록 기준은 각 주차에 표시됩니다. 일별 입력은 선택한 발생일에 합산되며, 누계는 조회된 기록 기준입니다.</p>}
        {mode === 'DAY' && weekly && <p role="status">이 날짜는 주간 확정값만 있습니다. 아래 점수는 해당 주 전체이며 일별 사유·발생 횟수는 확인할 수 없습니다.</p>}
        {calendar.filter(c => c.kind === 'NO_SCHOOL').map(c => <p className="section-copy" key={c.week_start}>{c.week_start} 주 · {c.label} · 비운영</p>)}
        {studentId && mode === 'TERM' && trend.length > 0 && <figure className="history-trend">
          <figcaption>주간 최종값 · 위쪽은 상점, 아래쪽은 벌점 우세</figcaption>
          <svg viewBox="0 0 660 200" role="img" aria-label="학생 주간 최종값 추이. 정확한 값은 아래 표에서 확인할 수 있습니다.">
            <line x1="30" x2="645" y1="90" y2="90" stroke="currentColor" opacity=".35" /><text x="5" y="94" fill="currentColor" fontSize="12">0</text>
            {trend.map((p, i) => {
              const x = 40 + i * 590 / Math.max(1, trend.length - 1), y = 90 - (p.value ?? 0) / extent * 65;
              const prev = trend[i - 1]; const px = 40 + (i - 1) * 590 / Math.max(1, trend.length - 1);
              return <g key={p.week}>{p.value != null && <>
                {prev?.value != null && <line x1={px} x2={x} y1={90 - prev.value / extent * 65} y2={y} stroke="currentColor" strokeWidth="2" />}
                <circle cx={x} cy={y} r="4" fill="currentColor" /><text x={x} y={y - 10} textAnchor="middle" fill="currentColor" fontSize="12">{p.value}</text>
              </>}<text x={x} y="180" textAnchor="middle" fill="currentColor" fontSize="11">{p.week.slice(5).replace('-', '/')}</text>
              {p.value == null && <text x={x} y="110" textAnchor="middle" fill="currentColor" fontSize="10">{p.label ? '비운영' : '기록 없음'}</text>}</g>;
            })}
          </svg>
        </figure>}
        {mode === 'TERM' && !studentId && totals.size > 0 && <div className="table-wrap"><table className="data-table"><caption className="desk-sr-only">학생별 학기 누계</caption>
          <thead><tr><th>학생</th><th>학번 / 반</th><th>상점</th><th>벌점</th><th>학기 누계</th></tr></thead>
          <tbody>{[...totals.entries()].sort((a,b) => a[1].name.localeCompare(b[1].name, 'ko')).map(([id,r]) => <tr key={id}>
            <td><Link href={'/students/' + id}>{r.name}</Link></td><td>{identities.get(id)?.student_no} / {identities.get(id)?.homeroom}</td>
            <td>{r.positive}</td><td>{r.negative}</td><td>{r.positive-r.negative}<div className="record-meta">기록 {r.weeks}주</div></td>
          </tr>)}</tbody></table></div>}
        {rows.length > 0 && (mode !== 'DAY' || weekly) && <div className="table-wrap"><table className="data-table"><caption className="desk-sr-only">주차별 확정 또는 일별 합산</caption>
          <thead><tr><th>주차</th>{!studentId && <th>학생</th>}<th>상점</th><th>벌점</th><th>최종값</th><th>기록 기준</th></tr></thead>
          <tbody>{rows.map(r => <tr key={r.core_student_id+r.week_start+r.source}>
            <td>{r.week_start} – {r.week_end.slice(5)}</td>{!studentId && <td><Link href={'/students/'+r.core_student_id}>{r.student_name}</Link> <span className="muted">{r.homeroom}</span></td>}
            <td>{r.positive_points}</td><td>{r.negative_points}</td><td>{r.net}</td><td>{r.source==='WEEKLY' ? '주간 확정' : '일별 합산'}{r.review_note && <div className="record-meta">{r.review_note}</div>}</td>
          </tr>)}</tbody></table></div>}
        {mode === 'DAY' && records.length > 0 && <div className="table-wrap"><table className="data-table"><thead><tr><th>발생일</th><th>학생</th><th>사유</th><th>점수</th><th>기록자</th></tr></thead><tbody>{records.map(r => <tr key={r.id}><td>{r.recordedAt.slice(0,10)}</td><td><Link href={'/students/'+r.coreStudentId}>{r.studentName}</Link></td><td>{r.item}</td><td>{r.type==='POSITIVE'?'상점':'벌점'} {r.points}</td><td>{r.enteredByName}</td></tr>)}</tbody></table></div>}
        {!rows.length && <p>해당 기간에 조회 가능한 점수 기록이 없습니다. 기록 없음은 0점 확정과 다릅니다.</p>}
        {studentId && <p className="section-copy">비운영 주차와 학생 행이 없는 주차는 0점으로 채우지 않습니다. 주간 확정값만으로 반성문 횟수나 제출 상태를 판단하지 않습니다.</p>}
      </>}
  </section>;
}

export function StudentHistory({ studentId }: { studentId: string }) {
  const today = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Seoul' }).format(new Date());
  const [date, setDate] = useState(today);
  return <PointHistory date={date} today={today} onDateChange={setDate} studentId={studentId} />;
}
