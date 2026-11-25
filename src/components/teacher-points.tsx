import { useRef, useState, type KeyboardEvent } from 'react';
import { ArrowRight, BookOpenCheck, CircleMinus, CirclePlus, History, LayoutDashboard, Search } from 'lucide-react';
import { Link, useLocation } from 'wouter';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/lib/auth';

const menus = [
  { href: '/teacher/dashboard', label: '대시보드', icon: LayoutDashboard },
  { href: '/teacher/positive', label: '상점 입력', icon: CirclePlus },
  { href: '/teacher/negative', label: '벌점 입력', icon: CircleMinus },
  { href: '/teacher/history', label: '기록 확인', icon: History },
  { href: '/teacher', label: '담당 학생 벌점 확인', icon: BookOpenCheck },
];

export function TeacherLinks() {
  const [path] = useLocation();
  return <nav aria-label="교사 메뉴" className="teacher-menu">
    {menus.map(({href, label, icon: Icon}) => <Link key={href} href={href}
      aria-current={path === href ? 'page' : undefined} className="teacher-nav-link">
      <Icon size={17} aria-hidden="true" />{label}
    </Link>)}
  </nav>;
}
type Student = { id: string; name: string; homeroom: string };
type Kind = 'POSITIVE' | 'NEGATIVE';
const message = (error: unknown) => (error as {message?: string})?.message ?? '다시 시도해주세요.';
const day = (date = new Date()) => new Intl.DateTimeFormat('sv-SE', {timeZone:'Asia/Seoul'}).format(date);
const time = (value: string | null) => value ? new Date(value).toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' }) : '—';

export function TeacherEntry({kind}: {kind: Kind}) {
  const {session} = useAuth();
  const cache = useQueryClient();
  const [filter,setFilter] = useState('');
  const [student,setStudent] = useState('');
  const [reason,setReason] = useState('');
  const [points,setPoints] = useState('');
  const [continuous,setContinuous] = useState(kind === 'NEGATIVE');
  const [status,setStatus] = useState('');
  const request = useRef({key:'',id:''});
  const locked = useRef(false);
  const search = useRef<HTMLInputElement>(null);
  const select = useRef<HTMLSelectElement>(null);
  const reasonInput = useRef<HTMLInputElement>(null);
  const students = useQuery({queryKey:['teacher-point-students',session?.user.id],queryFn:async()=>{
    const {data,error}=await supabase.rpc('teacher_point_students');
    if(error) throw error;
    return data as Student[];
  }});
  const save = useMutation({mutationFn:async()=>{
    const key=JSON.stringify([student,reason.trim(),kind,points]);
    if(request.current.key!==key) request.current={key,id:crypto.randomUUID()};
    const {error}=await supabase.rpc('submit_teacher_point',{p_id:request.current.id,p_student:student,
      p_kind:kind,p_reason:reason.trim(),p_points:Number(points)});
    if(error) throw error;
  },onSuccess:()=>{
    request.current={key:'',id:''};
    setStatus(`${kind === 'POSITIVE' ? '상점' : '벌점'} 예약을 저장했습니다.`);
    setStudent(''); setFilter('');
    if(!continuous){setReason('');setPoints('');}
    void cache.invalidateQueries({queryKey:['teacher-point-history']});
    requestAnimationFrame(()=>search.current?.focus());
  },onSettled:()=>{locked.current=false;}});
  const negative = kind === 'NEGATIVE';
  const label = negative ? '벌점' : '상점';
  const sign = negative ? '−' : '+';
  const Icon = negative ? CircleMinus : CirclePlus;
  const needle = filter.trim();
  const matches = (students.data ?? []).filter(s => `${s.homeroom} ${s.name}`.includes(needle));
  const selected = matches.find(s => s.id === student);
  const ready = Boolean(selected && reason.trim() && points);

  function handleStudentEnter(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key !== 'Enter' || event.nativeEvent.isComposing) return;
    event.preventDefault();
    if (selected || (needle && matches.length === 1)) {
      setStudent(selected?.id ?? matches[0].id);
      reasonInput.current?.focus();
    } else if (needle && matches.length > 1) {
      select.current?.focus();
    }
  }

  return <form className={`card teacher-entry ${negative ? 'teacher-negative' : 'teacher-positive'}`} onSubmit={event => {
    event.preventDefault();
    if (!ready || locked.current) return;
    locked.current = true;
    setStatus('');
    save.mutate();
  }}>
    <header className="teacher-entry-header">
      <Icon size={32} aria-hidden="true" />
      <div><h2 className="section-title">{label} 입력</h2>
        <p className="section-copy">다음 등교일 00:00에 {label}으로 반영됩니다.</p>
      </div>
    </header>
    <fieldset className="teacher-fields" disabled={save.isPending}>
      <div className="field">
        <label htmlFor="teacher-student-search">학생 검색</label>
        <div className="search-box"><Search size={16} aria-hidden="true" />
          <input id="teacher-student-search" ref={search} className="input" value={filter}
            onChange={event => { setFilter(event.target.value); setStudent(''); }}
            onKeyDown={handleStudentEnter} placeholder="이름 또는 학급" autoComplete="off" lang="ko" />
        </div>
        <select aria-label="학생 선택" ref={select} required className="select" value={student}
          onChange={event => setStudent(event.target.value)}>
          <option value="">학생 선택</option>
          {matches.map(s => <option key={s.id} value={s.id}>{s.homeroom} · {s.name}</option>)}
        </select>
        {students.isPending && <span className="record-meta" role="status">학생 목록을 불러오는 중입니다.</span>}
        {needle && students.isSuccess && !selected && <span className="record-meta" role="status">
          {matches.length === 0 ? '일치하는 학생이 없습니다.' :
            matches.length === 1 ? 'Enter를 누르면 학생을 선택하고 사유로 이동합니다.' : `${matches.length}명 중 학생을 선택하세요.`}
        </span>}
      </div>
      <div className="field">
        <label htmlFor="teacher-point-reason">{label} 사유</label>
        <input id="teacher-point-reason" ref={reasonInput} required maxLength={80} className="input"
          value={reason} onChange={event => setReason(event.target.value)} />
      </div>
      <fieldset className="teacher-score">
        <legend>{label} 점수</legend>
        <div className="teacher-score-options">{[1, 2, 3, 4, 5].map(n => <label key={n}>
          <input type="radio" name="teacher-points" value={n} checked={points === String(n)}
            onChange={event => setPoints(event.target.value)} required />
          <span>{sign}{n}</span>
        </label>)}</div>
      </fieldset>
      <label className="check-row">
        <input type="checkbox" checked={continuous} onChange={event => setContinuous(event.target.checked)} />
        연속 입력 · 사유와 점수 유지
      </label>
      <div className="teacher-entry-actions">
        {selected && points && <span className="record-meta">{selected.homeroom} · {selected.name}</span>}
        <button className="btn teacher-register" disabled={!ready}>
          {save.isPending ? '저장 중…' : `${label}${points ? ` ${sign}${points}점` : ''} 등록`}
        </button>
      </div>
    </fieldset>
    {students.isError && <p className="teacher-entry-feedback" role="alert">{message(students.error)} <button type="button" onClick={() => students.refetch()}>다시 확인</button></p>}
    {save.isError && <p className="teacher-entry-feedback" role="alert">{message(save.error)}</p>}
    {status && <p className="teacher-entry-feedback success-text" role="status">{status}</p>}
  </form>;
}

type Row = {id:string;staff_id:string;teacher:string;student:string;kind:Kind;reason:string;points:number;entered_at:string;
  scheduled_on:string;posted_at:string|null;cancelled_at:string|null;state:string;in_week:boolean;next_school_day:boolean};
function useTeacherHistory(team = false, date: string | null = null) {
  const {session} = useAuth();
  return useQuery({queryKey:['teacher-point-history',session?.user.id,team,date],refetchInterval:30000,queryFn:async()=>{
    const rows: Row[] = [];
    const size = 500;
    for (;;) {
      const {data,error}=await supabase.rpc('teacher_point_history',{p_team:team,p_week:date})
        .order('entered_at',{ascending:false}).order('id').range(rows.length,rows.length+size-1);
      if(error) throw error;
      rows.push(...data as Row[]);
      if(data.length<size) return rows;
    }
  }});
}

const signedPoints = (row: Row) => `${row.kind === 'POSITIVE' ? '+' : '−'}${row.points}`;
const enteredToday = (row: Row) => day(new Date(row.entered_at)) === day();

export function TeacherDashboard({name, followups}: {name: string; followups: number}) {
  const history = useTeacherHistory();
  const rows = history.data ?? [];
  const today = rows.filter(row => enteredToday(row) && !row.cancelled_at);
  const waiting = rows.filter(row => !row.cancelled_at && !row.posted_at && row.state !== '반영 실패');
  const failed = rows.filter(row => row.state === '반영 실패').length;
  const next = waiting.reduce<string | null>((earliest, row) =>
    !earliest || row.scheduled_on < earliest ? row.scheduled_on : earliest, null);

  return <div className="teacher-records">
    <section className="card card-pad teacher-overview">
      <div className="section-row teacher-dashboard-row">
        <h2 className="section-title">{name} 선생님</h2>
        <time dateTime={day()} className="record-meta">{new Intl.DateTimeFormat('ko-KR', {
          month: 'long', day: 'numeric', weekday: 'short', timeZone: 'Asia/Seoul',
        }).format(new Date())}</time>
      </div>
      <div className="teacher-metrics">
        <div><span className="metric-label">오늘 입력</span><strong>{history.data ? today.length : '—'}<small>건</small></strong></div>
        <Link href="/teacher/history"><span className="metric-label">반영 대기</span><strong>{history.data ? waiting.length : '—'}<small>건</small></strong></Link>
        <Link href="/teacher"><span className="metric-label">담당 학급 미제출</span><strong>{followups}<small>건</small></strong></Link>
      </div>
      {next && <p className="record-meta teacher-next-post">가장 이른 반영 예정 · {next} 00:00 KST</p>}
      {failed > 0 && <p className="teacher-next-post danger-text">반영 실패 {failed}건 · <Link href="/teacher/history">기록 확인</Link></p>}
    </section>
    <div className="teacher-start-actions">
      <Link href="/teacher/positive" className="teacher-start-card teacher-positive"><CirclePlus size={22} aria-hidden="true" />상점 입력<ArrowRight size={17} aria-hidden="true" /></Link>
      <Link href="/teacher/negative" className="teacher-start-card teacher-negative"><CircleMinus size={22} aria-hidden="true" />벌점 입력<ArrowRight size={17} aria-hidden="true" /></Link>
    </div>
    <section className="card card-pad">
      <div className="section-row teacher-dashboard-row">
        <h2 className="section-title">최근 입력</h2>
        <Link href="/teacher/history" className="btn btn-outline">전체 기록 <ArrowRight size={14} aria-hidden="true" /></Link>
      </div>
      {history.isPending ? <p role="status" className="section-copy">기록을 불러오는 중입니다.</p> :
        history.isError ? <p role="alert">{message(history.error)} <button type="button" onClick={()=>history.refetch()}>다시 확인</button></p> :
        rows.length === 0 ? <p className="section-copy">아직 입력한 상벌점이 없습니다.</p> :
        <ul className="teacher-recent">{rows.slice(0, 4).map(row => <li key={row.id}>
          <span className={`pill ${row.kind === 'POSITIVE' ? 'pill-positive' : 'pill-negative'}`}>{signedPoints(row)}</span>
          <div><strong>{row.student}</strong><span className="record-meta">{row.reason}</span></div>
          <div className="teacher-recent-status"><strong>{row.state}</strong><span className="record-meta">{
            row.posted_at ? day(new Date(row.posted_at)) : row.cancelled_at ? day(new Date(row.cancelled_at)) : `${row.scheduled_on} 예정`
          }</span></div>
        </li>)}</ul>}
    </section>
  </div>;
}

export function TeacherHistory({team=false}:{team?:boolean}) {
  const cache=useQueryClient();
  const [date,setDate]=useState(day);
  const history=useTeacherHistory(team,team?date:null);
  const cancel=useMutation({mutationFn:async(id:string)=>{
    const {error}=await supabase.rpc('cancel_teacher_point',{p_id:id});if(error)throw error;
  },onSuccess:()=>cache.invalidateQueries({queryKey:['teacher-point-history']})});
  const records=history.data??[];
  function table(title:string,rows:Row[]) {
    return <section className="card card-pad"><h2 className="section-title">{title}</h2>
      {!rows.length?<p>기록이 없습니다.</p>:<div className="table-wrap"><table className="data-table"><thead><tr>
        {['교사','학생','상벌점','사유','입력 시각','반영 예정일','실제 반영 시각','상태'].map(h=><th key={h}>{h}</th>)}
      </tr></thead><tbody>{rows.map(r=><tr key={r.id}><td>{r.teacher}</td><td>{r.student}</td><td>{signedPoints(r)}</td>
        <td>{r.reason}</td><td>{time(r.entered_at)}</td><td>{r.scheduled_on}</td><td>{time(r.posted_at)}</td><td>{r.state} {r.cancelled_at&&time(r.cancelled_at)}
        {!team&&enteredToday(r)&&!r.posted_at&&!r.cancelled_at&&<button className="btn btn-outline" disabled={cancel.isPending} onClick={()=>cancel.mutate(r.id)}>취소</button>}</td></tr>)}</tbody></table></div>}</section>;
  }
  const weekly=records.filter(r=>r.in_week);
  const totals=new Map<string,{name:string;positive:number;negative:number}>();
  for(const r of weekly.filter(r=>!r.cancelled_at)){
    const t=totals.get(r.staff_id)??{name:r.teacher,positive:0,negative:0};
    t[r.kind==='POSITIVE'?'positive':'negative']+=r.points;totals.set(r.staff_id,t);
  }
  return <div className="teacher-records">{team&&<label>기준일 <input className="input" type="date" value={date} onChange={e=>{if(e.target.value)setDate(e.target.value);}}/></label>}
    {cancel.isError&&<p role="alert">{message(cancel.error)}</p>}
    {history.isPending?<p role="status">불러오는 중…</p>:history.isError?<p role="alert">{message(history.error)} <button onClick={()=>history.refetch()}>다시 확인</button></p>:team?
    <>{table('다음 등교일 반영 기록',records.filter(r=>r.next_school_day))}
    <section className="card card-pad"><h2 className="section-title">교사별 주간 합계</h2>{Array.from(totals,([id,t])=><p key={id}>{t.name} · 상점 +{t.positive} · 벌점 −{t.negative}</p>)}</section>
    {table('주간 입력 기록',weekly)}</>:<>{table('오늘 입력',records.filter(enteredToday))}{table('이전 기록',records.filter(r=>!enteredToday(r)))}</>}
  </div>;
}
