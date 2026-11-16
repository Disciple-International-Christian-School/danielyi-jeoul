import { Link } from 'wouter';
import type { DisciplineScope, Reflection, SeondoNotice, SeondoSettlement } from '@/lib/api';

export type SettlementState = { data: SeondoSettlement | null | undefined; loading: boolean; error: boolean };
export const dashboardTime = (value: string) => new Intl.DateTimeFormat('ko-KR', {
  month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'Asia/Seoul',
}).format(new Date(value));
const localDay = (value: string) => new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Seoul' }).format(new Date(value));

export function settlementCaption(state: SettlementState, kind: '주간' | '월간') {
  if (state.error) return `${kind} 결산 조회 실패`;
  if (state.loading || state.data === undefined) return `${kind} 결산 확인 중`;
  if (!state.data) return `확정된 ${kind} 결산 없음`;
  return `${kind} · ${dashboardTime(state.data.closes_at)} 결산`;
}

export function DashboardOperations({ notice, reflections, date, isLead, scope, weekly, monthly, retry }: {
  notice: SeondoNotice;
  reflections: Reflection[];
  date: string;
  isLead: boolean;
  scope?: DisciplineScope | null;
  weekly: SettlementState;
  monthly: SettlementState;
  retry: () => void;
}) {
  const pending = reflections.filter(row => row.isCurrentStudent && row.status !== 'SUBMITTED');
  const dueToday = pending.filter(row => localDay(row.actionDueAt) === date);
  const earlier = pending.filter(row => localDay(row.actionDueAt) < date);
  const count = (rows: Reflection[]) => new Set(rows.map(row => row.coreStudentId)).size;
  const batch = notice.batch;
  const stage = !batch ? 0 : !batch.published_at ? 1 : 2;
  const visibleEntries = notice.entries.filter(row => !scope || scope === 'ALL' ||
    (scope === 'ELEMENTARY' ? row.grade <= 6 : scope === 'MIDDLE' ? row.grade >= 7 && row.grade <= 8 : row.grade >= 9));

  return <section className="desk-operations" aria-label="규칙 적용 및 오늘 할 일">
    <div className="desk-policy-line" data-testid="dashboard-policy-status">
      <span className={'pill ' + (notice.active ? 'pill-positive' : 'pill-neutral')}>{notice.active ? '새 규칙 적용 중' : '기존 규칙 적용 중'}</span>
      <span>{notice.active ? '게시 기준 반성문 · 주간·월간 확정 결산' : '새 규칙 전환 대기 · 활성화 전까지 기존 기준으로 표시합니다.'}</span>
      <details className="desk-rule-help"><summary>변경 기준 보기</summary><div>
        <p>출력 마감 때 상점 잔액을 배분하고 반성문 페이지를 확정합니다. 상점은 접수 기준 5평일 동안 유효하며, 한 번 사용한 상점은 다시 사용하지 않습니다.</p>
        <p>게시일 기준 초등은 첫째·둘째 수업일 08:20, 중고등은 당일·다음 수업일 17:00이 1차·2차 제출 기한입니다.</p>
        <p>일요일 23:59 주간 결산, 월말 23:59 월간 결산. 같은 달 체력훈련 확정 3회 이상인 중고등 학생이 징계위 검토 대상입니다.</p>
        {!notice.active && <p>시행 시점은 아직 도래하지 않았습니다. 기존 사건에는 당시 기준과 기한이 유지됩니다.</p>}
      </div></details>
    </div>
    <div className="desk-operations-grid">
      <div className="desk-notice-state" data-testid="dashboard-notice-state">
        <h2>{notice.active ? '오늘 공지 진행' : '오늘 공지 확인'}</h2>
        {notice.active ? <>
          <ol className="desk-notice-steps" aria-label="공지 진행 단계">{['출력 마감 전', '게시 대기', '게시 완료'].map((label, index) =>
            <li key={label} aria-current={stage === index ? 'step' : undefined} className={stage === index ? 'is-current' : ''}>{label}</li>)}</ol>
          <p>{batch ? <>출력 마감 {dashboardTime(batch.cutoff_at)} · 담당 범위 {visibleEntries.length}건{batch.published_at && <> · 게시 {dashboardTime(batch.published_at)}</>}</> : '출력 마감을 확정하면 이번 공지 명단과 페이지가 정해집니다.'}</p>
          <Link className="btn btn-outline" href="/reports">{isLead ? ['출력 마감 확인하기', '인쇄·게시 확정하기', '게시 명단 확인하기'][stage] : '공지 상태 확인하기'}</Link>
        </> : <><p>오늘 발생·마감되는 반성문과 이월된 2배 제출 대상을 확인합니다.</p><Link className="btn btn-outline" href="/reports">오늘 공지·출력</Link></>}
      </div>
      <div className="desk-deadline-state">
        <h2>제출 기한 확인 <small>한국 시간</small></h2>
        <div className="desk-deadline-counts"><Link href="/reflections?view=MISSING"><span>오늘 마감</span><strong>{count(dueToday)}<small>명</small></strong></Link><Link href="/reflections?view=MISSING"><span>이전 날짜 미제출</span><strong>{count(earlier)}<small>명</small></strong></Link></div>
        <p>현재 제출 기한 기준 · 2배 대상은 2차 기한 · 연장된 기한 포함</p>
        {notice.active && isLead && <div className="desk-closure-links">
          <Link href="/reports?view=WEEKLY">{settlementCaption(weekly, '주간')}</Link>
          <Link href="/reports?view=MONTHLY">{settlementCaption(monthly, '월간')}</Link>
          {(weekly.error || monthly.error) && <button type="button" className="btn btn-outline" onClick={retry}>결산 다시 확인</button>}
        </div>}
      </div>
    </div>
  </section>;
}
