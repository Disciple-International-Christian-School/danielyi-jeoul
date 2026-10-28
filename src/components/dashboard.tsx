import { useMemo, useRef, useState, type ReactNode } from 'react';
import { ArrowDownRight, ArrowRight, ArrowUpRight, BookOpenCheck, CalendarDays, Check, ChevronRight, CircleCheck, Clock3, Dumbbell, FileClock, Printer, Search, ShieldAlert, Users, X } from 'lucide-react';
import { Link } from 'wouter';
import type { DepartmentMeritStatus, DisciplineScope, Reflection, SettlementPeriod, StudentSummary } from '@/lib/api';
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
  departments: ReadState<DepartmentMeritStatus[]>;
  settlement: ReadState<SettlementPeriod | null>;
};

const scopeLabels = { ALL: '전체 학년', ELEMENTARY: '초등', MIDDLE: '중등', HIGH: '고등' };
const targetLabels: Array<[Target, string]> = [['ALL', '전체 학생'], ['PHYSICAL', '체력훈련 대상자'], ['COMMITTEE', '징계위원회 대상자']];
const shortDate = (date: string) => new Intl.DateTimeFormat('ko-KR', { month: 'numeric', day: 'numeric', timeZone: 'Asia/Seoul' }).format(new Date(date + 'T12:00:00+09:00'));

function ActionRow({ href, icon, title, copy, badge }: { href: string; icon: ReactNode; title: string; copy: string; badge?: string }) {
  return <Link className="desk-action-row" href={href}>
    <span className="desk-action-icon" aria-hidden="true">{icon}</span>
    <span className="desk-action-copy"><strong>{title}</strong><span>{copy}</span></span>
    {badge && <span className="desk-action-badge">{badge}</span>}
    <ChevronRight size={17} aria-hidden="true" />
  </Link>;
}

export function DashboardView({ students, reflections, calendar, scope, isLead, departments, settlement }: Props) {
  const [historyDate, setHistoryDate] = useState(calendar.date);
  const [historyVersion, setHistoryVersion] = useState(0);
  const historyPanel = useRef<HTMLDivElement>(null);
  const selectHistoryDate = (date: string) => {
    setHistoryDate(date);
    setHistoryVersion(value => value + 1);
    historyPanel.current?.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth', block: 'start' });
  };
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
      // Gross components keep merit-only and fully offset records above empty rows.
      const hasPoints = (student: StudentSummary) =>
        student.positivePoints > 0 || student.negativePoints > 0 || student.weeklyRecordCount > 0;
      const recordedFirst = Number(hasPoints(b)) - Number(hasPoints(a));
      if (recordedFirst) return recordedFirst;
      return (sort === 'name' ? a.name.localeCompare(b.name, 'ko') : sort === 'grade'
        ? a.grade - b.grade || (a.homeroom ?? '').localeCompare(b.homeroom ?? '', 'ko')
        : b.weeklyNetPenaltyPoints - a.weeklyNetPenaltyPoints)
        || a.name.localeCompare(b.name, 'ko');
    });
  }, [students, search, sort, target]);
  const personCount = (predicate: (reflection: Reflection) => boolean) => new Set(reflections.filter(predicate).map(row => row.coreStudentId)).size;
  const missing = personCount(row => row.status !== 'SUBMITTED');
  const metrics = [
    { label: '반성문 대상자', value: personCount(row => !row.submitted && (row.recordedAt.slice(0, 10) === calendar.date || row.status === 'DOUBLE')), note: '오늘 미제출 + 이월 2배', icon: BookOpenCheck, href: '/reflections?view=TODAY', tone: 'normal' },
    { label: '반성문 미제출자', value: missing, note: '이전 날짜 포함 · 미제출 전체', icon: FileClock, href: '/reflections?view=MISSING', tone: 'watch' },
    { label: '2배 제출 대상자', value: personCount(row => row.status === 'DOUBLE'), note: '미제출자 중 마감 경과', icon: Clock3, href: '/reflections?view=DOUBLE', tone: 'urgent' },
    { label: '체력훈련 대상자', value: students.filter(row => row.physicalTrainingRequired).length, note: '주간 3회 또는 상벌NET -8점 이하', icon: Dumbbell, target: 'PHYSICAL' as Target, tone: 'training' },
    { label: '징계위원회 대상자', value: students.filter(row => row.committeeRequired).length, note: '이번 학기 체력훈련 대상 3주 연속', icon: ShieldAlert, target: 'COMMITTEE' as Target, tone: 'normal' },
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
  const settlementLabel = settlement.loading ? '정산기간 확인 중' : settlement.error ? '정산기간 조회 실패' : settlement.data?.label ?? '정산기간 미설정';
  const settlementCopy = settlement.loading ? '잠시만 기다려 주세요.' : settlement.error ? '정산 관리에서 다시 확인해 주세요.' : settlement.data ? shortDate(settlement.data.startsOn) + '부터 누적 중' : isLead ? '정산 관리에서 기간을 시작해 주세요.' : '담당 관리자에게 기간 설정을 요청해 주세요.';

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
        <ol className="desk-week-days" aria-label="이번 주 달력">{days.map(day => <li key={day.date} className={day.date === calendar.date ? 'is-today' : ''} aria-current={day.date === calendar.date ? 'date' : undefined}><button type="button" disabled={day.date > calendar.date} aria-label={day.date + ' 기록 보기'} onClick={() => selectHistoryDate(day.date)}><span>{day.label}</span><strong>{day.day}</strong><span className="desk-day-marker">{day.date === calendar.date ? '오늘' : '\u00a0'}</span></button></li>)}</ol>
        {isLead ? <div className="desk-merit">
          <div className="desk-merit-heading"><span>{!departments.loading && !departments.error && total > 0 && generated === total ? <CircleCheck size={18} /> : <CalendarDays size={18} />}부서상점 자동반영</span><Link href="/points/positive/departments">관리<ArrowRight size={15} /></Link></div>
          <div className="desk-merit-status"><strong>{meritLabel}</strong>{!departments.loading && !departments.error && total > 0 && <span>{generated} / {total}건</span>}</div>
          {!departments.loading && !departments.error && total > 0 ? <progress aria-label="이번 주 부서상점 반영" max={total} value={generated} /> : <p>{departments.error ? '관리 화면에서 반영 내역을 다시 확인해 주세요.' : departments.loading ? '이번 주 반영 내역을 불러오고 있습니다.' : '부서 규칙과 소속 학생을 등록하면 매주 자동 반영됩니다.'}</p>}
        </div> : <div className="desk-week-note"><CalendarDays size={18} /><p>주간 점수는 월요일부터 집계됩니다.<br />이번 주 대상자 현황을 확인해 주세요.</p></div>}
      </section>
      <section className="desk-work" aria-labelledby="desk-work-title"><div className="desk-panel-heading"><div><span className="desk-panel-kicker">업무 바로가기</span><h2 id="desk-work-title">확인하고 이어가기</h2></div></div>
        <ActionRow href="/reflections?view=MISSING" icon={<BookOpenCheck size={20} />} title="반성문 제출 확인" copy={missing > 0 ? '미제출 명단에서 제출 여부를 확인하세요.' : '현재 미제출 대상자가 없습니다.'} badge={missing > 0 ? missing + '명 미제출' : undefined} />
        <ActionRow href="/reports" icon={<Printer size={20} />} title="공지·명단 출력" copy="생활지도 공지와 주간 명단을 준비하세요." />
        {isLead ? <ActionRow href="/settlement" icon={<CalendarDays size={20} />} title={settlementLabel} copy={settlementCopy} /> : <div className="desk-settlement-note"><CalendarDays size={18} /><div><strong>{settlementLabel}</strong><span>{settlementCopy}</span></div></div>}
      </section>
    </div>

    <section className="desk-students" aria-labelledby="dashboard-students">
      <div className="desk-students-heading"><div><h2 id="dashboard-students" ref={listHeading} tabIndex={-1}>학생 생활점수<span className="desk-row-count" aria-live="polite">{rows.length}명</span></h2><p>주간 점수와 현재 정산기간의 누적 점수를 확인합니다.</p></div><span className="desk-net-legend">주간 상벌NET · 누적NET = 상점 − 벌점</span></div>
      <div className="desk-filter-bar"><div className="desk-filter-tabs" role="group" aria-label="대상자 필터">{targetLabels.map(([value, label]) => <button key={value} type="button" aria-pressed={target === value} className={target === value ? 'is-active' : ''} onClick={() => setTarget(value)}>{label}</button>)}</div>
        <div className="desk-search-tools"><div className="search-box"><Search size={17} aria-hidden="true" /><input className="input" value={search} onChange={event => setSearch(event.target.value)} placeholder="이름 · 학번 · 반" aria-label="학생 검색" data-testid="input-dashboard-search" />{search && <button type="button" className="desk-clear-search" aria-label="검색어 지우기" onClick={() => setSearch('')}><X size={15} /></button>}</div><select className="select" value={sort} onChange={event => setSort(event.target.value as typeof sort)} aria-label="학생 정렬" data-testid="select-dashboard-sort"><option value="net">주간 상벌NET 낮은 순</option><option value="grade">학년/반 순</option><option value="name">이름 순</option></select></div>
      </div>
      <div className="table-wrap"><table className="data-table desk-student-table"><caption className="desk-sr-only">학생별 주간 상점, 벌점, 상벌NET 및 정산기간 상태</caption><thead><tr><th scope="col">학생</th><th scope="col">학년 / 반</th><th scope="col" className="desk-number">주간 상점</th><th scope="col" className="desk-number">주간 벌점</th><th scope="col" className="desk-number desk-net-cell">주간 상벌NET</th><th scope="col" className="desk-number">누적NET</th><th scope="col">상태</th></tr></thead><tbody>{rows.map(student => <tr key={student.id} data-testid={'row-dashboard-student-' + student.id}>
        <td><Link className="desk-student-identity" href={'/students/' + (student.coreStudentId ?? student.id)} data-testid={'link-dashboard-student-' + student.id}><span className="desk-student-avatar" aria-hidden="true">{student.name.slice(0, 1)}</span><span><strong>{student.name}</strong><small>{student.studentNo ?? '학번 미등록'}</small></span></Link></td><td>{student.homeroom ?? student.grade + '학년'}</td><td className="desk-number success-text">+{student.weeklyPositivePoints}</td><td className="desk-number">−{student.weeklyPenaltyPoints}</td><td className={'desk-number desk-net-cell' + (student.weeklyNetPenaltyPoints >= 8 ? ' danger-text' : '')}>{student.weeklyPositivePoints - student.weeklyPenaltyPoints}</td><td className="desk-number">{student.settlementPositivePoints - student.settlementPenaltyPoints}</td><td><div className="status-list">{student.statuses.length > 0 ? student.statuses.map(status => <span className={'pill ' + (status === '체력훈련 대상' ? 'pill-training' : status === '반성문 2배 제출 대상' ? 'pill-negative' : 'pill-warning')} key={status}>{status}</span>) : <span className="desk-status-clear"><Check size={14} />양호</span>}</div></td>
      </tr>)}</tbody></table></div>
      {rows.length === 0 && <div className="desk-empty"><Users size={28} aria-hidden="true" /><strong>{search ? '검색 결과가 없습니다' : '해당 대상자가 없습니다'}</strong><p>{search ? '이름·학번·반 또는 선택한 필터를 확인해 주세요.' : '현재 선택한 조건에 해당하는 학생이 없습니다.'}</p>{(search || target !== 'ALL') && <button className="btn btn-outline" type="button" onClick={() => { setSearch(''); setTarget('ALL'); }}>전체 학생 보기</button>}</div>}
      <div className="desk-table-footer"><span>{targetLabels.find(([value]) => value === target)?.[1]} · {rows.length}명</span><span>학생 이름을 누르면 상세 기록으로 이동합니다.</span></div>
    </section>
    {isLead && <Link className="btn btn-outline" href="/history/import">주간 원장 · 이관 이력</Link>}
    <div ref={historyPanel}><PointHistory key={historyVersion} date={historyDate} today={calendar.date} onDateChange={setHistoryDate} students={students} scope={scope} /></div>
  </div>;
}

