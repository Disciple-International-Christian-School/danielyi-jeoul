import { createContext, useContext, useEffect, useMemo, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { QueryClient, QueryClientProvider, useQueryClient } from '@tanstack/react-query';
import {
  AlertTriangle,
  ArrowDownRight,
  ArrowUpRight,
  BedDouble,
  BookOpenCheck,
  CalendarRange,
  Check,
  ChevronLeft,
  CircleHelp,
  Database,
  FileSpreadsheet,
  Gauge,
  LayoutDashboard,
  LogOut,
  Pencil,
  Plus,
  Printer,
  RefreshCw,
  Search,
  ShieldAlert,
  SlidersHorizontal,
  Trash2,
  Users,
  X,
} from 'lucide-react';
import { Link, Redirect, Route, Router as WouterRouter, Switch, useLocation, useParams } from 'wouter';

import {
  PUNISHMENT_TYPES,
  getGetDashboardQueryKey,
  getGetStudentQueryKey,
  getListPointItemsQueryKey,
  getListPointRecordsQueryKey,
  getListPunishmentsQueryKey,
  getListReflectionsQueryKey,
  getListStudentsQueryKey,
  getCurrentSettlementQueryKey,
  getDepartmentMeritStatusQueryKey,
  useDailyDisciplineNotice,
  useWeeklyDisciplineReport,
  useCreatePointItem,
  useCreatePointRecord,
  useCreatePunishment,
  useCloseSettlementPeriod,
  useCurrentSettlement,
  useDeletePointItem,
  useDeletePointRecord,
  useDepartmentMeritStatus,
  useEnsureWeeklyDepartmentMerits,
  useGetDashboard,
  useGetStudent,
  useExtendReflectionTo21,
  useImportPointItems,
  useListPointItems,
  useListPointRecords,
  useListPunishments,
  useListReflections,
  useListStudents,
  useSetPunishmentViolation,
  useStartSettlementPeriod,
  useUpdatePointItem,
  useUpdatePointRecord,
  useUpdateReflection,
  type DailyDisciplineNotice,
  type DisciplineScope,
  type PointItem,
  type PointRecord,
  type Punishment,
  type Role,
  type WeeklyDisciplineReport,
} from '@/lib/api';
import { AuthProvider, useAuth } from '@/lib/auth';
import { supabase, supabaseConfigured } from '@/lib/supabase';
import './index.css';

const queryClient = new QueryClient();
const basePath = import.meta.env.BASE_URL.replace(/\/$/, '');

type NoticeTone = 'success' | 'error';
const NoticeContext = createContext<(message: string, tone?: NoticeTone) => void>(() => undefined);

function dateLabel(value?: string | null) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('ko-KR', { month: 'short', day: 'numeric', timeZone: 'Asia/Seoul' }).format(new Date(value));
}
function dateTimeLabel(value?: string | null) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('ko-KR', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Seoul' }).format(new Date(value));
}
function today() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}
function errText(error: unknown) { return error instanceof Error ? error.message : '요청을 처리하지 못했습니다.'; }

function Brand() {
  return <Link href="/" className="brand" data-testid="link-brand">
    <span className="brand-mark" aria-hidden="true">저울</span>
    <span className="brand-name">다니엘의 저울</span>
  </Link>;
}

function Toast({ message, tone, onClose }: { message: string; tone: NoticeTone; onClose: () => void }) {
  return <div className="toast-note" data-tone={tone} role="status" data-testid="status-toast">
    <span>{message}</span><button className="btn btn-icon" onClick={onClose} aria-label="알림 닫기" data-testid="button-close-toast"><X size={15} /></button>
  </div>;
}

function AppShell({ children, role }: { children: ReactNode; role: Role }) {
  const [location] = useLocation();
  const { admin, signOut } = useAuth();
  const [, setLocation] = useLocation();
  const [notice, setNotice] = useState<{ message: string; tone: NoticeTone } | null>(null);
  const nav = [
    { href: '/dashboard', label: '대시보드', icon: LayoutDashboard, roles: ['SEONDO', 'SASAENG'] as Role[], leadOnly: false },
    { href: '/students', label: '학생 관리', icon: Users, roles: ['SEONDO'] as Role[], leadOnly: false },
    { href: '/points/negative', label: '벌점 입력', icon: ArrowDownRight, roles: ['SEONDO'] as Role[], leadOnly: false },
    { href: '/points/positive', label: '상점 입력', icon: ArrowUpRight, roles: ['SEONDO'] as Role[], leadOnly: false },
    { href: '/reflections', label: '반성문', icon: BookOpenCheck, roles: ['SEONDO'] as Role[], leadOnly: false },
    { href: '/reports', label: '공지·출력', icon: Printer, roles: ['SEONDO'] as Role[], leadOnly: false },
    { href: '/settlement', label: '정산 관리', icon: CalendarRange, roles: ['SEONDO'] as Role[], leadOnly: true },
    { href: '/punishments', label: '기숙사 처분', icon: BedDouble, roles: ['SASAENG'] as Role[], leadOnly: false },
    { href: '/point-items', label: '점수 항목', icon: SlidersHorizontal, roles: ['SEONDO'] as Role[], leadOnly: false },
  ];
  const title = nav.find((item) => location.startsWith(item.href))?.label ?? '대시보드';
  const displayName = admin?.displayName ?? '관리자';
  const roleLabel = admin?.roleLabel ?? (role === 'SASAENG' ? '사생회' : '선도부');
  const handleSignOut = async () => { await signOut(); setLocation('/'); };
  return <NoticeContext.Provider value={(message, tone = 'success') => setNotice({ message, tone })}><div className="app-shell">
    <aside className="sidebar">
      <Brand />
      <div className="nav-label">운영 메뉴</div>
      <nav className="nav-list" aria-label="주요 메뉴">
        {nav.filter((item) => item.roles.includes(role) && (!item.leadOnly || admin?.isLead)).map((item) => {
          const Icon = item.icon;
          return <Link key={item.href} href={item.href} className={`nav-link ${location.startsWith(item.href) ? 'active' : ''}`} data-testid={`link-nav-${item.href.slice(1).replace('/', '-')}`}>
            <Icon size={16} strokeWidth={1.7} /><span>{item.label}</span>
          </Link>;
        })}
      </nav>
      <div className="sidebar-bottom">
        <div className="user-mini">
          <div className="avatar" data-testid="avatar-admin">{displayName.slice(0, 1)}</div>
          <div className="user-mini-copy"><div className="user-mini-name" data-testid="text-admin-name">{displayName}</div><div className="user-mini-meta">{roleLabel}</div></div>
        </div>
        <button className="nav-link" onClick={handleSignOut} data-testid="button-sign-out"><LogOut size={16} /><span>로그아웃</span></button>
      </div>
    </aside>
    <main className="main-area">
      <header className="topbar">
        <div className="mobile-brand"><span className="brand-mark">저울</span><span>다니엘의 저울</span></div>
        <div className="topbar-title">{title}</div>
        <div className="topbar-actions"><span className="topbar-date">{new Intl.DateTimeFormat('ko-KR', { dateStyle: 'full' }).format(new Date())}</span><span className="pill pill-positive" data-testid="status-health"><Gauge size={12} /> 운영 중</span></div>
      </header>
      <div className="content page-enter">{children}</div>
    </main>
    {notice && <Toast message={notice.message} tone={notice.tone} onClose={() => setNotice(null)} />}
  </div></NoticeContext.Provider>;
}

function LoadingState() {
  return <div className="app-loading"><div className="loading-stack"><div className="skeleton" /><div className="skeleton" /><div className="skeleton" /></div></div>;
}
function ErrorState({ error, retry }: { error: unknown; retry: () => void }) {
  return <div className="error-box"><AlertTriangle size={24} /><p>{errText(error)}</p><button className="btn btn-outline" onClick={retry} data-testid="button-retry"><RefreshCw size={14} /> 다시 시도</button></div>;
}
function EmptyState({ title, copy }: { title: string; copy: string }) {
  return <div className="empty-state"><Database size={28} /><strong>{title}</strong><p>{copy}</p></div>;
}
function PageHeader({ eyebrow, title, copy, action }: { eyebrow: string; title: string; copy: string; action?: ReactNode }) {
  return <div className="page-toolbar"><div><div className="eyebrow">{eyebrow}</div><h1 className="heading">{title}</h1><p className="subheading">{copy}</p></div>{action && <div className="toolbar-right">{action}</div>}</div>;
}
function RoleGate({ role, children }: { role: Role; children: ReactNode }) {
  const { admin, loading } = useAuth();
  if (loading) return <LoadingState />;
  if (admin?.role !== role) return <Redirect to="/dashboard" />;
  return <>{children}</>;
}

function LeadGate({ children }: { children: ReactNode }) {
  const { admin, loading } = useAuth();
  if (loading) return <LoadingState />;
  if (admin?.role !== 'SEONDO' || !admin.isLead) return <Redirect to="/dashboard" />;
  return <>{children}</>;
}

function DashboardPage() {
  const dashboard = useGetDashboard();
  const departmentStatus = useDepartmentMeritStatus();
  const ensureDepartmentMerits = useEnsureWeeklyDepartmentMerits();
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const { admin } = useAuth();
  const [search, setSearch] = useState('');

  useEffect(() => {
    if (admin?.role !== 'SEONDO') return;
    ensureDepartmentMerits.mutate(undefined, {
      onSuccess: (inserted) => {
        queryClient.invalidateQueries({ queryKey: getDepartmentMeritStatusQueryKey() });
        if (inserted > 0) {
          queryClient.invalidateQueries({ queryKey: getGetDashboardQueryKey() });
          queryClient.invalidateQueries({ queryKey: getListStudentsQueryKey() });
          notify(`이번 주 부서활동 상점 ${inserted}건을 자동 반영했습니다.`);
        }
      },
    });
    // RPC is idempotent; run once per dashboard mount.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [admin?.role]);

  const [sort, setSort] = useState<'net' | 'grade' | 'name'>('net');
  const [, setLocation] = useLocation();

  const rows = useMemo(() => {
    const needle = search.trim().toLowerCase();
    const list = (dashboard.data?.students ?? []).filter((student) =>
      !needle
      || student.name.toLowerCase().includes(needle)
      || (student.studentNo ?? '').toLowerCase().includes(needle)
      || (student.homeroom ?? '').toLowerCase().includes(needle)
    );
    return [...list].sort((a, b) =>
      sort === 'name'
        ? a.name.localeCompare(b.name, 'ko')
        : sort === 'grade'
          ? a.grade - b.grade || (a.homeroom ?? '').localeCompare(b.homeroom ?? '', 'ko')
          : b.weeklyNetPenaltyPoints - a.weeklyNetPenaltyPoints
    );
  }, [dashboard.data?.students, search, sort]);

  if (dashboard.isLoading) return <LoadingState />;
  if (dashboard.isError || !dashboard.data) return <ErrorState error={dashboard.error} retry={() => dashboard.refetch()} />;

  const counts = dashboard.data.counts;
  const settlementLabel = dashboard.data.students.find((student) => student.settlementPeriodLabel)?.settlementPeriodLabel ?? '정산기간 미설정';
  const metrics = [
    ['등록 학생', counts.students, 'DICS Core 현재 학적', Users],
    ['체력훈련 대상', counts.weeklyTargets, '주 3회 또는 NET 8+', ShieldAlert],
    ['징계위원회 대상', counts.committeeTargets, '정산기간 기준', AlertTriangle],
    ['미제출 반성문', counts.missingReflections, '현재 마감 전 미제출', BookOpenCheck],
    ['2배 제출 대상', counts.doubleReflections, '마감 경과', BookOpenCheck],
  ] as const;

  return <div>
    <PageHeader
      eyebrow="오늘의 운영 현황"
      title="학생 생활점수, 한눈에."
      copy={'주간 NET과 ' + settlementLabel + ' 누적을 기준으로 생활지도 신호를 보여줍니다.'}
      action={<Link href="/points/negative" className="btn btn-primary" data-testid="link-quick-negative"><Plus size={15} /> 벌점 입력</Link>}
    />

    <div className="metric-grid" style={{ marginTop: 30 }}>
      {metrics.map(([label, value, note, Icon], index) => <div className="card metric-card" key={label} data-testid={'card-metric-' + index}>
        <Icon size={17} />
        <div className="metric-value">{value}</div>
        <div className="metric-label">{label}</div>
        <div className="muted" style={{ fontSize: 10, marginTop: 6 }}>{note}</div>
      </div>)}
    </div>

    {(departmentStatus.data?.length ?? 0) > 0 && <div className="side-note" style={{ marginTop: 20 }}>
      <strong>부서활동 자동 상점</strong>
      <span style={{ marginLeft: 10 }}>
        이번 주 {departmentStatus.data?.filter((row) => row.generated).length ?? 0}/{departmentStatus.data?.length ?? 0}건 반영
      </span>
    </div>}

    <div className="section-row">
      <div>
        <h2 className="section-title">학생 상태 목록</h2>
        <p className="section-copy">상점·벌점 원점수는 보존하고, 처벌 판단에는 벌점 - 상점 NET을 사용합니다.</p>
      </div>
      <div className="toolbar-right">
        <div className="search-box"><Search size={15} /><input
          className="input"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="이름 · 학번 · 반 검색"
          aria-label="학생 검색"
          data-testid="input-dashboard-search"
        /></div>
        <select
          className="select"
          value={sort}
          onChange={(event) => setSort(event.target.value as 'net' | 'grade' | 'name')}
          aria-label="학생 정렬"
          data-testid="select-dashboard-sort"
        >
          <option value="net">주간 NET 높은 순</option>
          <option value="grade">학년/반 순</option>
          <option value="name">이름 순</option>
        </select>
      </div>
    </div>

    <div className="card card-pad table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            <th>학생</th>
            <th>학년 / 반</th>
            <th>주간 상점</th>
            <th>주간 벌점</th>
            <th>주간 NET</th>
            <th>정산 NET</th>
            <th>상태</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((student) => <tr key={student.id} data-testid={'row-dashboard-student-' + student.id}>
            <td>
              <Link className="table-link" href={'/students/' + student.id} data-testid={'link-dashboard-student-' + student.id}>{student.name}</Link>
              <div className="muted" style={{ fontSize: 10, marginTop: 3 }}>{student.studentNo ?? 'Core 매핑 대기'}</div>
            </td>
            <td>{student.homeroom ?? (student.grade + '학년')}</td>
            <td className="weight-number success-text">+{student.weeklyPositivePoints}</td>
            <td className="weight-number danger-text">{student.weeklyPenaltyPoints}</td>
            <td className={student.weeklyNetPenaltyPoints >= 8 ? 'weight-number danger-text' : 'weight-number'}>
              {student.weeklyNetPenaltyPoints}
            </td>
            <td className={student.settlementNetPenaltyPoints >= 20 ? 'weight-number danger-text' : 'weight-number'}>
              {student.settlementNetPenaltyPoints}
            </td>
            <td><div className="status-list">
              {student.statuses.length
                ? student.statuses.map((status) => <span className="pill pill-warning" key={status}>{status}</span>)
                : <span className="pill pill-positive"><Check size={11} /> 양호</span>}
            </div></td>
          </tr>)}
        </tbody>
      </table>
      {rows.length === 0 && <EmptyState title="검색 결과가 없습니다" copy="다른 이름, 학번 또는 반으로 다시 검색해 보세요." />}
    </div>

    <button type="button" onClick={() => setLocation('/students')} style={{ display: 'none' }} data-testid="button-dashboard-hidden-navigation" />
  </div>;
}

function StudentsPage() {
  const students = useListStudents();
  const [search, setSearch] = useState('');
  const needle = search.trim().toLowerCase();
  const rows = (students.data ?? []).filter((student) =>
    !needle
    || student.name.toLowerCase().includes(needle)
    || (student.studentNo ?? '').toLowerCase().includes(needle)
    || (student.homeroom ?? '').toLowerCase().includes(needle)
  );

  if (students.isLoading) return <LoadingState />;
  if (students.isError) return <ErrorState error={students.error} retry={() => students.refetch()} />;

  return <div>
    <PageHeader
      eyebrow="DICS Core"
      title="학생 명부"
      copy="학생 원본은 DICS Core에서 관리합니다. 다니엘의 저울에서는 명부를 별도로 추가·삭제하지 않습니다."
    />

    <div className="section-row">
      <div><h2 className="section-title">현재 학적 <span className="muted">{students.data?.length ?? 0}</span></h2></div>
      <div className="search-box"><Search size={15} /><input
        className="input"
        value={search}
        onChange={(event) => setSearch(event.target.value)}
        placeholder="이름 · 학번 · 반 검색"
        aria-label="학생 검색"
        data-testid="input-students-search"
      /></div>
    </div>

    <div className="card card-pad table-wrap">
      <table className="data-table">
        <thead><tr><th>학번</th><th>이름</th><th>학년 / 반</th><th>주간 NET</th><th>정산 NET</th><th>감지 상태</th></tr></thead>
        <tbody>
          {rows.map((student) => <tr key={student.id} data-testid={'row-student-' + student.id}>
            <td className="muted">{student.studentNo ?? '매핑 대기'}</td>
            <td><Link href={'/students/' + student.id} className="table-link" data-testid={'link-student-' + student.id}>{student.name}</Link></td>
            <td>{student.homeroom ?? (student.grade + '학년')}</td>
            <td>{student.weeklyNetPenaltyPoints}</td>
            <td>{student.settlementNetPenaltyPoints}</td>
            <td>{student.statuses.length ? student.statuses.join(', ') : '양호'}</td>
          </tr>)}
        </tbody>
      </table>
      {rows.length === 0 && <EmptyState title="학생이 없습니다" copy="DICS Core 현재 학기 명부와 legacy mapping 상태를 확인하세요." />}
    </div>

    <div className="side-note" style={{ marginTop: 18 }}>
      <strong>명부 관리 원칙</strong><br />
      학생 추가·학번·생년월일·성별·학년/반 변경은 DICS Core roster에서 처리하고, 이 앱은 생활지도 데이터만 관리합니다.
    </div>
  </div>;
}

function StudentDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const queryClient = useQueryClient();
  const detail = useGetStudent(id);
  const records = useListPointRecords({ studentId: id, limit: 100 });
  const deleteRecord = useDeletePointRecord();
  const updateRecord = useUpdatePointRecord();
  const setViolation = useSetPunishmentViolation();
  const notify = useContext(NoticeContext);
  if (detail.isLoading) return <LoadingState />;
  if (detail.isError || !detail.data) return <ErrorState error={detail.error} retry={() => detail.refetch()} />;
  const student = detail.data;
  const refreshDetail = () => { queryClient.invalidateQueries({ queryKey: getGetStudentQueryKey(id) }); queryClient.invalidateQueries({ queryKey: getListPointRecordsQueryKey({ studentId: id, limit: 100 }) }); };
  const removeRecord = (record: PointRecord) => { if (window.confirm('이 점수 기록을 삭제할까요?')) deleteRecord.mutate({ id: record.id }, { onSuccess: () => { refreshDetail(); notify('점수 기록을 삭제했습니다.'); }, onError: (error) => notify(errText(error), 'error') }); };
  const editRecord = (record: PointRecord) => {
    const nextPoints = window.prompt('점수를 입력하세요.', String(record.points));
    if (!nextPoints || Number.isNaN(Number(nextPoints))) return;
    updateRecord.mutate({ id: record.id, data: { points: Number(nextPoints), item: record.item, recordedAt: record.recordedAt, enteredByName: record.enteredByName, reflectionSubmitted: record.reflection?.submitted ?? null } }, { onSuccess: () => { refreshDetail(); notify('점수 기록을 수정했습니다.'); }, onError: (error) => notify(errText(error), 'error') });
  };
  const toggleViolated = (punishment: Punishment) => setViolation.mutate({ id: punishment.id, violated: !punishment.violated }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: getGetStudentQueryKey(id) }), onError: (error) => notify(errText(error), 'error') });
  return <div><Link href="/students" className="btn btn-outline" data-testid="link-back-students"><ChevronLeft size={15} /> 학생 목록</Link><div style={{ marginTop: 25 }} className="detail-hero"><div><div className="eyebrow">학생 상세 기록</div><h1 className="heading">{student.name}</h1><p className="subheading">{student.homeroom ?? (student.grade + '학년')}{student.studentNo ? ' · ' + student.studentNo : ''} · 최근 생활점수와 상태 신호</p><div className="status-list">{student.statuses.length ? student.statuses.map((status) => <span className="pill pill-warning" key={status}>{status}</span>) : <span className="pill pill-positive"><Check size={11} /> 현재 양호</span>}</div></div><div className="detail-avatar">{student.name.slice(0, 1)}</div></div><div className="metric-grid" style={{ marginTop: 28 }}><div className="card metric-card"><div className="metric-label">주간 상점</div><div className="metric-value success-text">+{student.weeklyPositivePoints}</div></div><div className="card metric-card"><div className="metric-label">주간 벌점</div><div className="metric-value danger-text">{student.weeklyPenaltyPoints}</div></div><div className="card metric-card"><div className="metric-label">주간 NET</div><div className="metric-value">{student.weeklyNetPenaltyPoints}</div></div><div className="card metric-card"><div className="metric-label">정산기간 NET</div><div className="metric-value">{student.settlementNetPenaltyPoints}</div></div><div className="card metric-card"><div className="metric-label">체력훈련 판정 주차</div><div className="metric-value">{student.physicalTrainingWeeks}</div></div><div className="card metric-card"><div className="metric-label">기숙사 처분</div><div className="metric-value" style={{ fontSize: 14 }}>{student.punishment ?? '없음'}</div></div></div><div className="detail-grid" style={{ marginTop: 18 }}><section className="card card-pad"><div className="section-row" style={{ margin: 0 }}><div><h2 className="section-title">점수 이력</h2><p className="section-copy">최근 기록부터 확인합니다.</p></div></div>{records.isLoading ? <div className="skeleton" style={{ height: 90, marginTop: 18 }} /> : records.isError ? <ErrorState error={records.error} retry={() => records.refetch()} /> : <div className="record-list">{(records.data ?? []).map((record) => <div className="record-row" key={record.id} data-testid={`row-record-${record.id}`}><div className="record-date">{dateLabel(record.recordedAt)}</div><div className="record-main"><div className="record-item">{record.item}</div><div className="record-meta">{record.enteredByName}{record.reflection ? ` · 반성문 ${record.reflection.status === 'SUBMITTED' ? '제출' : record.reflection.status === 'DOUBLE' ? '2배 대상' : '미제출'}` : ''}</div></div><div className={`record-points ${record.type === 'NEGATIVE' ? 'negative' : 'positive'}`}>{record.type === 'NEGATIVE' ? '-' : '+'}{record.points}<button className="btn btn-icon btn-outline" style={{ marginLeft: 8 }} onClick={() => editRecord(record)} aria-label="점수 기록 수정" data-testid={`button-edit-record-${record.id}`}><Pencil size={13} /></button><button className="btn btn-icon btn-danger" style={{ marginLeft: 6 }} onClick={() => removeRecord(record)} aria-label="점수 기록 삭제" data-testid={`button-delete-record-${record.id}`}><Trash2 size={13} /></button></div></div>)}{(records.data ?? []).length === 0 && <EmptyState title="점수 이력이 없습니다" copy="아직 등록된 생활점수가 없습니다." />}</div>}</section><section className="card card-pad"><div className="section-row" style={{ margin: 0 }}><div><h2 className="section-title">기숙사 처분</h2><p className="section-copy">사생회가 기록한 처분입니다.</p></div></div>{student.punishments.length === 0 ? <EmptyState title="처분 이력 없음" copy="등록된 기숙사 처분이 없습니다." /> : <div className="activity-list">{student.punishments.map((punishment) => <div className="activity-row" key={punishment.id} data-testid={`row-punishment-${punishment.id}`}><div className="activity-mark"><BedDouble size={15} /></div><div><div className="activity-label">{punishment.types.join(' · ')}</div><div className="record-meta">{dateLabel(punishment.startDate)} — {dateLabel(punishment.endDate)}</div></div><button className={`pill ${punishment.violated ? 'pill-negative' : 'pill-neutral'}`} onClick={() => toggleViolated(punishment)} data-testid={`button-toggle-violation-${punishment.id}`}>{punishment.violated ? '위반 기록됨' : '위반 없음'}</button></div>)}</div>}</section></div></div>;
}

function PointEntryPage({ type }: { type: 'NEGATIVE' | 'POSITIVE' }) {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const { admin } = useAuth();
  const students = useListStudents();
  const items = useListPointItems({ type, includeInactive: false });
  const create = useCreatePointRecord();
  const searchRef = useRef<HTMLInputElement>(null);

  const [studentId, setStudentId] = useState('');
  const [itemId, setItemId] = useState('');
  const [points, setPoints] = useState('');
  const [recordedAt, setRecordedAt] = useState(today());
  const [reflectionSubmitted, setReflectionSubmitted] = useState(false);
  const [search, setSearch] = useState('');
  const [continuousMode, setContinuousMode] = useState(type === 'NEGATIVE');
  const [recentEntries, setRecentEntries] = useState<Array<{ student: string; item: string; points: number }>>([]);

  const negative = type === 'NEGATIVE';
  const needle = search.trim().toLowerCase();
  const filteredStudents = (students.data ?? []).filter((student) =>
    !needle
    || student.name.toLowerCase().includes(needle)
    || (student.studentNo ?? '').toLowerCase().includes(needle)
    || (student.homeroom ?? '').toLowerCase().includes(needle)
  ).slice(0, 40);

  const selectedStudent = (students.data ?? []).find((student) => String(student.id) === studentId);
  const selectedItem = (items.data ?? []).find((item) => String(item.id) === itemId);

  const resetForNextStudent = () => {
    setStudentId('');
    setSearch('');
    setReflectionSubmitted(false);
    window.setTimeout(() => searchRef.current?.focus(), 0);
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!studentId || !points || !admin) return;

    const itemName = selectedItem?.name ?? '수기 입력';
    const pointValue = Number(points);
    const studentName = selectedStudent?.name ?? '학생';

    create.mutate({
      data: {
        studentId: Number(studentId),
        type,
        item: itemName,
        points: pointValue,
        recordedAt,
        enteredByName: admin.displayName,
        reflectionSubmitted: negative ? reflectionSubmitted : null,
      },
    }, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: getListStudentsQueryKey() });
        queryClient.invalidateQueries({ queryKey: getGetDashboardQueryKey() });
        queryClient.invalidateQueries({ queryKey: getListReflectionsQueryKey() });

        setRecentEntries((current) => [
          { student: studentName, item: itemName, points: pointValue },
          ...current,
        ].slice(0, 6));

        resetForNextStudent();

        if (!continuousMode) {
          setItemId('');
          setPoints('');
        }

        notify(studentName + ' · ' + (negative ? '벌점' : '상점') + ' ' + pointValue + '점 기록 완료');
      },
      onError: (error) => notify(errText(error), 'error'),
    });
  };

  const handleSearchKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter' && !studentId && filteredStudents.length === 1) {
      event.preventDefault();
      setStudentId(String(filteredStudents[0].id));
    }
  };

  if (students.isLoading || items.isLoading) return <LoadingState />;
  if (students.isError || items.isError) return <ErrorState error={students.error ?? items.error} retry={() => { students.refetch(); items.refetch(); }} />;

  return <div>
    <PageHeader
      eyebrow={negative ? '생활지도 기록' : '긍정 기록'}
      title={negative ? '벌점 입력' : '상점 입력'}
      copy={negative ? '아침 종이 시트도 빠르게 옮길 수 있도록 연속 입력에 최적화했습니다.' : '학생의 좋은 행동을 놓치지 않고 상점으로 남깁니다.'}
    />

    <div className="detail-grid" style={{ marginTop: 30 }}>
      <form className="card card-pad" onSubmit={submit}>
        <div className="section-row" style={{ margin: 0 }}>
          <div>
            <h2 className="section-title">새 기록</h2>
            <p className="section-copy">{continuousMode ? '저장 후 학생만 비우고 같은 조건으로 계속 입력합니다.' : '한 건씩 입력합니다.'}</p>
          </div>
          <span className={'pill ' + (negative ? 'pill-negative' : 'pill-positive')}>{negative ? '벌점' : '상점'}</span>
        </div>

        <div className="form-grid" style={{ marginTop: 25 }}>
          <div className="field full">
            <label htmlFor="entry-student">학생 검색</label>
            <div className="search-box">
              <Search size={15} />
              <input
                ref={searchRef}
                id="entry-student"
                className="input"
                value={search}
                onChange={(event) => {
                  setSearch(event.target.value);
                  if (studentId) setStudentId('');
                }}
                onKeyDown={handleSearchKeyDown}
                placeholder="이름 · 학번 · 반 검색"
                autoComplete="off"
                data-testid="input-point-student-search"
              />
            </div>
            <select
              className="select"
              value={studentId}
              onChange={(event) => setStudentId(event.target.value)}
              required
              data-testid="select-point-student"
            >
              <option value="">학생 선택</option>
              {filteredStudents.map((student) => <option key={student.id} value={student.id}>
                {student.name + ' · ' + (student.homeroom ?? (student.grade + '학년')) + (student.studentNo ? ' · ' + student.studentNo : '')}
              </option>)}
            </select>
            {needle && filteredStudents.length === 1 && !studentId && <div className="record-meta">Enter를 누르면 {filteredStudents[0].name} 학생을 바로 선택합니다.</div>}
          </div>

          <div className="field full">
            <label htmlFor="entry-item">점수 항목</label>
            <select
              id="entry-item"
              className="select"
              value={itemId}
              onChange={(event) => {
                setItemId(event.target.value);
                const selected = (items.data ?? []).find((item) => String(item.id) === event.target.value);
                if (selected?.fixedPoints != null) setPoints(String(selected.fixedPoints));
              }}
              data-testid="select-point-item"
            >
              <option value="">항목 선택 또는 수기 입력</option>
              {(items.data ?? []).map((item) => <option key={item.id} value={item.id}>
                {item.name + (item.fixedPoints != null ? ' · ' + item.fixedPoints + '점' : '')}
              </option>)}
            </select>
          </div>

          <div className="field">
            <label htmlFor="entry-points">점수</label>
            <input id="entry-points" className="input" type="number" min="1" max="100" required value={points} onChange={(event) => setPoints(event.target.value)} data-testid="input-point-value" />
          </div>

          <div className="field">
            <label htmlFor="entry-date">기록일</label>
            <input id="entry-date" className="input" type="date" required value={recordedAt} onChange={(event) => setRecordedAt(event.target.value)} data-testid="input-point-date" />
          </div>

          <div className="side-note field full">
            기록자 <strong>{admin?.displayName ?? '로그인 관리자'}</strong> · 실제 작성자 ID는 로그인 계정으로 자동 저장됩니다.
          </div>

          <label className="check-row field full">
            <input type="checkbox" checked={continuousMode} onChange={(event) => setContinuousMode(event.target.checked)} data-testid="checkbox-continuous-entry" />
            연속 입력 모드 — 저장 후 항목·점수·날짜를 유지
          </label>

          {negative && <label className="check-row field full">
            <input type="checkbox" checked={reflectionSubmitted} onChange={(event) => setReflectionSubmitted(event.target.checked)} data-testid="checkbox-reflection-submitted" />
            같은 날 반성문 제출 완료
          </label>}
        </div>

        <div className="modal-actions">
          <button className="btn btn-primary" disabled={create.isPending || !studentId || !points} data-testid="button-submit-point">
            {create.isPending ? '저장 중' : (negative ? '벌점' : '상점') + ' 기록 + 다음 학생'}
          </button>
        </div>
      </form>

      <div>
        <div className="card card-pad">
          <div className="eyebrow">빠른 입력</div>
          <h2 className="section-title" style={{ marginTop: 10 }}>{negative ? '아침 종이 시트 처리' : '반복 상점 처리'}</h2>
          <p className="subheading" style={{ marginTop: 12 }}>
            같은 사유가 반복되면 항목과 점수는 그대로 두고 학생 이름만 검색해서 연속 저장하세요.
          </p>
          <div className="side-note" style={{ marginTop: 24 }}>
            검색 결과가 한 명뿐이면 Enter로 바로 선택할 수 있습니다. 저장 후에는 학생 검색창으로 포커스가 돌아옵니다.
          </div>
        </div>

        {recentEntries.length > 0 && <div className="card card-pad" style={{ marginTop: 18 }}>
          <div className="eyebrow">이번 입력 세션</div>
          <h2 className="section-title" style={{ marginTop: 10 }}>최근 저장</h2>
          <div className="activity-list" style={{ marginTop: 16 }}>
            {recentEntries.map((entry, index) => <div className="activity-row" key={index}>
              <div className="activity-mark"><Check size={15} /></div>
              <div>
                <div className="activity-label">{entry.student}</div>
                <div className="record-meta">{entry.item + ' · ' + (negative ? '-' : '+') + entry.points + '점'}</div>
              </div>
            </div>)}
          </div>
        </div>}
      </div>
    </div>
  </div>;
}

function ReflectionsPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const { admin } = useAuth();
  const [filter, setFilter] = useState<'ALL' | 'SUBMITTED' | 'MISSING' | 'DOUBLE'>('ALL');
  const [scopeFilter, setScopeFilter] = useState<DisciplineScope>(admin?.disciplineScope ?? 'ALL');
  const reflections = useListReflections();
  const update = useUpdateReflection();
  const extend = useExtendReflectionTo21();

  if (reflections.isLoading) return <LoadingState />;
  if (reflections.isError) return <ErrorState error={reflections.error} retry={() => reflections.refetch()} />;

  const filterLabels = [['ALL', '전체'], ['SUBMITTED', '제출 완료'], ['MISSING', '미제출'], ['DOUBLE', '2배 제출 대상']] as const;
  const scopeLabels: Array<[DisciplineScope, string]> = [
    ['ALL', '전체 학년'],
    ['ELEMENTARY', '초등 G1–6'],
    ['MIDDLE', '중등 G7–9'],
    ['HIGH', '고등 G10–12'],
  ];
  const allowedScopeLabels = admin?.disciplineScope === 'ALL'
    ? scopeLabels
    : scopeLabels.filter(([value]) => value === admin?.disciplineScope);

  const rows = (reflections.data ?? []).filter((reflection) =>
    (filter === 'ALL' || reflection.status === filter)
    && (scopeFilter === 'ALL' || reflection.assignedScope === scopeFilter)
  );

  return <div>
    <PageHeader
      eyebrow="반성문 관리"
      title="반성문 현황"
      copy="초등은 익일 등교, 중고등은 기본 17시·필요 시 21시 연장 기준으로 담당 범위별 제출 상태를 확인합니다."
    />

    <div className="card card-pad" style={{ marginTop: 30 }}>
      <div className="section-row" style={{ marginTop: 0 }}>
        <div>
          <div className="eyebrow">담당 범위</div>
          <div className="tab-row" style={{ marginTop: 10 }}>
            {allowedScopeLabels.map(([value, label]) => <button
              key={value}
              className={'tab ' + (scopeFilter === value ? 'active' : '')}
              onClick={() => setScopeFilter(value)}
              data-testid={'button-reflection-scope-' + value.toLowerCase()}
            >{label}</button>)}
          </div>
        </div>
        {admin?.isLead && <span className="pill pill-positive">선도부장 · 전체 조회</span>}
      </div>

      <div className="tab-row" style={{ marginTop: 18 }}>
        {filterLabels.map(([value, label]) => <button
          key={value}
          className={'tab ' + (filter === value ? 'active' : '')}
          onClick={() => setFilter(value)}
          data-testid={'button-reflection-filter-' + value.toLowerCase()}
        >{label}</button>)}
      </div>

      {rows.length === 0 ? <EmptyState title="해당 반성문이 없습니다" copy="선택한 담당 범위와 상태에 맞는 반성문이 없습니다." /> : <div className="table-wrap">
        <table className="data-table">
          <thead><tr><th>학생</th><th>담당</th><th>벌점 항목</th><th>벌점</th><th>입력일</th><th>제출기한</th><th>상태</th><th>조치</th></tr></thead>
          <tbody>{rows.map((reflection) => <tr key={reflection.id} data-testid={'row-reflection-' + reflection.id}>
            <td><Link className="table-link" href={'/students/' + reflection.studentId} data-testid={'link-reflection-student-' + reflection.id}>{reflection.studentName}</Link> <span className="muted">{reflection.grade}학년</span></td>
            <td className="muted">{reflection.assignedScope === 'ELEMENTARY' ? '초등' : reflection.assignedScope === 'MIDDLE' ? '중등' : '고등'}</td>
            <td>{reflection.item}</td>
            <td className="weight-number danger-text">{reflection.points}</td>
            <td className="muted">{dateLabel(reflection.recordedAt)}</td>
            <td className="muted"><div>{dateTimeLabel(reflection.dueAt)}</div>{reflection.deadlineChangeReason && <div className="record-meta">연장 사유: {reflection.deadlineChangeReason}</div>}</td>
            <td><span className={'pill ' + (reflection.status === 'SUBMITTED' ? 'pill-positive' : reflection.status === 'DOUBLE' ? 'pill-negative' : 'pill-warning')}>{reflection.status === 'SUBMITTED' ? '제출 완료' : reflection.status === 'DOUBLE' ? '2배 대상' : '미제출'}</span>{reflection.submittedAt && <div className="record-meta">제출 {dateTimeLabel(reflection.submittedAt)}</div>}</td>
            <td><div className="toolbar-right">
              <button className="btn btn-outline" onClick={() => {
                update.mutate({ id: reflection.id, data: { submitted: !reflection.submitted } }, {
                  onSuccess: () => {
                    queryClient.invalidateQueries({ queryKey: getListReflectionsQueryKey() });
                    notify('반성문 상태를 변경했습니다.');
                  },
                  onError: (error) => notify(errText(error), 'error'),
                });
              }} data-testid={'button-toggle-reflection-' + reflection.id}>{reflection.submitted ? '미제출로' : '제출 완료'}</button>
              {!reflection.submitted && reflection.grade >= 7 && <button className="btn btn-outline" onClick={() => {
                const reason = window.prompt('21시까지 연장하는 사유를 입력하세요.', '오후 벌점 발생');
                if (reason == null) return;
                extend.mutate({ id: reflection.id, reason }, {
                  onSuccess: () => {
                    queryClient.invalidateQueries({ queryKey: getListReflectionsQueryKey() });
                    notify('반성문 마감을 21시로 연장했습니다.');
                  },
                  onError: (error) => notify(errText(error), 'error'),
                });
              }} data-testid={'button-extend-reflection-' + reflection.id}>21시 연장</button>}
            </div></td>
          </tr>)}</tbody>
        </table>
      </div>}
    </div>
  </div>;
}


function ReportsPage() {
  const { admin } = useAuth();
  const [mode, setMode] = useState<'DAILY' | 'WEEKLY'>('DAILY');
  const [noticeDate, setNoticeDate] = useState(today());
  const [classFilter, setClassFilter] = useState('ALL');

  const daily = useDailyDisciplineNotice(noticeDate);
  const weekly = useWeeklyDisciplineReport();

  const loading = mode === 'DAILY' ? daily.isLoading : weekly.isLoading;
  const error = mode === 'DAILY' ? daily.error : weekly.error;
  const isError = mode === 'DAILY' ? daily.isError : weekly.isError;

  const scopeMatchesGrade = (grade: number) =>
    admin?.disciplineScope == null
    || admin.disciplineScope === 'ALL'
    || (admin.disciplineScope === 'ELEMENTARY' && grade >= 1 && grade <= 6)
    || (admin.disciplineScope === 'MIDDLE' && grade >= 7 && grade <= 9)
    || (admin.disciplineScope === 'HIGH' && grade >= 10 && grade <= 12);

  const dailyRows = (daily.data ?? []).filter((row) => scopeMatchesGrade(row.grade));
  const weeklyRows = admin?.isLead ? (weekly.data ?? []) : [];

  const classOptions = useMemo(() => {
    const labels = new Set<string>();
    const source = mode === 'DAILY' ? dailyRows : weeklyRows;
    source.forEach((row) => labels.add(row.homeroom ?? ('G' + row.grade)));
    return Array.from(labels).sort((a, b) => a.localeCompare(b, 'ko', { numeric: true }));
  }, [mode, dailyRows, weeklyRows]);

  const filteredDaily = useMemo(() => dailyRows.filter((row) => {
    const label = row.homeroom ?? ('G' + row.grade);
    return classFilter === 'ALL' || classFilter === label;
  }), [dailyRows, classFilter]);

  const weeklyTargets = useMemo(() => weeklyRows.filter((row) => {
    const label = row.homeroom ?? ('G' + row.grade);
    const classMatches = classFilter === 'ALL' || classFilter === label;
    return classMatches && (row.physicalTrainingRequired || row.committeeRequired);
  }), [weeklyRows, classFilter]);

  const dailyGroups = useMemo(() => {
    const grouped = new Map<string, DailyDisciplineNotice[]>();
    filteredDaily.forEach((row) => {
      const key = row.homeroom ?? ('G' + row.grade);
      const list = grouped.get(key) ?? [];
      list.push(row);
      grouped.set(key, list);
    });
    return Array.from(grouped.entries()).sort(([a], [b]) => a.localeCompare(b, 'ko', { numeric: true }));
  }, [filteredDaily]);

  const weeklyGroups = useMemo(() => {
    const grouped = new Map<string, WeeklyDisciplineReport[]>();
    weeklyTargets.forEach((row) => {
      const key = row.homeroom ?? ('G' + row.grade);
      const list = grouped.get(key) ?? [];
      list.push(row);
      grouped.set(key, list);
    });
    return Array.from(grouped.entries()).sort(([a], [b]) => a.localeCompare(b, 'ko', { numeric: true }));
  }, [weeklyTargets]);

  const resetClassIfMissing = (nextMode: 'DAILY' | 'WEEKLY') => {
    setMode(nextMode);
    setClassFilter('ALL');
  };

  if (loading) return <LoadingState />;
  if (isError) return <ErrorState error={error} retry={() => { daily.refetch(); weekly.refetch(); }} />;

  const weekStart = weeklyRows[0]?.weekStart ?? null;
  const settlementLabel = weeklyRows.find((row) => row.settlementPeriodLabel)?.settlementPeriodLabel ?? '열린 정산기간 없음';

  return <div className="report-page">
    <div className="screen-only">
      <PageHeader
        eyebrow="통지 · 보고"
        title="공지·출력"
        copy="반별 일일 벌점 공지와 주말 체력훈련·정산 대상 명단을 같은 기준으로 출력합니다."
        action={<button className="btn btn-primary" onClick={() => window.print()} data-testid="button-print-report"><Printer size={15} /> 인쇄</button>}
      />

      <div className="card card-pad report-controls" style={{ marginTop: 28 }}>
        <div className="tab-row">
          <button className={'tab ' + (mode === 'DAILY' ? 'active' : '')} onClick={() => resetClassIfMissing('DAILY')} data-testid="button-report-daily">일일 반별 공지</button>
          {admin?.isLead && <button className={'tab ' + (mode === 'WEEKLY' ? 'active' : '')} onClick={() => resetClassIfMissing('WEEKLY')} data-testid="button-report-weekly">주간 정산 보고</button>}
        </div>

        <div className="filter-bar" style={{ marginTop: 18 }}>
          {mode === 'DAILY' && <div className="field">
            <label htmlFor="notice-date">공지 날짜</label>
            <input id="notice-date" className="input" type="date" value={noticeDate} onChange={(event) => setNoticeDate(event.target.value)} data-testid="input-notice-date" />
          </div>}
          <div className="field">
            <label htmlFor="report-class">학년 / 반</label>
            <select id="report-class" className="select" value={classFilter} onChange={(event) => setClassFilter(event.target.value)} data-testid="select-report-class">
              <option value="ALL">전체</option>
              {classOptions.map((label) => <option key={label} value={label}>{label}</option>)}
            </select>
          </div>
        </div>
      </div>
    </div>

    <section className="print-sheet" data-testid="print-sheet">
      <header className="print-header">
        <div>
          <div className="print-kicker">DISCIPLE INTERNATIONAL CHRISTIAN SCHOOL</div>
          <h1>{mode === 'DAILY' ? '생활지도 일일 공지' : '주간 생활지도 정산 보고'}</h1>
        </div>
        <div className="print-meta">
          {mode === 'DAILY'
            ? <><strong>{noticeDate}</strong><span>{classFilter === 'ALL' ? '전체 반' : classFilter}</span></>
            : <><strong>{weekStart ? dateLabel(weekStart) + ' 시작 주간' : '이번 주'}</strong><span>{settlementLabel}</span></>}
        </div>
      </header>

      {mode === 'DAILY' ? <>
        <div className="print-summary">
          <span>벌점 기록 <strong>{filteredDaily.length}</strong>건</span>
          <span>반성문 미제출 <strong>{filteredDaily.filter((row) => row.reflectionStatus === 'MISSING').length}</strong>건</span>
          <span>2배 제출 대상 <strong>{filteredDaily.filter((row) => row.reflectionStatus === 'DOUBLE').length}</strong>건</span>
        </div>

        {dailyGroups.length === 0 ? <div className="print-empty">선택한 날짜/반의 벌점 공지 대상이 없습니다.</div> :
          dailyGroups.map(([className, rows]) => {
            return <section className="print-group" key={className}>
              <h2>{className}</h2>
              <table className="print-table">
                <thead><tr><th style={{ width: '18%' }}>학생</th><th>벌점 사유</th><th style={{ width: '10%' }}>벌점</th><th style={{ width: '24%' }}>반성문</th></tr></thead>
                <tbody>{rows.map((row) => <tr key={row.pointRecordId}>
                  <td><strong>{row.studentName}</strong></td>
                  <td>{row.item}</td>
                  <td>{row.points}</td>
                  <td>
                    {row.reflectionStatus === 'SUBMITTED' ? '제출 완료'
                      : row.reflectionStatus === 'DOUBLE' ? '2배 제출 대상'
                      : row.reflectionStatus === 'MISSING' ? '미제출'
                      : '—'}
                    {row.reflectionDueAt && row.reflectionStatus !== 'SUBMITTED' && <div className="print-sub">마감 {dateTimeLabel(row.reflectionDueAt)}</div>}
                  </td>
                </tr>)}</tbody>
              </table>
            </section>;
          })}
      </> : <>
        <div className="print-summary">
          <span>체력훈련 대상 <strong>{weeklyTargets.filter((row) => row.physicalTrainingRequired).length}</strong>명</span>
          <span>징계위원회 대상 <strong>{weeklyTargets.filter((row) => row.committeeRequired).length}</strong>명</span>
        </div>

        {weeklyGroups.length === 0 ? <div className="print-empty">현재 주간 정산 대상자가 없습니다.</div> :
          weeklyGroups.map(([className, rows]) => {
            return <section className="print-group" key={className}>
              <h2>{className}</h2>
              <table className="print-table">
                <thead><tr><th>학생</th><th>벌점 횟수</th><th>주간 상점</th><th>주간 벌점</th><th>주간 NET</th><th>정산 NET</th><th>판정</th></tr></thead>
                <tbody>{rows.map((row) => <tr key={row.studentId}>
                  <td><strong>{row.studentName}</strong></td>
                  <td>{row.penaltyIncidentCount}</td>
                  <td>+{row.weeklyPositivePoints}</td>
                  <td>{row.weeklyPenaltyPoints}</td>
                  <td><strong>{row.weeklyNetPenaltyPoints}</strong></td>
                  <td>{row.settlementNetPenaltyPoints}</td>
                  <td>
                    {row.physicalTrainingRequired && <div>체력훈련</div>}
                    {row.committeeRequired && <div>징계위원회</div>}
                  </td>
                </tr>)}</tbody>
              </table>
            </section>;
          })}
      </>}

      <footer className="print-footer">
        <span>다니엘의 저울 · DICS 생활지도</span>
        <span>출력 시각 {new Intl.DateTimeFormat('ko-KR', { dateStyle: 'short', timeStyle: 'short', timeZone: 'Asia/Seoul' }).format(new Date())}</span>
      </footer>
    </section>
  </div>;
}

function SettlementPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const current = useCurrentSettlement();
  const start = useStartSettlementPeriod();
  const close = useCloseSettlementPeriod();

  const [startsOn, setStartsOn] = useState(today());
  const [label, setLabel] = useState('');
  const [endDate, setEndDate] = useState(today());
  const [openNext, setOpenNext] = useState(true);
  const [nextLabel, setNextLabel] = useState('');

  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: getCurrentSettlementQueryKey() });
    queryClient.invalidateQueries({ queryKey: getGetDashboardQueryKey() });
    queryClient.invalidateQueries({ queryKey: getListStudentsQueryKey() });
  };

  if (current.isLoading) return <LoadingState />;
  if (current.isError) return <ErrorState error={current.error} retry={() => current.refetch()} />;

  const period = current.data;

  const submitStart = (event: FormEvent) => {
    event.preventDefault();
    const cleanLabel = label.trim() || (startsOn + ' 시작 정산');
    start.mutate(
      { startsOn, label: cleanLabel },
      {
        onSuccess: () => {
          refresh();
          setLabel('');
          notify('정산기간을 시작했습니다.');
        },
        onError: (error) => notify(errText(error), 'error'),
      },
    );
  };

  const submitClose = (event: FormEvent) => {
    event.preventDefault();
    if (!period) return;

    const message = openNext
      ? endDate + '까지 현재 정산을 종료하고 다음날부터 새 정산기간을 시작할까요?'
      : endDate + '까지 현재 정산만 종료할까요? 다음 기간은 자동 시작되지 않습니다.';

    if (!window.confirm(message)) return;

    close.mutate(
      {
        periodId: period.id,
        endDate,
        openNext,
        nextLabel: nextLabel.trim() || null,
      },
      {
        onSuccess: () => {
          refresh();
          setNextLabel('');
          notify(openNext ? '정산을 종료하고 다음 기간을 시작했습니다.' : '정산기간을 종료했습니다.');
        },
        onError: (error) => notify(errText(error), 'error'),
      },
    );
  };

  return <div>
    <PageHeader
      eyebrow="귀가 사이클"
      title="정산 관리"
      copy="달력 월이 아니라 실제 귀가 주기에 맞춰 누적 기간을 직접 시작하고 종료합니다."
    />

    {!period ? <div className="detail-grid" style={{ marginTop: 30 }}>
      <form className="card card-pad" onSubmit={submitStart}>
        <div className="eyebrow">현재 상태</div>
        <h2 className="section-title" style={{ marginTop: 10 }}>열린 정산기간 없음</h2>
        <p className="section-copy">첫 정산 시작일을 지정하면 그 날짜부터 상점·벌점 NET이 누적됩니다.</p>

        <div className="form-grid" style={{ marginTop: 24 }}>
          <div className="field">
            <label htmlFor="settlement-start">시작일</label>
            <input
              id="settlement-start"
              className="input"
              type="date"
              required
              value={startsOn}
              onChange={(event) => setStartsOn(event.target.value)}
              data-testid="input-settlement-start"
            />
          </div>
          <div className="field">
            <label htmlFor="settlement-label">기간 이름</label>
            <input
              id="settlement-label"
              className="input"
              value={label}
              onChange={(event) => setLabel(event.target.value)}
              placeholder="예: 9월 2차 귀가 전"
              data-testid="input-settlement-label"
            />
          </div>
        </div>

        <div className="modal-actions">
          <button className="btn btn-primary" disabled={start.isPending} data-testid="button-start-settlement">
            {start.isPending ? '시작 중' : '정산 시작'}
          </button>
        </div>
      </form>

      <section className="card card-pad">
        <div className="eyebrow">판정 기준</div>
        <h2 className="section-title" style={{ marginTop: 10 }}>관리자가 종료할 때까지 누적</h2>
        <div className="activity-list" style={{ marginTop: 20 }}>
          <div className="activity-row"><div className="activity-mark"><ShieldAlert size={15} /></div><div><div className="activity-label">주간 체력훈련</div><div className="record-meta">벌점 발생 3회 이상 또는 주간 NET 8점 이상</div></div></div>
          <div className="activity-row"><div className="activity-mark"><AlertTriangle size={15} /></div><div><div className="activity-label">징계위원회</div><div className="record-meta">정산기간 내 체력훈련 판정 3주 이상 또는 NET 20점 이상</div></div></div>
        </div>
      </section>
    </div> : <div className="detail-grid" style={{ marginTop: 30 }}>
      <section className="card card-pad">
        <div className="eyebrow">진행 중</div>
        <h2 className="section-title" style={{ marginTop: 10 }}>{period.label}</h2>
        <p className="subheading" style={{ marginTop: 10 }}>{dateLabel(period.startsOn)}부터 현재까지 누적 중</p>

        <div className="side-note" style={{ marginTop: 22 }}>
          이 기간을 종료하지 않으면 다음 주 점수도 그대로 같은 정산기간에 누적됩니다.
        </div>
      </section>

      <form className="card card-pad" onSubmit={submitClose}>
        <div className="eyebrow">정산 종료</div>
        <h2 className="section-title" style={{ marginTop: 10 }}>귀가 일정에 맞춰 종료</h2>

        <div className="form-grid" style={{ marginTop: 24 }}>
          <div className="field">
            <label htmlFor="settlement-end">종료일</label>
            <input
              id="settlement-end"
              className="input"
              type="date"
              min={period.startsOn}
              required
              value={endDate}
              onChange={(event) => setEndDate(event.target.value)}
              data-testid="input-settlement-end"
            />
          </div>

          <label className="check-row field full">
            <input
              type="checkbox"
              checked={openNext}
              onChange={(event) => setOpenNext(event.target.checked)}
              data-testid="checkbox-open-next-settlement"
            />
            종료 다음날부터 새 정산기간 자동 시작
          </label>

          {openNext && <div className="field full">
            <label htmlFor="next-settlement-label">다음 기간 이름 <span className="muted">선택</span></label>
            <input
              id="next-settlement-label"
              className="input"
              value={nextLabel}
              onChange={(event) => setNextLabel(event.target.value)}
              placeholder="비우면 시작일 기준 자동 생성"
              data-testid="input-next-settlement-label"
            />
          </div>}
        </div>

        <div className="modal-actions">
          <button className="btn btn-primary" disabled={close.isPending} data-testid="button-close-settlement">
            {close.isPending ? '처리 중' : '현재 정산 종료'}
          </button>
        </div>
      </form>
    </div>}
  </div>;
}

function PunishmentsPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const { admin } = useAuth();
  const students = useListStudents();
  const punishments = useListPunishments();
  const create = useCreatePunishment();
  const setViolation = useSetPunishmentViolation();
  const [studentId, setStudentId] = useState('');
  const [types, setTypes] = useState<string[]>([]);
  const [startDate, setStartDate] = useState(today());
  const [endDate, setEndDate] = useState(today());
  const toggleType = (value: string) => setTypes((current) => current.includes(value) ? current.filter((item) => item !== value) : current.length < 2 ? [...current, value] : current);
  const submit = (event: FormEvent) => { event.preventDefault(); if (!admin) return; create.mutate({ data: { studentId: Number(studentId), types, startDate, endDate, enteredByName: admin.displayName } }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: getListPunishmentsQueryKey() }); setStudentId(''); setTypes([]); notify('처분이 등록되었습니다.'); }, onError: (error) => notify(errText(error), 'error') }); };
  if (students.isLoading || punishments.isLoading) return <LoadingState />;
  if (students.isError || punishments.isError) return <ErrorState error={students.error ?? punishments.error} retry={() => { students.refetch(); punishments.refetch(); }} />;
  return <div><PageHeader eyebrow="사생회 운영" title="기숙사 처분" copy="수동 처분과 위반 여부를 같은 화면에서 기록합니다." /><div className="detail-grid" style={{ marginTop: 30 }}><form className="card card-pad" onSubmit={submit}><h2 className="section-title">처분 등록</h2><p className="section-copy">한 번에 최대 두 가지 처분을 선택할 수 있습니다.</p><div className="form-grid" style={{ marginTop: 24 }}><div className="field full"><label htmlFor="punishment-student">학생</label><select id="punishment-student" className="select" required value={studentId} onChange={(event) => setStudentId(event.target.value)} data-testid="select-punishment-student"><option value="">학생 선택</option>{(students.data ?? []).map((student) => <option key={student.id} value={student.id}>{student.name} · {student.grade}학년</option>)}</select></div><div className="field full"><label>처분 유형 <span className="muted">({types.length}/2)</span></label><div className="filter-bar">{PUNISHMENT_TYPES.map((value) => <button type="button" key={value} className={`btn ${types.includes(value) ? 'btn-primary' : 'btn-outline'}`} onClick={() => toggleType(value)} data-testid={`button-punishment-type-${value}`}>{types.includes(value) && <Check size={13} />}{value}</button>)}</div></div><div className="field"><label htmlFor="punishment-start">시작일</label><input id="punishment-start" className="input" type="date" required value={startDate} onChange={(event) => setStartDate(event.target.value)} data-testid="input-punishment-start" /></div><div className="field"><label htmlFor="punishment-end">종료일</label><input id="punishment-end" className="input" type="date" required value={endDate} onChange={(event) => setEndDate(event.target.value)} data-testid="input-punishment-end" /></div><div className="side-note field full">기록자 <strong>{admin?.displayName ?? '로그인 관리자'}</strong> · 인증된 계정으로 자동 기록됩니다.</div></div><div className="modal-actions"><button className="btn btn-primary" disabled={create.isPending || !studentId || types.length === 0} data-testid="button-submit-punishment">{create.isPending ? '저장 중' : '처분 등록'}</button></div></form><section className="card card-pad"><div className="section-row" style={{ margin: 0 }}><div><h2 className="section-title">최근 처분</h2><p className="section-copy">위반 시 규정에 따라 상태를 갱신합니다.</p></div></div>{punishments.data?.length === 0 ? <EmptyState title="처분 기록이 없습니다" copy="등록된 기숙사 처분이 없습니다." /> : <div className="activity-list">{punishments.data?.map((punishment) => <div className="activity-row" key={punishment.id} data-testid={`row-manual-punishment-${punishment.id}`}><div className="activity-mark"><BedDouble size={15} /></div><div style={{ minWidth: 0 }}><div className="activity-label">{punishment.studentName} · {punishment.types.join(' · ')}</div><div className="record-meta">{dateLabel(punishment.startDate)} — {dateLabel(punishment.endDate)} · {punishment.enteredByName}</div></div><button className={`pill ${punishment.violated ? 'pill-negative' : 'pill-neutral'}`} onClick={() => setViolation.mutate({ id: punishment.id, violated: !punishment.violated }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: getListPunishmentsQueryKey() }), onError: (error) => notify(errText(error), 'error') })} data-testid={`button-punishment-violation-${punishment.id}`}>{punishment.violated ? '위반 기록됨' : '위반 없음'}</button></div>)}</div>}</section></div></div>;
}

function PointItemsPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const items = useListPointItems({ includeInactive: true });
  const create = useCreatePointItem();
  const update = useUpdatePointItem();
  const remove = useDeletePointItem();
  const importer = useImportPointItems();
  const [editing, setEditing] = useState<PointItem | null | undefined>(undefined);
  const [importText, setImportText] = useState('');
  const [showImport, setShowImport] = useState(false);
  const [form, setForm] = useState({ name: '', type: 'NEGATIVE' as 'NEGATIVE' | 'POSITIVE', fixedPoints: '', isFixed: false, isActive: true });
  const list = useMemo(() => importText.split(/\r?\n/).map((line) => line.trim()).filter(Boolean).map((line) => { const [name, score] = line.split(',').map((cell) => cell.trim()); return { name, fixedPoints: score ? Number(score) : null }; }), [importText]);
  const refresh = () => queryClient.invalidateQueries({ queryKey: getListPointItemsQueryKey({ includeInactive: true }) });
  const openNew = () => { setForm({ name: '', type: 'NEGATIVE', fixedPoints: '', isFixed: false, isActive: true }); setEditing(null); };
  const openEdit = (item: PointItem) => { setForm({ name: item.name, type: item.type, fixedPoints: item.fixedPoints == null ? '' : String(item.fixedPoints), isFixed: item.isFixed, isActive: item.isActive }); setEditing(item); };
  const save = (event: FormEvent) => { event.preventDefault(); const data = { name: form.name.trim(), type: form.type, fixedPoints: form.fixedPoints ? Number(form.fixedPoints) : null, isFixed: form.isFixed, isActive: form.isActive }; const done = { onSuccess: () => { refresh(); setEditing(undefined); }, onError: (error: unknown) => notify(errText(error), 'error') }; if (editing) update.mutate({ id: editing.id, data }, done); else create.mutate({ data }, done); };
  const importItems = () => { importer.mutate({ data: { items: list } }, { onSuccess: () => { refresh(); setShowImport(false); setImportText(''); }, onError: (error) => notify(errText(error), 'error') }); };
  if (items.isLoading) return <LoadingState />;
  if (items.isError) return <ErrorState error={items.error} retry={() => items.refetch()} />;
  return <div><PageHeader eyebrow="기준 관리" title="점수 항목" copy="생활점수 입력에 쓰이는 항목과 고정 점수를 관리합니다." action={<><button className="btn btn-outline" onClick={() => setShowImport(true)} data-testid="button-open-import"><FileSpreadsheet size={15} /> 엑셀 가져오기</button><button className="btn btn-primary" onClick={openNew} data-testid="button-add-point-item"><Plus size={15} /> 항목 추가</button></>} /><div className="card card-pad" style={{ marginTop: 30 }}><div className="section-row" style={{ margin: 0 }}><div><h2 className="section-title">활성 및 비활성 항목</h2><p className="section-copy">비활성화된 항목은 입력 화면에서 선택되지 않습니다.</p></div></div><div className="table-wrap"><table className="data-table"><thead><tr><th>항목명</th><th>구분</th><th>고정 점수</th><th>상태</th><th>관리</th></tr></thead><tbody>{(items.data ?? []).map((item) => <tr key={item.id} data-testid={`row-point-item-${item.id}`}><td>{item.name}</td><td><span className={`pill ${item.type === 'NEGATIVE' ? 'pill-negative' : 'pill-positive'}`}>{item.type === 'NEGATIVE' ? '벌점' : '상점'}</span></td><td>{item.isFixed ? `${item.fixedPoints ?? 0}점` : '수기 입력'}</td><td><span className={`pill ${item.isActive ? 'pill-positive' : 'pill-neutral'}`}>{item.isActive ? '활성' : '비활성'}</span></td><td><div className="toolbar-right"><button className="btn btn-icon btn-outline" onClick={() => openEdit(item)} aria-label={`${item.name} 수정`} data-testid={`button-edit-point-item-${item.id}`}><Pencil size={14} /></button><button className="btn btn-icon btn-danger" onClick={() => { if (window.confirm(`${item.name} 항목을 비활성화할까요?`)) remove.mutate({ id: item.id }, { onSuccess: refresh, onError: (error) => notify(errText(error), 'error') }); }} aria-label={`${item.name} 삭제`} data-testid={`button-delete-point-item-${item.id}`}><Trash2 size={14} /></button></div></td></tr>)}</tbody></table></div>{items.data?.length === 0 && <EmptyState title="점수 항목이 없습니다" copy="항목을 추가하면 기록 입력 화면에서 선택할 수 있습니다." />}</div>{editing !== undefined && <div className="modal-backdrop"><form className="modal" onSubmit={save}><div className="modal-header"><div><div className="eyebrow">기준 항목</div><h2 className="modal-title">{editing ? '항목 수정' : '새 항목'}</h2></div><button type="button" className="btn btn-icon btn-outline" onClick={() => setEditing(undefined)} aria-label="닫기" data-testid="button-close-point-item"><X size={16} /></button></div><div className="form-grid"><div className="field full"><label htmlFor="item-name">항목명</label><input id="item-name" className="input" required maxLength={80} value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} data-testid="input-point-item-name" /></div><div className="field"><label htmlFor="item-type">구분</label><select id="item-type" className="select" value={form.type} onChange={(event) => setForm({ ...form, type: event.target.value as 'NEGATIVE' | 'POSITIVE' })} data-testid="select-point-item-type"><option value="NEGATIVE">벌점</option><option value="POSITIVE">상점</option></select></div><div className="field"><label htmlFor="item-score">고정 점수</label><input id="item-score" className="input" type="number" min="0" max="100" value={form.fixedPoints} onChange={(event) => setForm({ ...form, fixedPoints: event.target.value })} placeholder="비워두면 수기 입력" data-testid="input-point-item-score" /></div><label className="check-row field full"><input type="checkbox" checked={form.isFixed} onChange={(event) => setForm({ ...form, isFixed: event.target.checked })} data-testid="checkbox-point-item-fixed" /> 고정 점수 항목으로 사용</label><label className="check-row field full"><input type="checkbox" checked={form.isActive} onChange={(event) => setForm({ ...form, isActive: event.target.checked })} data-testid="checkbox-point-item-active" /> 입력 화면에 활성화</label></div><div className="modal-actions"><button type="button" className="btn btn-outline" onClick={() => setEditing(undefined)} data-testid="button-cancel-point-item">취소</button><button className="btn btn-primary" disabled={create.isPending || update.isPending} data-testid="button-submit-point-item">저장하기</button></div></form></div>}{showImport && <div className="modal-backdrop"><div className="modal modal-wide"><div className="modal-header"><div><div className="eyebrow">대량 등록</div><h2 className="modal-title">엑셀 미리보기</h2></div><button className="btn btn-icon btn-outline" onClick={() => setShowImport(false)} aria-label="닫기" data-testid="button-close-import"><X size={16} /></button></div><div className="csv-hint"><span>첫 번째 열은 항목명, 두 번째 열은 고정 점수입니다.</span><label className="btn btn-outline" htmlFor="csv-file"><FileSpreadsheet size={14} /> 파일 선택</label><input id="csv-file" type="file" accept=".csv,.txt" style={{ display: 'none' }} onChange={(event) => { const file = event.target.files?.[0]; if (file) file.text().then(setImportText); }} data-testid="input-import-file" /></div><textarea className="input" style={{ marginTop: 15, width: '100%', minHeight: 100, resize: 'vertical' }} placeholder={'생활 태도, 2\n기숙사 정리, 1'} value={importText} onChange={(event) => setImportText(event.target.value)} data-testid="textarea-import-data" /><div className="import-preview" style={{ marginTop: 15 }}><table className="data-table"><thead><tr><th>항목명</th><th>고정 점수</th><th>검증</th></tr></thead><tbody>{list.map((item, index) => <tr key={`${item.name}-${index}`}><td>{item.name || '이름 없음'}</td><td>{Number.isFinite(item.fixedPoints) ? item.fixedPoints : '수기 입력'}</td><td>{item.name && (!item.fixedPoints || (item.fixedPoints >= 0 && item.fixedPoints <= 100)) ? <span className="success-text">유효</span> : <span className="danger-text">확인 필요</span>}</td></tr>)}</tbody></table></div><div className="modal-actions"><button className="btn btn-outline" onClick={() => setShowImport(false)} data-testid="button-cancel-import">취소</button><button className="btn btn-primary" disabled={importer.isPending || list.length === 0} onClick={importItems} data-testid="button-submit-import">{importer.isPending ? '가져오는 중' : `${list.length}개 가져오기`}</button></div></div></div>}</div>;
}

function PublicHome() {
  // Internal operations tool: skip the former marketing-style landing page.
  return <LoginPage />;
}

function LoginPage() {
  const { session, loading } = useAuth();
  const [loginId, setLoginId] = useState('');
  const [password, setPassword] = useState('');
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  if (!loading && session) return <Redirect to="/dashboard" />;
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!loginId.trim() || !password) return;
    setPending(true);
    setError(null);
    // Login IDs map to synthetic emails; accounts are provisioned by the maintainer.
    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: `${loginId.trim()}@scale.dics.kr`,
      password,
    });
    if (signInError) {
      setError('아이디 또는 비밀번호를 확인해주세요.');
      setPending(false);
    }
    // On success the auth listener updates the session and the redirect above renders.
  };
  return <div className="landing" style={{ display: 'grid', placeItems: 'center', minHeight: '100dvh', padding: 20 }}><div style={{ width: '100%', maxWidth: 460 }}><div style={{ textAlign: 'center', marginBottom: 24 }}><Brand /><p className="subheading">관리자 계정으로 운영 콘솔에 들어갑니다.</p></div><form className="card card-pad" onSubmit={submit}><div className="eyebrow">관리자 로그인</div><h1 className="modal-title" style={{ marginTop: 8 }}>다니엘의 저울</h1><p className="section-copy" style={{ marginTop: 6 }}>승인된 운영 담당자만 로그인할 수 있습니다.</p><div className="form-grid" style={{ marginTop: 22 }}><div className="field full"><label htmlFor="login-id">아이디</label><input id="login-id" className="input" required autoComplete="username" value={loginId} onChange={(event) => setLoginId(event.target.value)} data-testid="input-login-id" /></div><div className="field full"><label htmlFor="login-password">비밀번호</label><input id="login-password" className="input" type="password" required autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} data-testid="input-login-password" /></div></div>{error && <p className="danger-text" style={{ fontSize: 12, marginTop: 14 }} role="alert" data-testid="text-login-error">{error}</p>}<div className="modal-actions"><button className="btn btn-primary" style={{ width: '100%' }} disabled={pending} data-testid="button-submit-login">{pending ? '로그인 중' : '로그인'}</button></div></form></div></div>;
}

function ProtectedRoutes() {
  const { session, admin, loading, signOut } = useAuth();
  if (loading) return <LoadingState />;
  if (!session) return <Redirect to="/sign-in" />;
  if (!admin) return <div className="app-loading"><div className="error-box"><AlertTriangle size={24} /><p>관리자 권한이 없는 계정입니다. 운영 담당자에게 문의해주세요.</p><button className="btn btn-outline" onClick={() => signOut()} data-testid="button-no-admin-sign-out"><LogOut size={14} /> 로그아웃</button></div></div>;
  return <AppShell role={admin.role}><Switch><Route path="/dashboard" component={DashboardPage} /><Route path="/students" component={() => <RoleGate role="SEONDO"><StudentsPage /></RoleGate>} /><Route path="/students/:id" component={StudentDetailPage} /><Route path="/points/negative" component={() => <RoleGate role="SEONDO"><PointEntryPage type="NEGATIVE" /></RoleGate>} /><Route path="/points/positive" component={() => <RoleGate role="SEONDO"><PointEntryPage type="POSITIVE" /></RoleGate>} /><Route path="/reflections" component={() => <RoleGate role="SEONDO"><ReflectionsPage /></RoleGate>} /><Route path="/reports" component={() => <RoleGate role="SEONDO"><ReportsPage /></RoleGate>} /><Route path="/settlement" component={() => <LeadGate><SettlementPage /></LeadGate>} /><Route path="/punishments" component={() => <RoleGate role="SASAENG"><PunishmentsPage /></RoleGate>} /><Route path="/point-items" component={() => <RoleGate role="SEONDO"><PointItemsPage /></RoleGate>} /><Route path="/"><Redirect to="/dashboard" /></Route><Route component={NotFoundInline} /></Switch></AppShell>;
}

function NotFoundInline() {
  return <div className="error-box"><CircleHelp size={28} /><h1 className="section-title">페이지를 찾을 수 없습니다</h1><Link href="/dashboard" className="btn btn-primary" data-testid="link-not-found-dashboard">대시보드로 돌아가기</Link></div>;
}

function Router() {
  return <Switch><Route path="/sign-in" component={LoginPage} /><Route path="/" component={PublicHome} /><Route component={ProtectedRoutes} /></Switch>;
}

function MissingEnvScreen() {
  return <div className="app-loading"><div className="error-box" style={{ maxWidth: 480 }}><AlertTriangle size={24} /><h1 className="section-title">환경 설정이 필요합니다</h1><p>Supabase 연결 정보(VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY)가 설정되지 않았습니다.<br />.env 파일을 확인한 뒤 다시 빌드해주세요.</p></div></div>;
}

function App() {
  if (!supabaseConfigured) return <MissingEnvScreen />;
  return <QueryClientProvider client={queryClient}><AuthProvider><WouterRouter base={basePath}><Router /></WouterRouter></AuthProvider></QueryClientProvider>;
}

export default App;
