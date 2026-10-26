import { useMemo, useState } from 'react';
import { Link } from 'wouter';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useCoreSetupStatus, usePointRecordArchive, type DisciplineScope, type StudentSummary } from '@/lib/api';
import { shiftDate, weekStart } from '@/lib/history';

export function PointHistory({ date, today, onDateChange, students, scope }: {
  date: string; today: string; onDateChange: (date: string) => void;
  students: StudentSummary[]; scope?: DisciplineScope | null;
}) {
  const [mode, setMode] = useState<'DAY' | 'WEEK' | 'TERM'>('DAY');
  const [search, setSearch] = useState('');
  const term = useCoreSetupStatus();
  const start = mode === 'TERM' ? term.data?.startsOn ?? '' : mode === 'WEEK' ? weekStart(date) : date;
  const end = mode === 'TERM' ? (term.data ? [term.data.endsOn, today].sort()[0] : '')
    : mode === 'WEEK' ? [shiftDate(start, 6), today].sort()[0] : date;
  const archive = usePointRecordArchive(start, end);
  const identities = useMemo(() => new Map(students.map(s => [s.coreStudentId, s])), [students]);
  const scoped = (archive.data ?? []).filter(row => !scope || scope === 'ALL' || identities.has(row.coreStudentId));
  const needle = search.trim().toLowerCase();
  const records = scoped.filter(row => !needle || [row.studentName, row.item,
    identities.get(row.coreStudentId)?.studentNo, identities.get(row.coreStudentId)?.homeroom]
    .some(value => value?.toLowerCase().includes(needle)));
  const positive = records.filter(row => row.type === 'POSITIVE').reduce((sum, row) => sum + row.points, 0);
  const negative = records.filter(row => row.type === 'NEGATIVE').reduce((sum, row) => sum + row.points, 0);
  const net = negative - positive;
  const totals = new Map<string, { name: string; positive: number; negative: number }>();
  for (const row of records) {
    const value = totals.get(row.coreStudentId) ?? { name: row.studentName, positive: 0, negative: 0 };
    if (row.type === 'POSITIVE') value.positive += row.points;
    else value.negative += row.points;
    totals.set(row.coreStudentId, value);
  }
  const pending = archive.isLoading || (mode === 'TERM' && term.isLoading);
  const error = archive.error ?? (mode === 'TERM' ? term.error : null);
  return <section className="card card-pad point-history" id="point-history" aria-labelledby="point-history-title">
    <div className="section-row" style={{ margin: 0 }}>
      <div><h2 className="section-title" id="point-history-title">지난 기록 · 학기 누계</h2>
        <p className="section-copy">원기록은 주차·정산이 바뀌어도 보존됩니다. 위의 현재 현황과 별도로 조회합니다.</p></div>
      <div className="desk-filter-tabs" role="group" aria-label="기록 조회 단위">
        {([['DAY', '일별'], ['WEEK', '주별'], ['TERM', '학기 누계']] as const).map(([value, label]) =>
          <button key={value} type="button" aria-pressed={mode === value} className={mode === value ? 'is-active' : ''} onClick={() => setMode(value)}>{label}</button>)}
      </div>
    </div>
    <div className="history-controls">
      {mode !== 'TERM' ? <>
        <button className="btn btn-icon btn-outline" aria-label={mode === 'WEEK' ? '이전 주' : '이전 날짜'} onClick={() => onDateChange(shiftDate(date, mode === 'WEEK' ? -7 : -1))}><ChevronLeft size={17} /></button>
        <input className="input" type="date" aria-label="기록 조회 날짜" max={today} value={date} onChange={e => { if (e.target.value && e.target.value <= today) onDateChange(e.target.value); }} />
        <button className="btn btn-icon btn-outline" aria-label={mode === 'WEEK' ? '다음 주' : '다음 날짜'} disabled={date >= today} onClick={() => onDateChange([shiftDate(date, mode === 'WEEK' ? 7 : 1), today].sort()[0])}><ChevronRight size={17} /></button>
        <button className="btn btn-outline" onClick={() => onDateChange(today)}>오늘</button>
      </> : <span>{term.data?.termName ?? '현재 학기'} · {start} – {end}</span>}
      <input className="input" aria-label="과거 기록 검색" placeholder="이름 · 학번 · 반 · 사유" value={search} onChange={e => setSearch(e.target.value)} />
    </div>
    {mode === 'WEEK' && <p className="section-copy">{start} – {end}</p>}
    {error ? <div role="alert"><p className="danger-text">기록 조회에 실패했습니다. 누계가 0이라는 뜻은 아닙니다.</p><button className="btn btn-outline" onClick={() => { archive.refetch(); term.refetch(); }}>다시 시도</button></div>
      : pending ? <p role="status">기록을 불러오는 중입니다.</p>
      : mode === 'TERM' && !term.data ? <p role="status">현재 학기 설정을 먼저 확인해주세요.</p> : <>
        <p className="history-totals" aria-live="polite">{records.length}건 · 상점 <span className="success-text">{positive}점</span> · 벌점 <span className="danger-text">{negative}점</span> · NET {net}점 {net < 0 ? `(상점 ${-net}점 우세)` : net > 0 ? `(벌점 ${net}점 우세)` : '(상쇄)'}</p>
        {mode === 'TERM' && <p className="section-copy">학기 시작일부터 DB에 등록된 원기록의 누계입니다. 미입력 수기 자료는 포함되지 않습니다. 정산기간을 초기화해도 이 누계는 유지됩니다.</p>}
        {mode === 'TERM' && records.length > 0 && <div className="table-wrap"><table className="data-table"><caption className="desk-sr-only">학생별 학기 상점·벌점 누계</caption>
          <thead><tr><th>학생</th><th>학번 / 반</th><th>상점</th><th>벌점</th><th>NET (벌점 − 상점)</th></tr></thead>
          <tbody>{[...totals.entries()].sort((a, b) => (b[1].negative - b[1].positive) - (a[1].negative - a[1].positive)).map(([id, row]) => <tr key={id}>
            <td><Link href={'/students/' + id}>{row.name}</Link></td><td>{identities.get(id)?.studentNo ?? '—'} / {identities.get(id)?.homeroom ?? '—'}</td>
            <td className="success-text">{row.positive}</td><td>{row.negative}</td><td>{row.negative - row.positive}</td>
          </tr>)}</tbody></table></div>}
        {records.length ? <div className="table-wrap"><table className="data-table"><caption className="desk-sr-only">선택한 기간의 상벌점 원기록</caption>
          <thead><tr><th>발생일</th><th>학생</th><th>구분</th><th>사유</th><th>점수</th><th>기록자</th></tr></thead><tbody>
            {records.map(row => <tr key={row.id}><td>{row.recordedAt.slice(0, 10)}</td><td><Link href={'/students/' + row.coreStudentId}>{row.studentName}</Link></td>
              <td>{row.type === 'POSITIVE' ? '상점' : '벌점'}</td><td>{row.item}</td><td className={row.type === 'POSITIVE' ? 'success-text' : 'danger-text'}>{row.points}</td><td>{row.enteredByName}</td></tr>)}
          </tbody></table></div> : <p>선택한 기간·검색 조건에 등록된 기록이 없습니다. 수기 자료가 미입력된 경우도 확인해주세요.</p>}
      </>}
  </section>;
}
