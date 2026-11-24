import { useRef, useState } from 'react';
import { Link } from 'wouter';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/lib/auth';

const menus = [
  ['/teacher/dashboard', '대시보드'], ['/teacher/positive', '상점 입력'],
  ['/teacher/negative', '벌점 입력'], ['/teacher/history', '기록 확인'], ['/teacher', '담당 학생 벌점 확인'],
];
export function TeacherLinks({ dashboard = false }: { dashboard?: boolean }) {
  return <nav aria-label={dashboard ? '교사 업무 바로가기' : '교사 메뉴'} className={dashboard ? 'teacher-shortcuts' : 'teacher-menu'}>
    {menus.slice(dashboard ? 1 : 0).map(([url, label]) => <Link key={url} href={url}
      aria-current={location.pathname === url ? 'page' : undefined} className="btn btn-outline">{label}</Link>)}
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
    setStatus('저장했습니다. 다음 등교일에 반영됩니다.');
    setStudent(''); setFilter('');
    if(!continuous){setReason('');setPoints('');}
    void cache.invalidateQueries({queryKey:['teacher-point-history']});
    requestAnimationFrame(()=>search.current?.focus());
  },onSettled:()=>{locked.current=false;}});
  const title=kind==='POSITIVE'?'상점 입력':'벌점 입력';
  return <form className="card card-pad" onSubmit={e=>{e.preventDefault();if(locked.current)return;locked.current=true;setStatus('');save.mutate();}}>
    <h2 className="section-title">{title}</h2>
    <fieldset className="teacher-fields" disabled={save.isPending}>
      <label>학생 검색<input className="input" ref={search} value={filter} onChange={e=>{setFilter(e.target.value);setStudent('');}} placeholder="이름 또는 학급"/></label>
      <label>학생 선택<select aria-label="학생 선택" required className="input" value={student} onChange={e=>setStudent(e.target.value)}>
        <option value="">학생 선택</option>{students.data?.filter(s=>(s.homeroom+' '+s.name).includes(filter.trim())).map(s=><option key={s.id} value={s.id}>{s.homeroom} · {s.name}</option>)}</select></label>
      <label>사유<input required maxLength={80} className="input" value={reason} onChange={e=>setReason(e.target.value)}/></label>
      <label>점수<select aria-label="점수" required className="input" value={points} onChange={e=>setPoints(e.target.value)}><option value="">점수 선택</option>
        {[1,2,3,4,5].map(n=><option key={n} value={n}>{n}점</option>)}</select></label>
      <label><input type="checkbox" checked={continuous} onChange={e=>setContinuous(e.target.checked)}/> 연속 입력</label>
      <button className="btn btn-primary" disabled={!student||!reason.trim()||!points}>{save.isPending?'저장 중…':'등록'}</button>
    </fieldset>
    {students.isError&&<p role="alert">{message(students.error)} <button type="button" onClick={()=>students.refetch()}>다시 확인</button></p>}
    {save.isError&&<p role="alert">{message(save.error)}</p>}{status&&<p role="status">{status}</p>}
  </form>;
}

type Row = {id:string;staff_id:string;teacher:string;student:string;kind:Kind;reason:string;points:number;entered_at:string;
  scheduled_on:string;posted_at:string|null;cancelled_at:string|null;state:string;in_week:boolean;next_school_day:boolean};
export function TeacherHistory({team=false}:{team?:boolean}) {
  const {session}=useAuth();
  const cache=useQueryClient();
  const [date,setDate]=useState(day);
  const history=useQuery({queryKey:['teacher-point-history',session?.user.id,team,team?date:null],refetchInterval:30000,queryFn:async()=>{
    const rows: Row[] = [];
    const size = 500;
    for (;;) {
      const {data,error}=await supabase.rpc('teacher_point_history',{p_team:team,p_week:team?date:null})
        .order('entered_at',{ascending:false}).order('id').range(rows.length,rows.length+size-1);
      if(error) throw error;
      rows.push(...data as Row[]);
      if(data.length<size) return rows;
    }
  }});
  const cancel=useMutation({mutationFn:async(id:string)=>{
    const {error}=await supabase.rpc('cancel_teacher_point',{p_id:id});if(error)throw error;
  },onSuccess:()=>cache.invalidateQueries({queryKey:['teacher-point-history']})});
  const records=history.data??[];
  const today=(r:Row)=>day(new Date(r.entered_at))===day();
  function table(title:string,rows:Row[]) {
    return <section className="card card-pad"><h2 className="section-title">{title}</h2>
      {!rows.length?<p>기록이 없습니다.</p>:<div className="table-wrap"><table className="data-table"><thead><tr>
        {['교사','학생','상벌점','사유','입력 시각','반영 예정일','실제 반영 시각','상태'].map(h=><th key={h}>{h}</th>)}
      </tr></thead><tbody>{rows.map(r=><tr key={r.id}><td>{r.teacher}</td><td>{r.student}</td><td>{r.kind==='POSITIVE'?'+':'−'}{r.points}</td>
        <td>{r.reason}</td><td>{time(r.entered_at)}</td><td>{r.scheduled_on}</td><td>{time(r.posted_at)}</td><td>{r.state} {r.cancelled_at&&time(r.cancelled_at)}
        {!team&&today(r)&&!r.posted_at&&!r.cancelled_at&&<button className="btn btn-outline" disabled={cancel.isPending} onClick={()=>cancel.mutate(r.id)}>취소</button>}</td></tr>)}</tbody></table></div>}</section>;
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
    {table('주간 입력 기록',weekly)}</>:<>{table('오늘 입력',records.filter(today))}{table('이전 기록',records.filter(r=>!today(r)))}</>}
  </div>;
}
