import { useMemo, useRef, useState } from 'react';
import { ArrowDownRight, ArrowRight, ArrowUpRight, BookOpenCheck, CalendarDays, Check, CircleCheck, Clock3, Dumbbell, FileClock, Search, ShieldAlert, Users, X } from 'lucide-react';
import { Link } from 'wouter';
import { reflectionIsOnNotice, usePointRecordArchive, type DepartmentMeritStatus, type DisciplineScope, type Reflection, type StudentSummary } from '@/lib/api';
import './dashboard.css';
import { PointHistory } from './point-history';

type ReadState<T> = { data: T | undefined; loading: boolean; error: boolean };
type Target = 'ALL' | 'PHYSICAL' | 'COMMITTEE';
type Props = {
  students: StudentSummary[];
  reflections: Reflection[];
  calendar: { date: string; label: string; weekLabel: string };
  scope?: DisciplineScope | null;
  isLead: boolean;
  seondoActive: boolean;
  departments: ReadState<DepartmentMeritStatus[]>;
};

const scopeLabels = { ALL: '전체 학년', ELEMENTARY: '초등', MIDDLE: '중등', HIGH: '고등' };
const targetLabels: Array<[Target, string]> = [['ALL', '전체 학생'], ['PHYSICAL', '체력훈련 대상자'], ['COMMITTEE', '징계위원회 대상자']];
const shortDate = (date: string) => new Intl.DateTimeFormat('ko-KR', { month: 'numeric', day: 'numeric', timeZone: 'Asia/Seoul' }).format(new Date(date + 'T12:00:00+09:00'));

export function DashboardView({ students, reflections, calendar, scope, isLead, seondoActive, departments }: Props) {
  const [historyDate, setHistoryDate] = useState(calendar.date);
  const [hasSelectedDay, setHasSelectedDay] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [historyMode, setHistoryMode] = useState<'DAY' | 'WEEK' | 'TERM'>('DAY');
  const selectHistoryDate = (date: string) => {
    setHistoryDate(date);
    setHasSelectedDay(true);
    setHistoryMode('DAY');
  };
  const openHistory = (mode: 'DAY' | 'WEEK' | 'TERM') => {
    setHistoryMode(mode);
    setHistoryOpen(true);
  };
  // Archive is lazy: do not fetch historical records while the dashboard loads.
  const selectedArchive = usePointRecordArchive(historyDate, historyDate, undefined, hasSelectedDay);
  const eligibleStudentIds = useMemo(() => new Set(students.map(row => row.coreStudentId)), [students]);
  const selectedRecords = (selectedArchive.data ?? []).filter(row => eligibleStudentIds.has(row.coreStudentId));
  const dayPositive = selectedRecords.filter(row => row.type === 'POSITIVE').reduce((sum, row) => sum + row.points, 0);
  const dayNegative = selectedRecords.filter(row => row.type === 'NEGATIVE').reduce((sum, row) => sum + row.points, 0);
  const [search, setSearch] = useState('');
  const [sort, setSort] = useState<'net' | 'grade' | 'name'>('net');
  const [target, setTarget] = useState<Target>('ALL');
  const listHeading = useRef<HTMLHeadingElement>(null);
  const rows = useMemo(() => {
    const needle = search.trim().toLowerCase();
    return students.filter(student =>
      (target === 'ALL' || (target === 'PHYSICAL' ? student.physicalTrainingRequired : student.committeeRequired))
      && (!needle || [student.name, student.studentNo, student.homeroom].some(value => value?.toLowerCase().includes(needle)))
    ).sort((a, b) => {
      // Respect the requested sort even when one student has no current score.
      // net_penalty_points uses the inverse sign of displayed merit-minus-penalty.
      return (sort === 'name' ? a.name.localeCompare(b.name, 'ko') : sort === 'grade'
        ? a.grade - b.grade || (a.homeroom ?? '').localeCompare(b.homeroom ?? '', 'ko')
        : b.weeklyNetPenaltyPoints - a.weeklyNetPenaltyPoints)
        || a.name.localeCompare(b.name, 'ko');
    });
  }, [students, search, sort, target]);
  const personCount = (predicate: (reflection: Reflection) => boolean) => new Set(reflections.filter(predicate).map(row => row.coreStudentId)).size;
  const missing = personCount(row => row.isCurrentStudent && row.status !== 'SUBMITTED');
  const metrics = [
    { label: '반성문 대상자', value: personCount(row => reflectionIsOnNotice(row, calendar.date, calendar.date, seondoActive)), note: seondoActive ? '오늘 반성문 대상 · 게시 전 포함' : '오늘 발생·마감 + 이월 2배', icon: BookOpenCheck, href: '/reflections?view=TODAY', tone: 'normal' },
    { label: '반성문 미제출자', value: missing, note: '이전 날짜 포함 · 미제출 전체', icon: FileClock, href: '/reflections?view=MISSING', tone: 'watch' },
    { label: '2배 제출 대상자', value: personCount(row => row.isCurrentStudent && row.status === 'DOUBLE'), note: '미제출자 중 마감 경과', icon: Clock3, href: '/reflections?view=DOUBLE', tone: 'urgent' },
    { label: '체력훈련 대상자', value: students.filter(row => row.physicalTrainingRequired).length, note: seondoActive ? '최근 주간 결산' : '초등 NET -8·2배 미제출 / 중고등 NET -8', icon: Dumbbell, target: 'PHYSICAL' as Target, tone: 'training' },
    { label: '징계위원회 대상자', value: students.filter(row => row.committeeRequired).length, note: seondoActive ? '최근 월간 결산 · 체력훈련 3회 이상' : '이번 학기 체력훈련 대상 3주 연속', icon: ShieldAlert, target: 'COMMITTEE' as Target, tone: 'normal' },
  ];
  const openTarget = (value: Target) => {
    setTarget(value);
    setSearch('');
    listHeading.current?.focus({ preventScroll: true });
    listHeading.current?.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth', block: 'start' });
  };
  const current = new Date(calendar.date + 'T12:00:00+09:00');
  const monday = new Date(current);
  monday.setUTCDate(current.getUTCDate() - (current.getUTCDay() + 6) % 7);
  const days = Array.from({ length: 7 }, (_, index) => {
    const day = new Date(monday);
    day.setUTCDate(monday.getUTCDate() + index);
    return { label: ['월', '화', '수', '목', '금', '토', '일'][index], day: day.getUTCDate(), date: day.toISOString().slice(0, 10) };
  });
  const total = departments.data?.length ?? 0;
  const generated = departments.data?.filter(row => row.generated).length ?? 0;
  const meritLabel = departments.loading ? '반영 내역 확인 중' : departments.error ? '반영 내역 확인 필요' : total === 0 ? '자동반영 대상 설정 필요' : generated === total ? '이번 주 자동반영 완료' : '이번 주 미반영 내역 확인';

  return <div className="dashboard-desk">
    <header className="desk-header">
      <div><div className="desk-eyebrow"><span aria-hidden="true" />오늘의 생활지도 현황</div>
        <h1>{calendar.label}</h1>
        <p className="desk-calendar-copy"><CalendarDays size={16} aria-hidden="true" />{calendar.weekLabel}<span className="desk-scope">{scopeLabels[scope ?? 'ALL']}</span></p>
      </div>
      <div className="desk-header-actions"><Link href="/points/positive" className="btn btn-primary" data-testid="link-quick-positive"><ArrowUpRight />상점 입력</Link><Link href="/points/negative" className="btn btn-outline"><ArrowDownRight />벌점 입력</Link></div>
    </header>

    <section className="desk-overview" aria-label="생활지도 대상자 현황">
      {metrics.map(({ label, value, note, icon: Icon, href, target: metricTarget, tone }, index) => {
        const content = <><span className="desk-metric-top"><span>{label}</span><Icon size={19} aria-hidden="true" /></span><span className="desk-metric-number">{value}<small>명</small></span><span className="desk-metric-note">{note}</span><span className="desk-metric-bottom">명단 확인<ArrowRight size={15} aria-hidden="true" /></span></>;
        const className = 'desk-metric ' + (value > 0 ? 'desk-metric-' + tone : '');
        return href ? <Link href={href} key={label} className={className} data-testid={'card-metric-' + index}>{content}</Link>
          : <button key={label} type="button" className={className} onClick={() => openTarget(metricTarget!)} data-testid={'card-metric-' + index}>{content}</button>;
      })}
    </section>
    <p className="desk-count-note">대상자 수는 학생 기준이며, 항목 간 중복될 수 있습니다.</p>

    <div className="desk-work-grid">
      <section className="desk-week" aria-labelledby="desk-week-title">
        <div className="desk-panel-heading"><div><span className="desk-panel-kicker">주간 업무</span><h2 id="desk-week-title">이번 주의 흐름</h2></div><span className="desk-week-range">{shortDate(days[0].date)} – {shortDate(days[6].date)}</span></div>
        <ol className="desk-week-days" aria-label="이번 주 달력">{days.map(day => <li key={day.date} className={[day.date === calendar.date ? 'is-today' : '', hasSelectedDay && day.date === historyDate ? 'is-selected' : ''].filter(Boolean).join(' ')} aria-current={day.date === calendar.date ? 'date' : undefined}><button type="button" disabled={day.date > calendar.date} aria-pressed={hasSelectedDay && day.date === historyDate} aria-label={day.date + ' 기록 바로 보기'} onClick={() => selectHistoryDate(day.date)}><span>{day.label}</span><strong>{day.day}</strong><span className="desk-day-marker">{day.date === calendar.date ? '오늘' : hasSelectedDay && day.date === historyDate ? '선택' : '\u00a0'}</span></button></li>)}</ol>
        {isLead ? <div className="desk-merit">
          <div className="desk-merit-heading"><span>{!departments.loading && !departments.error && total > 0 && generated === total ? <CircleCheck size={18} /> : <CalendarDays size={18} />}부서상점 자동반영</span><Link href="/points/positive/departments">관리<ArrowRight size={15} /></Link></div>
          <div className="desk-merit-status"><strong>{meritLabel}</strong>{!departments.loading && !departments.error && total > 0 && <span>{generated} / {total}건</span>}</div>
          {!departments.loading && !departments.error && total > 0 ? <progress aria-label="이번 주 부서상점 반영" max={total} value={generated} /> : <p>{departments.error ? '관리 화면에서 반영 내역을 다시 확인해 주세요.' : departments.loading ? '이번 주 반영 내역을 불러오고 있습니다.' : '부서 규칙과 소속 학생을 등록하면 매주 자동 반영됩니다.'}</p>}
        </div> : <div className="desk-week-note"><CalendarDays size={18} /><p>주간 점수는 월요일부터 집계됩니다.<br />이번 주 대상자 현황을 확인해 주세요.</p></div>}
      </section>
      <section className="desk-work desk-day-preview" aria-labelledby="desk-work-title">
        <div className="desk-panel-heading">
          <div><span className="desk-panel-kicker">날짜별 기록</span><h2 id="desk-work-title">{hasSelectedDay ? shortDate(historyDate) + ' 생활점수 기록' : '날짜를 선택해 기록 확인'}</h2></div>
          <CalendarDays size={19} className="desk-preview-calendar" aria-hidden="true" />
        </div>
        {!hasSelectedDay ? <div className="desk-preview-empty">
          <p>왼쪽 주간 달력의 날짜를 선택하면 해당일 상벌점과 입력 기록을 이곳에서 바로 볼 수 있습니다.</p>
          <button type="button" className="btn btn-outline" onClick={() => selectHistoryDate(calendar.date)}>오늘 기록 확인 <ArrowRight size={15} /></button>
        </div> : selectedArchive.isLoading ? <p className="desk-preview-loading" role="status">해당일 기록을 불러오는 중입니다.</p>
          : selectedArchive.isError ? <div className="desk-preview-error" role="alert">기록 조회에 실패했습니다. 점수가 0이라는 뜻은 아닙니다. <button className="btn btn-outline" type="button" onClick={() => selectedArchive.refetch()}>다시 시도</button></div>
          : <>
            <div className="desk-preview-totals" aria-live="polite">
              <div><span>상점</span><strong className="success-text">+{dayPositive}</strong></div>
              <div><span>벌점</span><strong className="danger-text">−{dayNegative}</strong></div>
              <div><span>상벌NET</span><strong>{dayPositive - dayNegative > 0 ? '+' : ''}{dayPositive - dayNegative}</strong></div>
            </div>
            <div className="desk-preview-meta">{selectedRecords.length > 0 ? '입력 기록 ' + selectedRecords.length + '건 · 최근 기록' : '해당일 입력 기록이 없습니다. 기록 없음은 0점 확정과 다릅니다.'}</div>
            {selectedRecords.length > 0 && <ul className="desk-preview-list">
              {selectedRecords.slice(0, 3).map(record => <li key={record.id}>
                <span className="desk-preview-person">{record.studentName}</span>
                <span className="desk-preview-item" title={record.item}>{record.item}</span>
                <strong className={record.type === 'POSITIVE' ? 'success-text' : 'danger-text'}>{record.type === 'POSITIVE' ? '+' : '−'}{record.points}</strong>
              </li>)}
            </ul>}
          </>}
        <div className="desk-history-actions" role="group" aria-label="과거 기록 상세 조회">
          <button type="button" className={'btn ' + (historyOpen && historyMode === 'DAY' ? 'btn-primary' : 'btn-outline')} onClick={() => { setHasSelectedDay(true); openHistory('DAY'); }}>일별 상세</button>
          <button type="button" className={'btn ' + (historyOpen && historyMode === 'WEEK' ? 'btn-primary' : 'btn-outline')} onClick={() => openHistory('WEEK')}>주별 기록</button>
          <button type="button" className={'btn ' + (historyOpen && historyMode === 'TERM' ? 'btn-primary' : 'btn-outline')} onClick={() => openHistory('TERM')}>학기 누계</button>
          {historyOpen && <button type="button" className="desk-history-close" onClick={() => setHistoryOpen(false)} aria-label="상세 기록 접기"><X size={16} /></button>}
        </div>
      </section>
    </div>

    {historyOpen && <div className="desk-inline-history" data-testid="dashboard-inline-history">
      <PointHistory key={historyMode} initialMode={historyMode} date={historyDate} today={calendar.date} onDateChange={selectHistoryDate} students={students} scope={scope} />
    </div>}

    <section className="desk-students" aria-labelledby="dashboard-students">
      <div className="desk-students-heading"><div><h2 id="dashboard-students" ref={listHeading} tabIndex={-1}>학생 생활점수<span className="desk-row-count" aria-live="polite">{rows.length}명</span></h2><p>주간 점수와 생활지도 상태를 확인합니다.</p></div><span className="desk-net-legend">주간 상벌NET = 상점 − 벌점</span></div>
      <div className="desk-filter-bar"><div className="desk-filter-tabs" role="group" aria-label="대상자 필터">{targetLabels.map(([value, label]) => <button key={value} type="button" aria-pressed={target === value} className={target === value ? 'is-active' : ''} onClick={() => setTarget(value)}>{label}</button>)}</div>
        <div className="desk-search-tools"><div className="search-box"><Search size={17} aria-hidden="true" /><input className="input" value={search} onChange={event => setSearch(event.target.value)} placeholder="이름 · 학번 · 반" aria-label="학생 검색" data-testid="input-dashboard-search" />{search && <button type="button" className="desk-clear-search" aria-label="검색어 지우기" onClick={() => setSearch('')}><X size={15} /></button>}</div><select className="select" value={sort} onChange={event => setSort(event.target.value as typeof sort)} aria-label="학생 정렬" data-testid="select-dashboard-sort"><option value="net">주간 상벌NET 낮은 순</option><option value="grade">학년/반 순</option><option value="name">이름 순</option></select></div>
      </div>
      <div className="table-wrap"><table className="data-table desk-student-table"><caption className="desk-sr-only">학생별 주간 상점, 벌점, 상벌NET 및 생활지도 상태</caption><thead><tr><th scope="col">학생</th><th scope="col">학년 / 반</th><th scope="col" className="desk-number">주간 상점</th><th scope="col" className="desk-number">주간 벌점</th><th scope="col" className="desk-number desk-net-cell">주간 상벌NET</th><th scope="col">상태</th></tr></thead><tbody>{rows.map(student => <tr key={student.id} data-testid={'row-dashboard-student-' + student.id}>
        <td><Link className="desk-student-identity" href={'/students/' + (student.coreStudentId ?? student.id)} data-testid={'link-dashboard-student-' + student.id}><span className="desk-student-avatar" aria-hidden="true">{student.name.slice(0, 1)}</span><span><strong>{student.name}</strong><small>{student.studentNo ?? '학번 미등록'}</small></span></Link></td><td>{student.homeroom ?? student.grade + '학년'}</td><td className="desk-number success-text">+{student.weeklyPositivePoints}</td><td className="desk-number">−{student.weeklyPenaltyPoints}</td><td className={'desk-number desk-net-cell' + (student.weeklyNetPenaltyPoints >= 8 ? ' danger-text' : '')}>{student.weeklyPositivePoints - student.weeklyPenaltyPoints}</td><td><div className="status-list">{student.statuses.length > 0 ? student.statuses.map(status => status === '체력훈련 대상'
          ? <span className="desk-training-status" key={status}><span className="pill pill-training">{status}</span>
            {student.physicalTrainingReasons.length > 0 && <small className="desk-training-reasons">사유: {student.physicalTrainingReasons.join(' · ')}</small>}
            </span>
          : <span className={'pill ' + (status === '반성문 2배 제출 대상' ? 'pill-negative' : 'pill-warning')} key={status}>{status}</span>) : <span className="desk-status-clear"><Check size={14} />양호</span>}</div></td>
      </tr>)}</tbody></table></div>
      {rows.length === 0 && <div className="desk-empty"><Users size={28} aria-hidden="true" /><strong>{search ? '검색 결과가 없습니다' : '해당 대상자가 없습니다'}</strong><p>{search ? '이름·학번·반 또는 선택한 필터를 확인해 주세요.' : '현재 선택한 조건에 해당하는 학생이 없습니다.'}</p>{(search || target !== 'ALL') && <button className="btn btn-outline" type="button" onClick={() => { setSearch(''); setTarget('ALL'); }}>전체 학생 보기</button>}</div>}
      <div className="desk-table-footer"><span>{targetLabels.find(([value]) => value === target)?.[1]} · {rows.length}명</span><span>학생 이름을 누르면 상세 기록으로 이동합니다.</span></div>
    </section>
    {isLead && <Link className="btn btn-outline desk-import-link" href="/history/import">주간 원장 · 이관 이력</Link>}
  </div>;
}

