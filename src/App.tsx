import { createContext, useContext, useMemo, useState, type FormEvent, type ReactNode } from 'react';
import { QueryClient, QueryClientProvider, useQueryClient } from '@tanstack/react-query';
import {
  AlertTriangle,
  ArrowDownRight,
  ArrowUpRight,
  BedDouble,
  BookOpenCheck,
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
  useCreatePointItem,
  useCreatePointRecord,
  useCreatePunishment,
  useDeletePointItem,
  useDeletePointRecord,
  useGetDashboard,
  useGetStudent,
  useImportPointItems,
  useListPointItems,
  useListPointRecords,
  useListPunishments,
  useListReflections,
  useListStudents,
  useSetPunishmentViolation,
  useUpdatePointItem,
  useUpdatePointRecord,
  useUpdateReflection,
  type PointItem,
  type PointRecord,
  type Punishment,
  type Role,
  type StudentSummary,
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
  return new Intl.DateTimeFormat('ko-KR', { month: 'short', day: 'numeric' }).format(new Date(value));
}
function dateTimeLabel(value?: string | null) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('ko-KR', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(value));
}
function today() { return new Date().toISOString().slice(0, 10); }
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
    { href: '/dashboard', label: '대시보드', icon: LayoutDashboard, roles: ['SEONDO', 'SASAENG'] as Role[] },
    { href: '/students', label: '학생 관리', icon: Users, roles: ['SEONDO'] as Role[] },
    { href: '/points/negative', label: '벌점 입력', icon: ArrowDownRight, roles: ['SEONDO'] as Role[] },
    { href: '/points/positive', label: '상점 입력', icon: ArrowUpRight, roles: ['SEONDO'] as Role[] },
    { href: '/reflections', label: '반성문', icon: BookOpenCheck, roles: ['SEONDO'] as Role[] },
    { href: '/punishments', label: '기숙사 처분', icon: BedDouble, roles: ['SASAENG'] as Role[] },
    { href: '/point-items', label: '점수 항목', icon: SlidersHorizontal, roles: ['SEONDO'] as Role[] },
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
        {nav.filter((item) => item.roles.includes(role)).map((item) => {
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

function DashboardPage() {
  const dashboard = useGetDashboard();
  const [search, setSearch] = useState('');
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
  const students = useListStudents();
  const items = useListPointItems({ type, includeInactive: false });
  const create = useCreatePointRecord();
  const [studentId, setStudentId] = useState('');
  const [itemId, setItemId] = useState('');
  const [points, setPoints] = useState('');
  const [enteredByName, setEnteredByName] = useState('');
  const [recordedAt, setRecordedAt] = useState(today());
  const [reflectionSubmitted, setReflectionSubmitted] = useState(false);
  const [search, setSearch] = useState('');
  const negative = type === 'NEGATIVE';
  const filteredStudents = (students.data ?? []).filter((student) => student.name.includes(search));
  const selectedItem = (items.data ?? []).find((item) => String(item.id) === itemId);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (!studentId || !enteredByName.trim()) return;
    create.mutate({ data: { studentId: Number(studentId), type, item: selectedItem?.name ?? '수기 입력', points: Number(points), recordedAt, enteredByName: enteredByName.trim(), reflectionSubmitted: negative ? reflectionSubmitted : null } }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: getListStudentsQueryKey() }); queryClient.invalidateQueries({ queryKey: getGetDashboardQueryKey() }); setStudentId(''); setItemId(''); setPoints(''); setReflectionSubmitted(false); notify(`${negative ? '벌점' : '상점'}을 기록했습니다.`); }, onError: (error) => notify(errText(error), 'error') });
  };
  if (students.isLoading || items.isLoading) return <LoadingState />;
  if (students.isError || items.isError) return <ErrorState error={students.error ?? items.error} retry={() => { students.refetch(); items.refetch(); }} />;
  return <div><PageHeader eyebrow={negative ? '생활지도 기록' : '긍정 기록'} title={negative ? '벌점 입력' : '상점 입력'} copy={negative ? '사실과 대화를 바탕으로 오늘의 벌점을 기록합니다.' : '학생의 좋은 행동을 놓치지 않고 상점으로 남깁니다.'} /><div className="detail-grid" style={{ marginTop: 30 }}><form className="card card-pad" onSubmit={submit}><div className="section-row" style={{ margin: 0 }}><div><h2 className="section-title">새 기록</h2><p className="section-copy">필수 항목을 모두 입력해 주세요.</p></div><span className={`pill ${negative ? 'pill-negative' : 'pill-positive'}`}>{negative ? '벌점' : '상점'}</span></div><div className="form-grid" style={{ marginTop: 25 }}><div className="field full"><label htmlFor="entry-student">학생 검색</label><div className="search-box"><Search size={15} /><input id="entry-student" className="input" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="이름을 입력해 목록을 좁혀보세요" data-testid="input-point-student-search" /></div><select className="select" value={studentId} onChange={(event) => setStudentId(event.target.value)} required data-testid="select-point-student"><option value="">학생 선택</option>{filteredStudents.map((student) => <option key={student.id} value={student.id}>{student.name} · {student.grade}학년</option>)}</select></div><div className="field full"><label htmlFor="entry-item">점수 항목</label><select id="entry-item" className="select" value={itemId} onChange={(event) => { setItemId(event.target.value); const selected = (items.data ?? []).find((item) => String(item.id) === event.target.value); if (selected?.fixedPoints != null) setPoints(String(selected.fixedPoints)); }} data-testid="select-point-item"><option value="">항목 선택 또는 수기 입력</option>{(items.data ?? []).map((item) => <option key={item.id} value={item.id}>{item.name}{item.fixedPoints != null ? ` · ${item.fixedPoints}점` : ''}</option>)}</select></div><div className="field"><label htmlFor="entry-points">점수</label><input id="entry-points" className="input" type="number" min="1" max="100" required value={points} onChange={(event) => setPoints(event.target.value)} data-testid="input-point-value" /></div><div className="field"><label htmlFor="entry-date">기록일</label><input id="entry-date" className="input" type="date" required value={recordedAt} onChange={(event) => setRecordedAt(event.target.value)} data-testid="input-point-date" /></div><div className="field full"><label htmlFor="entry-by">기입자</label><input id="entry-by" className="input" required maxLength={40} value={enteredByName} onChange={(event) => setEnteredByName(event.target.value)} placeholder="실제 기입자 이름" data-testid="input-point-entered-by" /></div>{negative && <label className="check-row field full"><input type="checkbox" checked={reflectionSubmitted} onChange={(event) => setReflectionSubmitted(event.target.checked)} data-testid="checkbox-reflection-submitted" /> 같은 날 반성문 제출 완료</label>}</div><div className="modal-actions"><button className="btn btn-primary" disabled={create.isPending || !studentId} data-testid="button-submit-point">{create.isPending ? '저장 중' : `${negative ? '벌점' : '상점'} 기록하기`}</button></div></form><div className="card card-pad"><div className="eyebrow">입력 원칙</div><h2 className="section-title" style={{ marginTop: 10 }}>{negative ? '기록은 구체적으로' : '좋은 행동을 보이게'}</h2><p className="subheading" style={{ marginTop: 12 }}>{negative ? '학생이 무엇을 어겼는지 항목과 기입자 이름을 분명히 남겨야 이후 상담과 반성문 안내가 흔들리지 않습니다.' : '작은 개선도 기록할수록 학생과 생활지도 담당자가 성장의 흐름을 함께 확인할 수 있습니다.'}</p><div className="side-note" style={{ marginTop: 24 }}>선택한 항목에 고정 점수가 있으면 점수가 자동으로 채워집니다. 수기 입력은 항목 없이도 가능합니다.</div></div></div></div>;
}

function ReflectionsPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const [filter, setFilter] = useState<'ALL' | 'SUBMITTED' | 'MISSING' | 'DOUBLE'>('ALL');
  const reflections = useListReflections();
  const update = useUpdateReflection();
  if (reflections.isLoading) return <LoadingState />;
  if (reflections.isError) return <ErrorState error={reflections.error} retry={() => reflections.refetch()} />;
  const filterLabels = [['ALL', '전체'], ['SUBMITTED', '제출 완료'], ['MISSING', '미제출'], ['DOUBLE', '2배 제출 대상']] as const;
  const rows = (reflections.data ?? []).filter((reflection) => filter === 'ALL' || reflection.status === filter);
  return <div><PageHeader eyebrow="반성문 관리" title="반성문 현황" copy="벌점 기록과 연결된 당일 반성문 제출 상태를 확인합니다." /><div className="card card-pad" style={{ marginTop: 30 }}><div className="tab-row">{filterLabels.map(([value, label]) => <button key={value} className={`tab ${filter === value ? 'active' : ''}`} onClick={() => setFilter(value)} data-testid={`button-reflection-filter-${value.toLowerCase()}`}>{label}</button>)}</div>{rows.length === 0 ? <EmptyState title="해당 반성문이 없습니다" copy="선택한 조건에 맞는 반성문이 없습니다." /> : <div className="table-wrap"><table className="data-table"><thead><tr><th>학생</th><th>벌점 항목</th><th>벌점</th><th>입력일</th><th>제출기한</th><th>상태</th><th>제출 여부</th></tr></thead><tbody>{rows.map((reflection) => <tr key={reflection.id} data-testid={`row-reflection-${reflection.id}`}><td><Link className="table-link" href={`/students/${reflection.studentId}`} data-testid={`link-reflection-student-${reflection.id}`}>{reflection.studentName}</Link> <span className="muted">{reflection.grade}학년</span></td><td>{reflection.item}</td><td className="weight-number danger-text">{reflection.points}</td><td className="muted">{dateLabel(reflection.recordedAt)}</td><td className="muted">{dateLabel(reflection.submissionDeadline)}</td><td><span className={`pill ${reflection.status === 'SUBMITTED' ? 'pill-positive' : reflection.status === 'DOUBLE' ? 'pill-negative' : 'pill-warning'}`}>{reflection.status === 'SUBMITTED' ? '제출 완료' : reflection.status === 'DOUBLE' ? '2배 대상' : '미제출'}</span>{reflection.submittedAt && <div className="record-meta">제출 {dateTimeLabel(reflection.submittedAt)}</div>}</td><td><button className="btn btn-outline" onClick={() => { update.mutate({ id: reflection.id, data: { submitted: !reflection.submitted } }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: getListReflectionsQueryKey() }); notify('반성문 상태를 변경했습니다.'); }, onError: (error) => notify(errText(error), 'error') }); }} data-testid={`button-toggle-reflection-${reflection.id}`}>{reflection.submitted ? '미제출로' : '제출 완료'}</button></td></tr>)}</tbody></table></div>}</div></div>;
}

function PunishmentsPage() {
  const queryClient = useQueryClient();
  const notify = useContext(NoticeContext);
  const students = useListStudents();
  const punishments = useListPunishments();
  const create = useCreatePunishment();
  const setViolation = useSetPunishmentViolation();
  const [studentId, setStudentId] = useState('');
  const [types, setTypes] = useState<string[]>([]);
  const [startDate, setStartDate] = useState(today());
  const [endDate, setEndDate] = useState(today());
  const [enteredByName, setEnteredByName] = useState('');
  const toggleType = (value: string) => setTypes((current) => current.includes(value) ? current.filter((item) => item !== value) : current.length < 2 ? [...current, value] : current);
  const submit = (event: FormEvent) => { event.preventDefault(); create.mutate({ data: { studentId: Number(studentId), types, startDate, endDate, enteredByName: enteredByName.trim() } }, { onSuccess: () => { queryClient.invalidateQueries({ queryKey: getListPunishmentsQueryKey() }); setStudentId(''); setTypes([]); setEnteredByName(''); notify('처분이 등록되었습니다.'); }, onError: (error) => notify(errText(error), 'error') }); };
  if (students.isLoading || punishments.isLoading) return <LoadingState />;
  if (students.isError || punishments.isError) return <ErrorState error={students.error ?? punishments.error} retry={() => { students.refetch(); punishments.refetch(); }} />;
  return <div><PageHeader eyebrow="사생회 운영" title="기숙사 처분" copy="수동 처분과 위반 여부를 같은 화면에서 기록합니다." /><div className="detail-grid" style={{ marginTop: 30 }}><form className="card card-pad" onSubmit={submit}><h2 className="section-title">처분 등록</h2><p className="section-copy">한 번에 최대 두 가지 처분을 선택할 수 있습니다.</p><div className="form-grid" style={{ marginTop: 24 }}><div className="field full"><label htmlFor="punishment-student">학생</label><select id="punishment-student" className="select" required value={studentId} onChange={(event) => setStudentId(event.target.value)} data-testid="select-punishment-student"><option value="">학생 선택</option>{(students.data ?? []).map((student) => <option key={student.id} value={student.id}>{student.name} · {student.grade}학년</option>)}</select></div><div className="field full"><label>처분 유형 <span className="muted">({types.length}/2)</span></label><div className="filter-bar">{PUNISHMENT_TYPES.map((value) => <button type="button" key={value} className={`btn ${types.includes(value) ? 'btn-primary' : 'btn-outline'}`} onClick={() => toggleType(value)} data-testid={`button-punishment-type-${value}`}>{types.includes(value) && <Check size={13} />}{value}</button>)}</div></div><div className="field"><label htmlFor="punishment-start">시작일</label><input id="punishment-start" className="input" type="date" required value={startDate} onChange={(event) => setStartDate(event.target.value)} data-testid="input-punishment-start" /></div><div className="field"><label htmlFor="punishment-end">종료일</label><input id="punishment-end" className="input" type="date" required value={endDate} onChange={(event) => setEndDate(event.target.value)} data-testid="input-punishment-end" /></div><div className="field full"><label htmlFor="punishment-by">기입자</label><input id="punishment-by" className="input" required value={enteredByName} onChange={(event) => setEnteredByName(event.target.value)} data-testid="input-punishment-entered-by" /></div></div><div className="modal-actions"><button className="btn btn-primary" disabled={create.isPending || !studentId || types.length === 0} data-testid="button-submit-punishment">{create.isPending ? '저장 중' : '처분 등록'}</button></div></form><section className="card card-pad"><div className="section-row" style={{ margin: 0 }}><div><h2 className="section-title">최근 처분</h2><p className="section-copy">위반 시 규정에 따라 상태를 갱신합니다.</p></div></div>{punishments.data?.length === 0 ? <EmptyState title="처분 기록이 없습니다" copy="등록된 기숙사 처분이 없습니다." /> : <div className="activity-list">{punishments.data?.map((punishment) => <div className="activity-row" key={punishment.id} data-testid={`row-manual-punishment-${punishment.id}`}><div className="activity-mark"><BedDouble size={15} /></div><div style={{ minWidth: 0 }}><div className="activity-label">{punishment.studentName} · {punishment.types.join(' · ')}</div><div className="record-meta">{dateLabel(punishment.startDate)} — {dateLabel(punishment.endDate)} · {punishment.enteredByName}</div></div><button className={`pill ${punishment.violated ? 'pill-negative' : 'pill-neutral'}`} onClick={() => setViolation.mutate({ id: punishment.id, violated: !punishment.violated }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: getListPunishmentsQueryKey() }), onError: (error) => notify(errText(error), 'error') })} data-testid={`button-punishment-violation-${punishment.id}`}>{punishment.violated ? '위반 기록됨' : '위반 없음'}</button></div>)}</div>}</section></div></div>;
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
  return <AppShell role={admin.role}><Switch><Route path="/dashboard" component={DashboardPage} /><Route path="/students" component={() => <RoleGate role="SEONDO"><StudentsPage /></RoleGate>} /><Route path="/students/:id" component={StudentDetailPage} /><Route path="/points/negative" component={() => <RoleGate role="SEONDO"><PointEntryPage type="NEGATIVE" /></RoleGate>} /><Route path="/points/positive" component={() => <RoleGate role="SEONDO"><PointEntryPage type="POSITIVE" /></RoleGate>} /><Route path="/reflections" component={() => <RoleGate role="SEONDO"><ReflectionsPage /></RoleGate>} /><Route path="/punishments" component={() => <RoleGate role="SASAENG"><PunishmentsPage /></RoleGate>} /><Route path="/point-items" component={() => <RoleGate role="SEONDO"><PointItemsPage /></RoleGate>} /><Route path="/"><Redirect to="/dashboard" /></Route><Route component={NotFoundInline} /></Switch></AppShell>;
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
