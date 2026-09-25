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
  getAdminAccountsQueryKey,
  getGetDashboardQueryKey,
  getGetStudentQueryKey,
  getListPointItemsQueryKey,
  getListPointRecordsQueryKey,
  getListPunishmentsQueryKey,
  getListReflectionsQueryKey,
  getListStudentsQueryKey,
  getCurrentSettlementQueryKey,
  getCoreMigrationReadinessQueryKey,
  getDisciplineCoreFkReadinessQueryKey,
  getCoreStudentReadinessQueryKey,
  getCoreSetupStatusQueryKey,
  getDepartmentMeritStatusQueryKey,
  getDepartmentMeritAdminQueryKey,
  getDepartmentMembersQueryKey,
  getGrade9AssignmentsQueryKey,
  useDailyDisciplineNotice,
  useWeeklyDisciplineReport,
  useAdminAccounts,
  useAssignCurrentGrade9Section,
  useCoreMigrationReadiness,
  useDisciplineCoreFkReadiness,
  useCoreStudentReadiness,
  useCoreSetupStatus,
  useCreateDepartmentWithMeritRule,
  useCreatePointItem,
  useCreatePointRecord,
  useCreatePunishment,
  useCloseSettlementPeriod,
  useCurrentSettlement,
  useDeletePointItem,
  useDeletePointRecord,
  useDisciplineAuditLogs,
  useDepartmentCurrentMembers,
  useDepartmentMeritAdmin,
  useDepartmentMeritStatus,
  useEnsureWeeklyDepartmentMerits,
  useGetDashboard,
  useGetStudent,
  useExtendReflectionTo21,
  useImportPointItems,
  useInitializeCurrentAcademicTerm,
  useGrade9Assignments,
  useListPointItems,
  useListPointRecords,
  useListPunishments,
  useListReflections,
  useListStudents,
  useChangeAdminPassword,
  useProvisionAdminAccount,
  useSetDepartmentActive,
  useSetDepartmentStudentMembership,
  useSetPunishmentViolation,
  useStartSettlementPeriod,
  useUpdateAdminProfile,
  useUpdatePointItem,
  useUpdatePointRecord,
  useUpdateReflection,
  type AdminAccount,
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
function currentWeekMonday() {
  const value = new Date(today() + 'T12:00:00+09:00');
  const offset = (value.getUTCDay() + 6) % 7;
  value.setUTCDate(value.getUTCDate() - offset);
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(value);
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
    { href: '/audit', label: '감사 로그', icon: Database, roles: ['SEONDO'] as Role[], leadOnly: true },
    { href: '/admins', label: '관리자 계정', icon: ShieldAlert, roles: ['SEONDO'] as Role[], leadOnly: true },
    { href: '/core-setup', label: 'Core 설정', icon: Users, roles: ['SEONDO'] as Role[], leadOnly: true },
    { href: '/department-merits', label: '부서 상점', icon: ArrowUpRight, roles: ['SEONDO'] as Role[], leadOnly: true },
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
    if (!selectedStudent?.coreStudentId) {
      notify('이 학생의 Core Identity 연결을 확인해주세요.', 'error');
      return;
    }

    const itemName = selectedItem?.name ?? '수기 입력';
    const pointValue = Number(points);
    const studentName = selectedStudent.name;

    create.mutate({
      data: {
        coreStudentId: selectedStudent.coreStudentId,
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
          <button className="btn btn-primary" disabled={create.isPending || !studentId || !points || !selectedStudent?.coreStudentId} data-testid="button-submit-point">
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

function CoreSetupPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const status = useCoreSetupStatus();
  const readiness = useCoreMigrationReadiness();
  const disciplineFk = useDisciplineCoreFkReadiness();
  const studentReadiness = useCoreStudentReadiness();
  const grade9 = useGrade9Assignments();
  const initializeTerm = useInitializeCurrentAcademicTerm();
  const assignGrade9 = useAssignCurrentGrade9Section();

  const [termCode, setTermCode] = useState('2026-FALL');
  const [termName, setTermName] = useState('2026 Fall');
  const [startsOn, setStartsOn] = useState('');
  const [endsOn, setEndsOn] = useState('');
  const [search, setSearch] = useState('');

  const refreshCore = () => {
    queryClient.invalidateQueries({ queryKey: getCoreSetupStatusQueryKey() });
    queryClient.invalidateQueries({ queryKey: getCoreMigrationReadinessQueryKey() });
    queryClient.invalidateQueries({ queryKey: getDisciplineCoreFkReadinessQueryKey() });
    queryClient.invalidateQueries({ queryKey: getCoreStudentReadinessQueryKey() });
    queryClient.invalidateQueries({ queryKey: getGrade9AssignmentsQueryKey() });
    queryClient.invalidateQueries({ queryKey: getListStudentsQueryKey() });
    queryClient.invalidateQueries({ queryKey: getGetDashboardQueryKey() });
    queryClient.invalidateQueries({ queryKey: ['reports'] });
  };

  const submitTerm = (event: FormEvent) => {
    event.preventDefault();
    if (!termCode.trim() || !termName.trim() || !startsOn || !endsOn) return;

    const confirmed = window.confirm(
      '현재 학기를 생성하고 G9을 제외한 활성 학생을 현재 학년 기준으로 자동 배정할까요? G9은 A/B를 별도로 확인 배정합니다.'
    );
    if (!confirmed) return;

    initializeTerm.mutate({
      code: termCode.trim(),
      name: termName.trim(),
      startsOn,
      endsOn,
    }, {
      onSuccess: (result) => {
        refreshCore();
        notify(
          'Core 학기 생성 완료 · 반 ' + result.classes_created
          + '개 생성 · 학생 ' + result.enrollments_created
          + '명 자동 배정 · G9 ' + result.grade9_pending + '명 확인 필요'
        );
      },
      onError: (error) => notify(errText(error), 'error'),
    });
  };

  const assign = (studentId: number, section: 'A' | 'B', studentName: string) => {
    assignGrade9.mutate({ studentId, section }, {
      onSuccess: () => {
        refreshCore();
        notify(studentName + ' → G9-' + section + ' 배정 완료');
      },
      onError: (error) => notify(errText(error), 'error'),
    });
  };

  if (status.isLoading || readiness.isLoading || disciplineFk.isLoading || studentReadiness.isLoading || grade9.isLoading) return <LoadingState />;
  if (status.isError || readiness.isError || disciplineFk.isError || studentReadiness.isError || grade9.isError) {
    return <ErrorState
      error={status.error ?? readiness.error ?? disciplineFk.error ?? studentReadiness.error ?? grade9.error}
      retry={() => { status.refetch(); readiness.refetch(); disciplineFk.refetch(); studentReadiness.refetch(); grade9.refetch(); }}
    />;
  }

  const current = status.data;
  const core = readiness.data;
  const discipline = disciplineFk.data;
  const readinessRows = studentReadiness.data ?? [];
  const readyStudents = readinessRows.filter((row) => row.readinessStatus === 'READY').length;
  const partialStudents = readinessRows.filter((row) => row.readinessStatus === 'PARTIAL').length;
  const coreOnlyStudents = readinessRows.filter((row) => row.readinessStatus === 'CORE_ONLY').length;
  const pendingRows = readinessRows.filter((row) => row.readinessStatus !== 'READY');
  const needle = search.trim().toLowerCase();
  const grade9Rows = (grade9.data ?? []).filter((row) =>
    !needle || row.studentName.toLowerCase().includes(needle)
  );

  return <div>
    <PageHeader
      eyebrow="DICS Core provisioning"
      title="Core 설정"
      copy="학생 Identity·학번·Auth·학기/반 연결 상태를 수치로 추적하고, 검증된 정보만 단계적으로 보강합니다."
    />

    {core && <div className="metric-grid" style={{ marginTop: 28 }}>
      <div className="card metric-card">
        <div className="metric-label">Core Identity</div>
        <div className="metric-value">{core.danielBridgeCount}/{core.activeStudents}</div>
        <div className="muted" style={{ fontSize: 10 }}>Daniel 활성 학생 연결</div>
      </div>
      <div className="card metric-card">
        <div className="metric-label">학번 연결</div>
        <div className="metric-value">{core.studentNoAssigned}/{core.activeStudents}</div>
        <div className="muted" style={{ fontSize: 10 }}>SP / 학교 공통 student_no</div>
      </div>
      <div className="card metric-card">
        <div className="metric-label">Core Auth</div>
        <div className="metric-value">{core.authLinked}/{core.activeStudents}</div>
        <div className="muted" style={{ fontSize: 10 }}>DICS Core 프로젝트 로그인</div>
      </div>
      <div className="card metric-card">
        <div className="metric-label">외부 Auth</div>
        <div className="metric-value">{core.externalAuthLinked}/{core.activeStudents}</div>
        <div className="muted" style={{ fontSize: 10 }}>SP 등 legacy 프로젝트 identity</div>
      </div>
      <div className="card metric-card">
        <div className="metric-label">현재 학적</div>
        <div className="metric-value">{core.currentEnrollmentCount}/{core.activeStudents}</div>
        <div className="muted" style={{ fontSize: 10 }}>current-term enrollment</div>
      </div>
      <div className="card metric-card">
        <div className="metric-label">완전 READY</div>
        <div className={readyStudents === core.activeStudents ? 'metric-value success-text' : 'metric-value'}>{readyStudents}</div>
        <div className="muted" style={{ fontSize: 10 }}>학번 + Auth + 현재 학적</div>
      </div>
    </div>}

    <div className="side-note" style={{ marginTop: 18 }}>
      <strong>현재 전환 상태</strong>
      <span style={{ marginLeft: 10 }}>READY {readyStudents} · PARTIAL {partialStudents} · CORE ONLY {coreOnlyStudents}</span>
      <div style={{ marginTop: 5 }}>
        Core UUID는 학생 identity의 시작점이고, 학번·현재 학적·(Core Auth 또는 검증된 외부 Auth)가 연결되어야 migration 기준 READY가 됩니다. 외부 Auth는 Core Auth와 별도 namespace로 추적합니다.
      </div>
    </div>

    {discipline && <div className="card card-pad" style={{ marginTop: 18 }}>
      <div className="section-row" style={{ marginTop: 0 }}>
        <div>
          <div className="eyebrow">Discipline FK cut-over</div>
          <h2 className="section-title" style={{ marginTop: 8 }}>생활지도 Core UUID 전환 상태</h2>
          <p className="section-copy">legacy integer student_id는 호환용으로 남아 있고, 원본 기록은 canonical Core UUID를 병행 저장합니다.</p>
        </div>
        <span className={'pill ' + (
          discipline.pointRecordsMismatch === 0
          && discipline.punishmentsMismatch === 0
          && discipline.pointRecordsCoreLinked === discipline.pointRecordsTotal
          && discipline.punishmentsCoreLinked === discipline.punishmentsTotal
            ? 'pill-positive'
            : 'pill-warning'
        )}>
          {discipline.pointRecordsMismatch === 0 && discipline.punishmentsMismatch === 0 ? 'mismatch 0' : '확인 필요'}
        </span>
      </div>

      <div className="metric-grid" style={{ marginTop: 20 }}>
        <div className="card metric-card">
          <div className="metric-label">점수 기록 Core 연결</div>
          <div className="metric-value">{discipline.pointRecordsCoreLinked}/{discipline.pointRecordsTotal}</div>
          <div className="muted" style={{ fontSize: 10 }}>mismatch {discipline.pointRecordsMismatch}</div>
        </div>
        <div className="card metric-card">
          <div className="metric-label">처분 기록 Core 연결</div>
          <div className="metric-value">{discipline.punishmentsCoreLinked}/{discipline.punishmentsTotal}</div>
          <div className="muted" style={{ fontSize: 10 }}>mismatch {discipline.punishmentsMismatch}</div>
        </div>
      </div>

      <div className="side-note" style={{ marginTop: 16 }}>
        <strong>최종 integer FK 제거 gate</strong>
        <div style={{ marginTop: 5 }}>
          모든 기존 record Core 연결 100% · mismatch 0 · 신규 write Core UUID only · 주요 read/report 결과 동일 조건을 계속 만족할 때만 final cut-over를 진행합니다.
        </div>
      </div>
    </div>}

    {!current ? <div className="detail-grid" style={{ marginTop: 30 }}>
      <form className="card card-pad" onSubmit={submitTerm}>
        <div className="eyebrow">Phase 1</div>
        <h2 className="section-title" style={{ marginTop: 10 }}>현재 학기 생성</h2>
        <p className="section-copy">학기 날짜는 시스템이 추측하지 않습니다. 실제 학사일정을 확인한 뒤 입력하세요.</p>

        <div className="form-grid" style={{ marginTop: 24 }}>
          <div className="field">
            <label htmlFor="core-term-code">학기 코드</label>
            <input id="core-term-code" className="input" required value={termCode} onChange={(event) => setTermCode(event.target.value)} data-testid="input-core-term-code" />
          </div>
          <div className="field">
            <label htmlFor="core-term-name">학기 이름</label>
            <input id="core-term-name" className="input" required value={termName} onChange={(event) => setTermName(event.target.value)} data-testid="input-core-term-name" />
          </div>
          <div className="field">
            <label htmlFor="core-term-start">시작일</label>
            <input id="core-term-start" className="input" type="date" required value={startsOn} onChange={(event) => setStartsOn(event.target.value)} data-testid="input-core-term-start" />
          </div>
          <div className="field">
            <label htmlFor="core-term-end">종료일</label>
            <input id="core-term-end" className="input" type="date" required value={endsOn} onChange={(event) => setEndsOn(event.target.value)} data-testid="input-core-term-end" />
          </div>
        </div>

        <div className="side-note" style={{ marginTop: 20 }}>
          실행 시 G1–8·G10–12는 현재 검증된 grade 기준으로 자동 배정합니다. <strong>G9 31명은 A/B를 추측하지 않고 미배정 상태로 남깁니다.</strong>
        </div>

        <div className="modal-actions">
          <button className="btn btn-primary" disabled={initializeTerm.isPending || !startsOn || !endsOn} data-testid="button-initialize-core-term">
            {initializeTerm.isPending ? '초기화 중' : '현재 학기 초기화'}
          </button>
        </div>
      </form>

      <section className="card card-pad">
        <div className="eyebrow">현재 Readiness</div>
        <h2 className="section-title" style={{ marginTop: 10 }}>학생 Core는 준비됨</h2>
        <p className="subheading" style={{ marginTop: 12 }}>
          Canonical 학생 UUID는 이미 180명 모두 생성되어 있습니다. 다음 단계는 학기/반 enrollment입니다.
        </p>
        <div className="side-note" style={{ marginTop: 22 }}>
          이 화면은 학생 master를 새로 만드는 것이 아니라 기존 Core 학생에 학기별 소속을 붙이는 단계입니다.
        </div>
      </section>
    </div> : <>
      <div className="metric-grid" style={{ marginTop: 28 }}>
        <div className="card metric-card"><div className="metric-label">현재 학기</div><div className="metric-value" style={{ fontSize: 17 }}>{current.termCode}</div><div className="muted" style={{ fontSize: 10 }}>{dateLabel(current.startsOn)} — {dateLabel(current.endsOn)}</div></div>
        <div className="card metric-card"><div className="metric-label">반</div><div className="metric-value">{current.classCount}</div></div>
        <div className="card metric-card"><div className="metric-label">Enrollment</div><div className="metric-value">{current.enrollmentCount}</div></div>
        <div className="card metric-card"><div className="metric-label">G9 배정</div><div className="metric-value">{current.grade9Assigned}/{current.grade9Total}</div></div>
        <div className="card metric-card"><div className="metric-label">G9 미배정</div><div className={current.grade9Pending > 0 ? 'metric-value danger-text' : 'metric-value success-text'}>{current.grade9Pending}</div></div>
      </div>

      <div className="card card-pad" style={{ marginTop: 26 }}>
        <div className="section-row" style={{ marginTop: 0 }}>
          <div>
            <div className="eyebrow">Phase 2</div>
            <h2 className="section-title" style={{ marginTop: 8 }}>G9-A / G9-B 확인 배정</h2>
            <p className="section-copy">별도 검증된 G9 명단을 보면서 한 명씩 배정합니다. 현재 선택은 언제든 A↔B로 수정할 수 있습니다.</p>
          </div>
          <div className="search-box"><Search size={15} /><input className="input" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="G9 학생 검색" data-testid="input-core-grade9-search" /></div>
        </div>

        {grade9Rows.length === 0 ? <EmptyState title="G9 학생이 없습니다" copy="현재 학기 또는 학생 데이터를 확인하세요." /> :
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr><th>학생</th><th>현재 배정</th><th>G9-A</th><th>G9-B</th></tr></thead>
              <tbody>{grade9Rows.map((row) => <tr key={row.studentId} data-testid={'row-core-grade9-' + row.studentId}>
                <td><strong>{row.studentName}</strong></td>
                <td>{row.homeroom ?? <span className="pill pill-warning">미배정</span>}</td>
                <td><button className={'btn ' + (row.section === 'A' ? 'btn-primary' : 'btn-outline')} disabled={assignGrade9.isPending} onClick={() => assign(row.studentId, 'A', row.studentName)} data-testid={'button-core-grade9-a-' + row.studentId}>{row.section === 'A' && <Check size={13} />} G9-A</button></td>
                <td><button className={'btn ' + (row.section === 'B' ? 'btn-primary' : 'btn-outline')} disabled={assignGrade9.isPending} onClick={() => assign(row.studentId, 'B', row.studentName)} data-testid={'button-core-grade9-b-' + row.studentId}>{row.section === 'B' && <Check size={13} />} G9-B</button></td>
              </tr>)}</tbody>
            </table>
          </div>}
      </div>

      <div className="card card-pad" style={{ marginTop: 26 }}>
        <div className="section-row" style={{ marginTop: 0 }}>
          <div>
            <div className="eyebrow">Integration backlog</div>
            <h2 className="section-title" style={{ marginTop: 8 }}>아직 Core 통합이 끝나지 않은 학생</h2>
            <p className="section-copy">이 목록은 실데이터를 추측하기 위한 것이 아니라, 어떤 연결정보가 아직 비어 있는지 확인하기 위한 readiness 목록입니다.</p>
          </div>
          <span className="pill pill-warning">{pendingRows.length}명 남음</span>
        </div>

        {pendingRows.length === 0 ? <EmptyState title="Core 통합 완료" copy="활성 학생의 학번·Auth·현재 학적 연결이 모두 완료되었습니다." /> :
          <div className="table-wrap">
            <table className="data-table">
              <thead><tr><th>학생</th><th>학년/반</th><th>학번</th><th>Core Auth</th><th>외부 Auth</th><th>현재 학적</th><th>상태</th></tr></thead>
              <tbody>{pendingRows.map((row) => <tr key={row.coreStudentId}>
                <td><strong>{row.name}</strong></td>
                <td>{row.homeroom ?? ('G' + row.grade)}</td>
                <td>{row.hasStudentNo ? <span className="pill pill-positive">연결</span> : <span className="pill pill-warning">미연결</span>}</td>
                <td>{row.hasAuthLink ? <span className="pill pill-positive">연결</span> : <span className="pill pill-neutral">없음</span>}</td>
                <td>{row.hasExternalAuthLink ? <span className="pill pill-positive">연결</span> : <span className="pill pill-neutral">없음</span>}</td>
                <td>{row.hasCurrentEnrollment ? <span className="pill pill-positive">배정</span> : <span className="pill pill-warning">미배정</span>}</td>
                <td><span className={'pill ' + (row.readinessStatus === 'PARTIAL' ? 'pill-warning' : 'pill-neutral')}>{row.readinessStatus}</span></td>
              </tr>)}</tbody>
            </table>
          </div>}
      </div>
    </>}
  </div>;
}

function AdminAccountsPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const accounts = useAdminAccounts();
  const provision = useProvisionAdminAccount();
  const update = useUpdateAdminProfile();

  const [editing, setEditing] = useState<AdminAccount | null | undefined>(undefined);
  const [credential, setCredential] = useState<{ loginId: string; temporaryPassword: string } | null>(null);
  const [form, setForm] = useState<{
    loginId: string;
    displayName: string;
    role: Role;
    disciplineScope: DisciplineScope | null;
    isLead: boolean;
    isActive: boolean;
  }>({
    loginId: '',
    displayName: '',
    role: 'SEONDO',
    disciplineScope: 'MIDDLE',
    isLead: false,
    isActive: true,
  });

  const scopeLabel = (scope: DisciplineScope | null) => ({
    ALL: '전체',
    ELEMENTARY: '초등 G1–6',
    MIDDLE: '중등 G7–9',
    HIGH: '고등 G10–12',
  }[scope ?? 'ALL'] ?? '—');

  const refresh = () => queryClient.invalidateQueries({ queryKey: getAdminAccountsQueryKey() });

  const openNew = () => {
    setForm({
      loginId: '',
      displayName: '',
      role: 'SEONDO',
      disciplineScope: 'MIDDLE',
      isLead: false,
      isActive: true,
    });
    setEditing(null);
  };

  const openEdit = (account: AdminAccount) => {
    setForm({
      loginId: account.loginId,
      displayName: account.displayName,
      role: account.role,
      disciplineScope: account.disciplineScope,
      isLead: account.isLead,
      isActive: account.isActive,
    });
    setEditing(account);
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    const normalizedRole = form.role;
    const normalizedScope = normalizedRole === 'SEONDO' ? form.disciplineScope : null;
    const normalizedLead = normalizedRole === 'SEONDO' ? form.isLead : false;

    if (editing) {
      update.mutate({
        adminId: editing.id,
        displayName: form.displayName.trim(),
        role: normalizedRole,
        disciplineScope: normalizedScope,
        isLead: normalizedLead,
        isActive: form.isActive,
      }, {
        onSuccess: () => {
          refresh();
          setEditing(undefined);
          notify('관리자 계정 설정을 저장했습니다.');
        },
        onError: (error) => notify(errText(error), 'error'),
      });
      return;
    }

    provision.mutate({
      loginId: form.loginId.trim().toLowerCase(),
      displayName: form.displayName.trim(),
      role: normalizedRole,
      disciplineScope: normalizedScope,
      isLead: normalizedLead,
    }, {
      onSuccess: (result) => {
        refresh();
        setEditing(undefined);
        setCredential({
          loginId: result.loginId,
          temporaryPassword: result.temporaryPassword,
        });
        notify('개인 관리자 계정을 생성했습니다.');
      },
      onError: (error) => notify(errText(error), 'error'),
    });
  };

  if (accounts.isLoading) return <LoadingState />;
  if (accounts.isError) return <ErrorState error={accounts.error} retry={() => accounts.refetch()} />;

  const rows = accounts.data ?? [];

  return <div>
    <PageHeader
      eyebrow="Individual accountability"
      title="관리자 계정"
      copy="공유 역할 계정에서 개인 계정으로 단계적으로 전환합니다. 새 계정은 임시 비밀번호로 생성되며 첫 로그인 시 비밀번호 변경이 강제됩니다."
      action={<button className="btn btn-primary" onClick={openNew} data-testid="button-new-admin-account"><Plus size={15} /> 개인 계정 생성</button>}
    />

    <div className="side-note" style={{ marginTop: 24 }}>
      <strong>전환 원칙</strong>
      <span style={{ marginLeft: 10 }}>공유계정은 당장 삭제하지 않습니다.</span>
      <div style={{ marginTop: 5 }}>
        개인계정 사용이 안정화된 뒤 shared SEONDO/SASAENG 계정을 비활성화합니다. 신규 기록은 인증된 개인 Auth UUID로 감사로그에 남습니다.
      </div>
    </div>

    <div className="card card-pad" style={{ marginTop: 24 }}>
      <div className="section-row" style={{ marginTop: 0 }}>
        <div>
          <h2 className="section-title">현재 관리자 계정</h2>
          <p className="section-copy">로그인 ID와 업무범위만 표시합니다. Auth UUID와 비밀번호는 노출하지 않습니다.</p>
        </div>
        <span className="pill pill-positive">{rows.filter((row) => row.isActive).length}개 활성</span>
      </div>

      <div className="table-wrap">
        <table className="data-table">
          <thead><tr><th>이름</th><th>로그인 ID</th><th>역할</th><th>담당</th><th>권한</th><th>비밀번호</th><th>상태</th><th>관리</th></tr></thead>
          <tbody>{rows.map((row) => <tr key={row.id} data-testid={'row-admin-' + row.id}>
            <td><strong>{row.displayName}</strong>{row.isSelf ? <span className="muted"> · 나</span> : null}</td>
            <td><code>{row.loginId}</code></td>
            <td>{row.role === 'SEONDO' ? '선도부' : '사생회'}</td>
            <td>{row.role === 'SEONDO' ? scopeLabel(row.disciplineScope) : '기숙사'}</td>
            <td>{row.isLead ? <span className="pill pill-positive">선도부장</span> : <span className="pill pill-neutral">일반</span>}</td>
            <td>{row.mustChangePassword ? <span className="pill pill-warning">첫 변경 필요</span> : <span className="pill pill-positive">설정됨</span>}</td>
            <td><span className={'pill ' + (row.isActive ? 'pill-positive' : 'pill-neutral')}>{row.isActive ? '활성' : '비활성'}</span></td>
            <td><button className="btn btn-outline" onClick={() => openEdit(row)}>설정</button></td>
          </tr>)}</tbody>
        </table>
      </div>
    </div>

    {editing !== undefined && <div className="modal-backdrop">
      <form className="modal" onSubmit={submit}>
        <div className="modal-header">
          <div>
            <div className="eyebrow">{editing ? 'Account settings' : 'Provision account'}</div>
            <h2 className="modal-title">{editing ? '관리자 계정 설정' : '개인 관리자 계정 생성'}</h2>
          </div>
          <button type="button" className="btn btn-icon btn-outline" onClick={() => setEditing(undefined)} aria-label="닫기"><X size={16} /></button>
        </div>

        <div className="form-grid">
          <div className="field full">
            <label htmlFor="admin-display-name">표시 이름</label>
            <input id="admin-display-name" className="input" required maxLength={80} value={form.displayName} onChange={(event) => setForm({ ...form, displayName: event.target.value })} />
          </div>

          <div className="field full">
            <label htmlFor="admin-login-id">로그인 ID</label>
            <input
              id="admin-login-id"
              className="input"
              required
              disabled={Boolean(editing)}
              maxLength={32}
              value={form.loginId}
              onChange={(event) => setForm({ ...form, loginId: event.target.value.toLowerCase() })}
              placeholder="영문 소문자/숫자/._-"
            />
            {!editing && <span className="muted" style={{ fontSize: 11 }}>실제 Auth 이메일은 내부적으로 ID@scale.dics.kr 형식으로 생성됩니다.</span>}
          </div>

          <div className="field">
            <label htmlFor="admin-role">역할</label>
            <select
              id="admin-role"
              className="select"
              value={form.role}
              onChange={(event) => {
                const role = event.target.value as Role;
                setForm({
                  ...form,
                  role,
                  disciplineScope: role === 'SEONDO' ? (form.disciplineScope ?? 'MIDDLE') : null,
                  isLead: role === 'SEONDO' ? form.isLead : false,
                });
              }}
            >
              <option value="SEONDO">선도부</option>
              <option value="SASAENG">사생회</option>
            </select>
          </div>

          {form.role === 'SEONDO' && <div className="field">
            <label htmlFor="admin-scope">담당 범위</label>
            <select id="admin-scope" className="select" disabled={form.isLead} value={form.disciplineScope ?? 'MIDDLE'} onChange={(event) => setForm({ ...form, disciplineScope: event.target.value as DisciplineScope })}>
              <option value="ELEMENTARY">초등 G1–6</option>
              <option value="MIDDLE">중등 G7–9</option>
              <option value="HIGH">고등 G10–12</option>
              <option value="ALL">전체</option>
            </select>
          </div>}

          {form.role === 'SEONDO' && <label className="check-row field full">
            <input type="checkbox" checked={form.isLead} onChange={(event) => setForm({ ...form, isLead: event.target.checked, disciplineScope: event.target.checked ? 'ALL' : (form.disciplineScope === 'ALL' ? 'MIDDLE' : form.disciplineScope) })} />
            선도부장 권한 — 정산·Core 설정·계정관리 접근
          </label>}

          {editing && <label className="check-row field full">
            <input type="checkbox" checked={form.isActive} onChange={(event) => setForm({ ...form, isActive: event.target.checked })} />
            계정 활성화
          </label>}
        </div>

        <div className="side-note" style={{ marginTop: 18 }}>
          {editing
            ? '계정을 비활성화해도 과거 작성자/감사로그는 그대로 보존됩니다.'
            : '임시 비밀번호는 생성 직후 한 번만 화면에 표시합니다. 실제 사용자에게 별도 전달한 뒤 이 화면을 닫으세요.'}
        </div>

        <div className="modal-actions">
          <button type="button" className="btn btn-outline" onClick={() => setEditing(undefined)}>취소</button>
          <button className="btn btn-primary" disabled={provision.isPending || update.isPending || !form.displayName.trim() || !form.loginId.trim()}>
            {editing ? '설정 저장' : (provision.isPending ? '계정 생성 중' : '계정 생성')}
          </button>
        </div>
      </form>
    </div>}

    {credential && <div className="modal-backdrop">
      <div className="modal">
        <div className="modal-header">
          <div>
            <div className="eyebrow">One-time credential</div>
            <h2 className="modal-title">임시 로그인 정보</h2>
          </div>
        </div>

        <div className="side-note">
          <strong>이 비밀번호는 지금 한 번만 표시됩니다.</strong>
          <div style={{ marginTop: 6 }}>사용자는 첫 로그인 직후 새 비밀번호를 설정해야 합니다.</div>
        </div>

        <div className="form-grid" style={{ marginTop: 20 }}>
          <div className="field full">
            <label>로그인 ID</label>
            <div className="credential-box"><code>{credential.loginId}</code></div>
          </div>
          <div className="field full">
            <label>임시 비밀번호</label>
            <div className="credential-box"><code>{credential.temporaryPassword}</code></div>
          </div>
        </div>

        <div className="modal-actions">
          <button
            type="button"
            className="btn btn-outline"
            onClick={async () => {
              await navigator.clipboard.writeText('ID: ' + credential.loginId + '\nTemporary password: ' + credential.temporaryPassword);
              notify('임시 로그인 정보를 클립보드에 복사했습니다.');
            }}
          >복사</button>
          <button type="button" className="btn btn-primary" onClick={() => setCredential(null)}>확인 후 닫기</button>
        </div>
      </div>
    </div>}
  </div>;
}

function AuditLogPage() {
  const logs = useDisciplineAuditLogs();
  const [entityFilter, setEntityFilter] = useState('ALL');
  const [actionFilter, setActionFilter] = useState<'ALL' | 'INSERT' | 'UPDATE' | 'DELETE'>('ALL');

  if (logs.isLoading) return <LoadingState />;
  if (logs.isError) return <ErrorState error={logs.error} retry={() => logs.refetch()} />;

  const entityTypes = Array.from(new Set((logs.data ?? []).map((log) => log.entityType))).sort();
  const rows = (logs.data ?? []).filter((log) =>
    (entityFilter === 'ALL' || log.entityType === entityFilter)
    && (actionFilter === 'ALL' || log.action === actionFilter)
  );

  const actionLabel = (action: 'INSERT' | 'UPDATE' | 'DELETE') =>
    action === 'INSERT' ? '생성' : action === 'UPDATE' ? '수정' : '삭제';

  const entityLabel = (entity: string) => ({
    point_records: '점수 기록',
    reflection_records: '반성문',
    punishments: '처분',
    settlement_periods: '정산기간',
  }[entity] ?? entity);

  const pretty = (value: Record<string, unknown> | null) =>
    value ? JSON.stringify(value, null, 2) : '—';

  return <div>
    <PageHeader
      eyebrow="책임성 · 추적"
      title="감사 로그"
      copy="생활지도 기록의 생성·수정·삭제 이력을 인증된 관리자 계정 기준으로 확인합니다."
    />

    <div className="card card-pad" style={{ marginTop: 28 }}>
      <div className="filter-bar">
        <div className="field">
          <label htmlFor="audit-entity">기록 종류</label>
          <select id="audit-entity" className="select" value={entityFilter} onChange={(event) => setEntityFilter(event.target.value)} data-testid="select-audit-entity">
            <option value="ALL">전체</option>
            {entityTypes.map((entity) => <option key={entity} value={entity}>{entityLabel(entity)}</option>)}
          </select>
        </div>
        <div className="field">
          <label htmlFor="audit-action">변경 종류</label>
          <select id="audit-action" className="select" value={actionFilter} onChange={(event) => setActionFilter(event.target.value as 'ALL' | 'INSERT' | 'UPDATE' | 'DELETE')} data-testid="select-audit-action">
            <option value="ALL">전체</option>
            <option value="INSERT">생성</option>
            <option value="UPDATE">수정</option>
            <option value="DELETE">삭제</option>
          </select>
        </div>
      </div>

      {rows.length === 0 ? <EmptyState title="감사 기록이 없습니다" copy="Audit 적용 이후 변경이 발생하면 여기에 기록됩니다." /> :
        <div className="activity-list" style={{ marginTop: 20 }}>
          {rows.map((log) => <div className="activity-row" key={log.id} style={{ alignItems: 'flex-start' }} data-testid={'row-audit-' + log.id}>
            <div className="activity-mark"><Database size={15} /></div>
            <div style={{ minWidth: 0, flex: 1 }}>
              <div className="activity-label">
                {log.actorName} · {entityLabel(log.entityType)} #{log.entityId ?? '—'} · {actionLabel(log.action)}
              </div>
              <div className="record-meta">{dateTimeLabel(log.createdAt)}{log.actorRole ? ' · ' + (log.actorRole === 'SEONDO' ? '선도부' : '사생회') : ''}</div>
              <details style={{ marginTop: 8 }}>
                <summary className="table-link" style={{ cursor: 'pointer' }}>변경 상세 보기</summary>
                <div className="detail-grid" style={{ marginTop: 10 }}>
                  <div>
                    <div className="eyebrow">BEFORE</div>
                    <pre className="audit-json">{pretty(log.beforeData)}</pre>
                  </div>
                  <div>
                    <div className="eyebrow">AFTER</div>
                    <pre className="audit-json">{pretty(log.afterData)}</pre>
                  </div>
                </div>
              </details>
            </div>
          </div>)}
        </div>}
    </div>
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
  const selectedStudent = (students.data ?? []).find((student) => String(student.id) === studentId);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!admin || !selectedStudent?.coreStudentId) {
      if (studentId) notify('이 학생의 Core Identity 연결을 확인해주세요.', 'error');
      return;
    }
    create.mutate({
      data: {
        coreStudentId: selectedStudent.coreStudentId,
        types,
        startDate,
        endDate,
        enteredByName: admin.displayName,
      },
    }, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: getListPunishmentsQueryKey() });
        setStudentId('');
        setTypes([]);
        notify('처분이 등록되었습니다.');
      },
      onError: (error) => notify(errText(error), 'error'),
    });
  };
  if (students.isLoading || punishments.isLoading) return <LoadingState />;
  if (students.isError || punishments.isError) return <ErrorState error={students.error ?? punishments.error} retry={() => { students.refetch(); punishments.refetch(); }} />;
  return <div><PageHeader eyebrow="사생회 운영" title="기숙사 처분" copy="수동 처분과 위반 여부를 같은 화면에서 기록합니다." /><div className="detail-grid" style={{ marginTop: 30 }}><form className="card card-pad" onSubmit={submit}><h2 className="section-title">처분 등록</h2><p className="section-copy">한 번에 최대 두 가지 처분을 선택할 수 있습니다.</p><div className="form-grid" style={{ marginTop: 24 }}><div className="field full"><label htmlFor="punishment-student">학생</label><select id="punishment-student" className="select" required value={studentId} onChange={(event) => setStudentId(event.target.value)} data-testid="select-punishment-student"><option value="">학생 선택</option>{(students.data ?? []).map((student) => <option key={student.id} value={student.id}>{student.name} · {student.grade}학년</option>)}</select></div><div className="field full"><label>처분 유형 <span className="muted">({types.length}/2)</span></label><div className="filter-bar">{PUNISHMENT_TYPES.map((value) => <button type="button" key={value} className={`btn ${types.includes(value) ? 'btn-primary' : 'btn-outline'}`} onClick={() => toggleType(value)} data-testid={`button-punishment-type-${value}`}>{types.includes(value) && <Check size={13} />}{value}</button>)}</div></div><div className="field"><label htmlFor="punishment-start">시작일</label><input id="punishment-start" className="input" type="date" required value={startDate} onChange={(event) => setStartDate(event.target.value)} data-testid="input-punishment-start" /></div><div className="field"><label htmlFor="punishment-end">종료일</label><input id="punishment-end" className="input" type="date" required value={endDate} onChange={(event) => setEndDate(event.target.value)} data-testid="input-punishment-end" /></div><div className="side-note field full">기록자 <strong>{admin?.displayName ?? '로그인 관리자'}</strong> · 인증된 계정으로 자동 기록됩니다.</div></div><div className="modal-actions"><button className="btn btn-primary" disabled={create.isPending || !studentId || !selectedStudent?.coreStudentId || types.length === 0} data-testid="button-submit-punishment">{create.isPending ? '저장 중' : '처분 등록'}</button></div></form><section className="card card-pad"><div className="section-row" style={{ margin: 0 }}><div><h2 className="section-title">최근 처분</h2><p className="section-copy">위반 시 규정에 따라 상태를 갱신합니다.</p></div></div>{punishments.data?.length === 0 ? <EmptyState title="처분 기록이 없습니다" copy="등록된 기숙사 처분이 없습니다." /> : <div className="activity-list">{punishments.data?.map((punishment) => <div className="activity-row" key={punishment.id} data-testid={`row-manual-punishment-${punishment.id}`}><div className="activity-mark"><BedDouble size={15} /></div><div style={{ minWidth: 0 }}><div className="activity-label">{punishment.studentName} · {punishment.types.join(' · ')}</div><div className="record-meta">{dateLabel(punishment.startDate)} — {dateLabel(punishment.endDate)} · {punishment.enteredByName}</div></div><button className={`pill ${punishment.violated ? 'pill-negative' : 'pill-neutral'}`} onClick={() => setViolation.mutate({ id: punishment.id, violated: !punishment.violated }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: getListPunishmentsQueryKey() }), onError: (error) => notify(errText(error), 'error') })} data-testid={`button-punishment-violation-${punishment.id}`}>{punishment.violated ? '위반 기록됨' : '위반 없음'}</button></div>)}</div>}</section></div></div>;
}

function DepartmentMeritAdminPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const departments = useDepartmentMeritAdmin();
  const members = useDepartmentCurrentMembers();
  const weeklyStatus = useDepartmentMeritStatus();
  const ensureWeeklyMerits = useEnsureWeeklyDepartmentMerits();
  const students = useCoreStudentReadiness();
  const saveRule = useCreateDepartmentWithMeritRule();
  const setMembership = useSetDepartmentStudentMembership();
  const setDepartmentActive = useSetDepartmentActive();

  const [selectedDepartmentId, setSelectedDepartmentId] = useState('');
  const [studentSearch, setStudentSearch] = useState('');
  const [studentId, setStudentId] = useState('');
  const [membershipDate, setMembershipDate] = useState(currentWeekMonday());
  const [form, setForm] = useState({
    code: '',
    name: '',
    points: '1',
    itemLabel: '부서활동 주간 상점',
    effectiveFrom: currentWeekMonday(),
  });

  const departmentRows = departments.data ?? [];
  const selectedDepartment = departmentRows.find((row) => row.departmentId === selectedDepartmentId) ?? null;

  useEffect(() => {
    if (!selectedDepartmentId && departmentRows.length > 0) {
      setSelectedDepartmentId(departmentRows[0].departmentId);
    }
  }, [departmentRows, selectedDepartmentId]);

  useEffect(() => {
    if (!selectedDepartment) return;
    setForm({
      code: selectedDepartment.code,
      name: selectedDepartment.name,
      points: String(selectedDepartment.points ?? 1),
      itemLabel: selectedDepartment.itemLabel ?? '부서활동 주간 상점',
      effectiveFrom: selectedDepartment.effectiveFrom ?? currentWeekMonday(),
    });
  }, [selectedDepartment?.departmentId]);

  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: getDepartmentMeritAdminQueryKey() });
    queryClient.invalidateQueries({ queryKey: getDepartmentMembersQueryKey() });
    queryClient.invalidateQueries({ queryKey: getDepartmentMeritStatusQueryKey() });
    queryClient.invalidateQueries({ queryKey: getGetDashboardQueryKey() });
  };

  const currentMembers = (members.data ?? []).filter((row) => row.departmentId === selectedDepartmentId);
  const memberIds = new Set(currentMembers.map((row) => row.coreStudentId));
  const needle = studentSearch.trim().toLowerCase();
  const candidates = (students.data ?? []).filter((row) =>
    !memberIds.has(row.coreStudentId)
    && (
      !needle
      || row.name.toLowerCase().includes(needle)
      || (row.studentNo ?? '').toLowerCase().includes(needle)
      || (row.homeroom ?? '').toLowerCase().includes(needle)
    )
  ).slice(0, 50);

  const resetNewDepartment = () => {
    setSelectedDepartmentId('');
    setForm({
      code: '',
      name: '',
      points: '1',
      itemLabel: '부서활동 주간 상점',
      effectiveFrom: currentWeekMonday(),
    });
  };

  const submitDepartment = (event: FormEvent) => {
    event.preventDefault();
    const points = Number(form.points);
    if (!form.code.trim() || !form.name.trim() || !form.itemLabel.trim() || !Number.isFinite(points)) return;

    saveRule.mutate({
      code: form.code.trim(),
      name: form.name.trim(),
      points,
      itemLabel: form.itemLabel.trim(),
      effectiveFrom: form.effectiveFrom,
    }, {
      onSuccess: (departmentId) => {
        refresh();
        setSelectedDepartmentId(departmentId);
        notify('부서와 주간 상점 규칙을 저장했습니다.');
      },
      onError: (error) => notify(errText(error), 'error'),
    });
  };

  const addMember = () => {
    if (!selectedDepartmentId || !studentId) return;
    setMembership.mutate({
      departmentId: selectedDepartmentId,
      studentId,
      active: true,
      effectiveOn: membershipDate,
    }, {
      onSuccess: () => {
        refresh();
        setStudentId('');
        setStudentSearch('');
        notify('부서 소속 학생을 추가했습니다.');
      },
      onError: (error) => notify(errText(error), 'error'),
    });
  };

  const removeMember = (coreStudentId: string) => {
    if (!selectedDepartmentId) return;
    if (!window.confirm('이 학생의 현재 부서 소속을 종료할까요? 과거 상점 기록은 유지됩니다.')) return;

    setMembership.mutate({
      departmentId: selectedDepartmentId,
      studentId: coreStudentId,
      active: false,
      effectiveOn: today(),
    }, {
      onSuccess: () => {
        refresh();
        notify('부서 소속을 종료했습니다.');
      },
      onError: (error) => notify(errText(error), 'error'),
    });
  };

  if (departments.isLoading || members.isLoading || weeklyStatus.isLoading || students.isLoading) return <LoadingState />;
  if (departments.isError || members.isError || weeklyStatus.isError || students.isError) {
    return <ErrorState
      error={departments.error ?? members.error ?? weeklyStatus.error ?? students.error}
      retry={() => { departments.refetch(); members.refetch(); weeklyStatus.refetch(); students.refetch(); }}
    />;
  }

  const expectedThisWeek = weeklyStatus.data?.length ?? 0;
  const generatedThisWeek = weeklyStatus.data?.filter((row) => row.generated).length ?? 0;

  return <div>
    <PageHeader
      eyebrow="주간 자동 상점"
      title="부서 상점 관리"
      copy="실제 부서활동 명단과 주간 상점 규칙을 운영 DB에서 관리합니다. Git에는 학생 소속 데이터가 저장되지 않습니다."
      action={<button className="btn btn-primary" onClick={resetNewDepartment} data-testid="button-new-department"><Plus size={15} /> 새 부서</button>}
    />

    <div className="side-note" style={{ marginTop: 24 }}>
      <strong>이번 주 자동 상점</strong>
      <span style={{ marginLeft: 10 }}>{generatedThisWeek}/{expectedThisWeek}건 생성됨</span>
      <button
        type="button"
        className="btn btn-outline"
        style={{ marginLeft: 12 }}
        disabled={ensureWeeklyMerits.isPending}
        onClick={() => ensureWeeklyMerits.mutate(undefined, {
          onSuccess: (inserted) => {
            refresh();
            notify(inserted > 0 ? '이번 주 부서활동 상점 ' + inserted + '건을 반영했습니다.' : '이번 주 부서활동 상점은 이미 최신 상태입니다.');
          },
          onError: (error) => notify(errText(error), 'error'),
        })}
        data-testid="button-ensure-department-merits"
      >
        <RefreshCw size={14} /> 이번 주 반영
      </button>
    </div>

    <div className="detail-grid" style={{ marginTop: 22 }}>
      <section className="card card-pad">
        <div className="section-row" style={{ marginTop: 0 }}>
          <div>
            <div className="eyebrow">Departments</div>
            <h2 className="section-title" style={{ marginTop: 8 }}>부서 목록</h2>
          </div>
          <span className="pill pill-positive">{departmentRows.filter((row) => row.isActive).length}개 활성</span>
        </div>

        {departmentRows.length === 0 ? <EmptyState title="등록된 부서가 없습니다" copy="새 부서를 만들고 주간 상점 규칙을 지정하세요." /> :
          <div className="activity-list">
            {departmentRows.map((row) => <button
              type="button"
              key={row.departmentId}
              className={'activity-row department-row-button ' + (selectedDepartmentId === row.departmentId ? 'selected' : '')}
              onClick={() => setSelectedDepartmentId(row.departmentId)}
              data-testid={'button-department-' + row.departmentId}
            >
              <div className="activity-mark"><ArrowUpRight size={15} /></div>
              <div style={{ textAlign: 'left', minWidth: 0, flex: 1 }}>
                <div className="activity-label">{row.name}</div>
                <div className="record-meta">
                  {row.code} · {row.points != null ? '+' + row.points + '점/주' : '규칙 없음'} · 현재 {row.currentMemberCount}명
                </div>
              </div>
              <span className={'pill ' + (row.isActive ? 'pill-positive' : 'pill-neutral')}>{row.isActive ? '활성' : '중지'}</span>
            </button>)}
          </div>}
      </section>

      <form className="card card-pad" onSubmit={submitDepartment}>
        <div className="eyebrow">{selectedDepartment ? 'Rule version' : 'New department'}</div>
        <h2 className="section-title" style={{ marginTop: 8 }}>{selectedDepartment ? '부서 / 상점 규칙 수정' : '새 부서 만들기'}</h2>
        <p className="section-copy">점수를 변경하면 이전 규칙은 이력으로 남고 새 effective date부터 새 규칙이 적용됩니다.</p>

        <div className="form-grid" style={{ marginTop: 22 }}>
          <div className="field">
            <label htmlFor="dept-code">부서 코드</label>
            <input id="dept-code" className="input" required maxLength={40} value={form.code} onChange={(event) => setForm({ ...form, code: event.target.value })} placeholder="예: MEDIA" />
          </div>
          <div className="field">
            <label htmlFor="dept-name">부서명</label>
            <input id="dept-name" className="input" required maxLength={80} value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="dept-points">주간 상점</label>
            <input id="dept-points" className="input" type="number" min="1" max="20" required value={form.points} onChange={(event) => setForm({ ...form, points: event.target.value })} />
          </div>
          <div className="field">
            <label htmlFor="dept-effective">적용 시작일</label>
            <input id="dept-effective" className="input" type="date" required value={form.effectiveFrom} onChange={(event) => setForm({ ...form, effectiveFrom: event.target.value })} />
          </div>
          <div className="field full">
            <label htmlFor="dept-item-label">상점 기록명</label>
            <input id="dept-item-label" className="input" required maxLength={120} value={form.itemLabel} onChange={(event) => setForm({ ...form, itemLabel: event.target.value })} />
          </div>
        </div>

        <div className="modal-actions">
          {selectedDepartment && <button
            type="button"
            className="btn btn-outline"
            disabled={setDepartmentActive.isPending}
            onClick={() => setDepartmentActive.mutate({
              departmentId: selectedDepartment.departmentId,
              active: !selectedDepartment.isActive,
            }, {
              onSuccess: () => {
                refresh();
                notify(selectedDepartment.isActive ? '부서를 중지했습니다.' : '부서를 다시 활성화했습니다.');
              },
              onError: (error) => notify(errText(error), 'error'),
            })}
          >{selectedDepartment.isActive ? '부서 중지' : '부서 활성화'}</button>}
          <button className="btn btn-primary" disabled={saveRule.isPending}>규칙 저장</button>
        </div>
      </form>
    </div>

    <section className="card card-pad" style={{ marginTop: 26 }}>
      <div className="section-row" style={{ marginTop: 0 }}>
        <div>
          <div className="eyebrow">Membership</div>
          <h2 className="section-title" style={{ marginTop: 8 }}>{selectedDepartment ? selectedDepartment.name + ' 소속 학생' : '부서를 먼저 선택하세요'}</h2>
          <p className="section-copy">소속 이력은 삭제하지 않고 시작일/종료일로 보존합니다.</p>
        </div>
        {selectedDepartment && <span className="pill pill-positive">{currentMembers.length}명</span>}
      </div>

      {selectedDepartment ? <>
        <div className="form-grid" style={{ marginTop: 20 }}>
          <div className="field full">
            <label htmlFor="dept-student-search">학생 검색</label>
            <div className="search-box"><Search size={15} /><input
              id="dept-student-search"
              className="input"
              value={studentSearch}
              onChange={(event) => { setStudentSearch(event.target.value); setStudentId(''); }}
              placeholder="이름 · 학번 · 반"
            /></div>
            <select className="select" value={studentId} onChange={(event) => setStudentId(event.target.value)}>
              <option value="">추가할 학생 선택</option>
              {candidates.map((row) => <option key={row.coreStudentId} value={row.coreStudentId}>
                {row.name + ' · ' + (row.homeroom ?? ('G' + row.grade)) + (row.studentNo ? ' · ' + row.studentNo : '')}
              </option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="membership-date">소속 시작일</label>
            <input id="membership-date" className="input" type="date" value={membershipDate} onChange={(event) => setMembershipDate(event.target.value)} />
          </div>
          <div className="field" style={{ justifyContent: 'end' }}>
            <label>&nbsp;</label>
            <button type="button" className="btn btn-primary" disabled={!studentId || setMembership.isPending} onClick={addMember}>
              <Plus size={14} /> 학생 추가
            </button>
          </div>
        </div>

        <div className="side-note" style={{ marginTop: 16 }}>
          이번 주 월요일({dateLabel(currentWeekMonday())}) 이전/당일부터 유효한 소속만 이번 주 자동 상점 대상이 됩니다. 이미 생성된 과거 상점은 소속 종료 시 삭제하지 않습니다.
        </div>

        {currentMembers.length === 0 ? <EmptyState title="현재 소속 학생이 없습니다" copy="학생을 추가하면 주간 자동 상점 대상에 포함됩니다." /> :
          <div className="table-wrap" style={{ marginTop: 18 }}>
            <table className="data-table">
              <thead><tr><th>학생</th><th>학년/반</th><th>학번</th><th>시작일</th><th>관리</th></tr></thead>
              <tbody>{currentMembers.map((row) => <tr key={row.membershipId}>
                <td><strong>{row.studentName}</strong></td>
                <td>{row.homeroom ?? (row.grade ? 'G' + row.grade : '—')}</td>
                <td className="muted">{row.studentNo ?? '미발급'}</td>
                <td>{dateLabel(row.startsOn)}</td>
                <td><button type="button" className="btn btn-outline" onClick={() => removeMember(row.coreStudentId)}>소속 종료</button></td>
              </tr>)}</tbody>
            </table>
          </div>}
      </> : <EmptyState title="부서 선택 필요" copy="왼쪽에서 부서를 선택하거나 새 부서를 만드세요." />}
    </section>
  </div>;
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

function ChangePasswordPage() {
  const { admin, refreshAdmin, signOut } = useAuth();
  const [, setLocation] = useLocation();
  const changePassword = useChangeAdminPassword();
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');

  const strong = password.length >= 12
    && /[A-Z]/.test(password)
    && /[a-z]/.test(password)
    && /[0-9]/.test(password)
    && /[^A-Za-z0-9]/.test(password);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError('');

    if (!strong) {
      setError('12자 이상이며 영문 대·소문자, 숫자, 특수문자를 모두 포함해주세요.');
      return;
    }
    if (password !== confirm) {
      setError('새 비밀번호 확인이 일치하지 않습니다.');
      return;
    }

    setPending(true);
    try {
      await changePassword.mutateAsync(password);
      await refreshAdmin();
      setLocation('/dashboard');
    } catch (changeError) {
      setError(errText(changeError));
      setPending(false);
    }
  };

  return <div className="landing" style={{ display: 'grid', placeItems: 'center', minHeight: '100dvh', padding: 20 }}>
    <div style={{ width: '100%', maxWidth: 500 }}>
      <div style={{ textAlign: 'center', marginBottom: 24 }}>
        <Brand />
        <p className="subheading">개인 관리자 계정 첫 로그인</p>
      </div>
      <form className="card card-pad" onSubmit={submit}>
        <div className="eyebrow">보안 설정</div>
        <h1 className="modal-title" style={{ marginTop: 8 }}>새 비밀번호를 설정해주세요</h1>
        <p className="section-copy" style={{ marginTop: 8 }}>
          {admin?.displayName ?? '관리자'} 계정은 임시 비밀번호로 생성되었습니다. 생활지도 기록이 개인 계정에 귀속되므로 첫 사용 전에 비밀번호를 변경합니다.
        </p>

        <div className="form-grid" style={{ marginTop: 22 }}>
          <div className="field full">
            <label htmlFor="new-admin-password">새 비밀번호</label>
            <input
              id="new-admin-password"
              className="input"
              type="password"
              autoComplete="new-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
            <span className="muted" style={{ fontSize: 11 }}>12자 이상 · 대문자 · 소문자 · 숫자 · 특수문자 포함</span>
          </div>
          <div className="field full">
            <label htmlFor="confirm-admin-password">새 비밀번호 확인</label>
            <input
              id="confirm-admin-password"
              className="input"
              type="password"
              autoComplete="new-password"
              required
              value={confirm}
              onChange={(event) => setConfirm(event.target.value)}
            />
          </div>
        </div>

        {error && <p className="danger-text" style={{ fontSize: 12, marginTop: 14 }} role="alert">{error}</p>}

        <div className="modal-actions">
          <button type="button" className="btn btn-outline" onClick={() => signOut()}>로그아웃</button>
          <button className="btn btn-primary" disabled={pending || !strong || password !== confirm}>
            {pending ? '변경 중' : '비밀번호 변경 후 시작'}
          </button>
        </div>
      </form>
    </div>
  </div>;
}

function ProtectedRoutes() {
  const { session, admin, loading, signOut } = useAuth();
  if (loading) return <LoadingState />;
  if (!session) return <Redirect to="/sign-in" />;
  if (!admin) return <div className="app-loading"><div className="error-box"><AlertTriangle size={24} /><p>관리자 권한이 없는 계정입니다. 운영 담당자에게 문의해주세요.</p><button className="btn btn-outline" onClick={() => signOut()} data-testid="button-no-admin-sign-out"><LogOut size={14} /> 로그아웃</button></div></div>;
  if (!admin.isActive) return <div className="app-loading"><div className="error-box"><ShieldAlert size={24} /><p>비활성화된 관리자 계정입니다. 선도부장에게 문의해주세요.</p><button className="btn btn-outline" onClick={() => signOut()}><LogOut size={14} /> 로그아웃</button></div></div>;
  if (admin.mustChangePassword) return <ChangePasswordPage />;
  return <AppShell role={admin.role}><Switch><Route path="/dashboard" component={DashboardPage} /><Route path="/students" component={() => <RoleGate role="SEONDO"><StudentsPage /></RoleGate>} /><Route path="/students/:id" component={StudentDetailPage} /><Route path="/points/negative" component={() => <RoleGate role="SEONDO"><PointEntryPage type="NEGATIVE" /></RoleGate>} /><Route path="/points/positive" component={() => <RoleGate role="SEONDO"><PointEntryPage type="POSITIVE" /></RoleGate>} /><Route path="/reflections" component={() => <RoleGate role="SEONDO"><ReflectionsPage /></RoleGate>} /><Route path="/reports" component={() => <RoleGate role="SEONDO"><ReportsPage /></RoleGate>} /><Route path="/settlement" component={() => <LeadGate><SettlementPage /></LeadGate>} /><Route path="/audit" component={() => <LeadGate><AuditLogPage /></LeadGate>} /><Route path="/admins" component={() => <LeadGate><AdminAccountsPage /></LeadGate>} /><Route path="/core-setup" component={() => <LeadGate><CoreSetupPage /></LeadGate>} /><Route path="/department-merits" component={() => <LeadGate><DepartmentMeritAdminPage /></LeadGate>} /><Route path="/punishments" component={() => <RoleGate role="SASAENG"><PunishmentsPage /></RoleGate>} /><Route path="/point-items" component={() => <RoleGate role="SEONDO"><PointItemsPage /></RoleGate>} /><Route path="/"><Redirect to="/dashboard" /></Route><Route component={NotFoundInline} /></Switch></AppShell>;
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
