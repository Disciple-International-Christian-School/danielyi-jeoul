import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/lib/auth';

type Reflection={id:number;student_name:string;homeroom:string;item:string;recorded_at:string;status:string;submitted:boolean;due_at:string};
type Portal={name:string;classes:string[];publicKey:string|null;reflections:Reflection[]};
const errorText=(error:unknown)=>error instanceof Error?error.message:String((error as {message?:string})?.message??'처리하지 못했습니다. 다시 시도해주세요.');
function keyBytes(key:string):Uint8Array<ArrayBuffer> {
 const binary=atob(key.replace(/-/g,'+').replace(/_/g,'/'));return Uint8Array.from(binary,c=>c.charCodeAt(0));
}

export function TeacherPortal(){
 const {session,loading,signOut}=useAuth();
 const [message,setMessage]=useState('');
 const [pending,setPending]=useState(false);
 const [subscribed,setSubscribed]=useState(false);
 const [endpoint,setEndpoint]=useState<string|null>(null);
 const supported='serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
 const ios=/iPad|iPhone|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
 const installed=window.matchMedia('(display-mode: standalone)').matches || Boolean((navigator as Navigator & {standalone?:boolean}).standalone);
 const portal=useQuery({queryKey:['homeroom-portal',session?.user.id],enabled:!!session,
  queryFn:async()=>{const {data,error}=await supabase.rpc('homeroom_portal');if(error)throw error;return data as Portal;},refetchInterval:60000,retry:false});
 useEffect(()=>{
  let cancelled=false;
  if(supported)navigator.serviceWorker.getRegistration('/').then(async reg=>{
   const sub=await reg?.pushManager.getSubscription();if(!cancelled){setSubscribed(!!sub);setEndpoint(sub?.endpoint??null);}
  }).catch(()=>{});
  return()=>{cancelled=true;};
 },[supported,session?.user.id]);
 async function login(){
  setPending(true);setMessage('');
  const {error}=await supabase.auth.signInWithOAuth({provider:'google',options:{redirectTo:window.location.origin+'/teacher',queryParams:{prompt:'select_account'}}});
  if(error){setMessage(error.message);setPending(false);}
 }
 async function enable(){
  setPending(true);setMessage('');
  try{
   if(!portal.data?.publicKey)throw new Error('알림 서버 설정을 준비 중입니다.');
   // Request directly inside the click handler for iOS user activation requirements.
   const permission=await Notification.requestPermission();
   if(permission!=='granted')throw new Error('휴대전화 설정에서 다니엘저울 알림을 허용해주세요.');
   await navigator.serviceWorker.register('/push-sw.js',{scope:'/'});
   const reg=await navigator.serviceWorker.ready;
   const sub=await reg.pushManager.getSubscription()??await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:keyBytes(portal.data.publicKey)});
   const {error}=await supabase.rpc('register_homeroom_push',{p_subscription:sub.toJSON()});if(error)throw error;
   setSubscribed(true);setEndpoint(sub.endpoint);setMessage('이 기기의 알림을 등록했습니다. 테스트 알림으로 확인해주세요.');
  }catch(error){setMessage(errorText(error));}finally{setPending(false);}
 }
 async function disable(){
  const reg=await navigator.serviceWorker.getRegistration('/');const sub=await reg?.pushManager.getSubscription();
  if(sub){const {error}=await supabase.rpc('disable_homeroom_push',{p_endpoint:sub.endpoint});if(error)throw error;await sub.unsubscribe();}
  setSubscribed(false);setEndpoint(null);
 }
 async function action(fn:()=>Promise<void>){setPending(true);setMessage('');try{await fn();}catch(error){setMessage(errorText(error));}finally{setPending(false);}}
 const rows=portal.data?.reflections??[];
 return <main className="teacher-portal"><header className="section-row"><div><div className="eyebrow">다니엘저울</div><h1 className="heading">담임 알림</h1></div>{session&&<button className="btn btn-outline" disabled={pending} onClick={()=>action(async()=>{if(supported)await disable();await signOut();})}>로그아웃</button>}</header>
 {loading?<p role="status">로그인 확인 중…</p>:!session?<section className="card card-pad"><h2 className="section-title">담임 계정으로 시작하기</h2><p className="section-copy">학교에 등록된 구글 계정으로 로그인해주세요.</p><button className="btn btn-primary" disabled={pending} onClick={login}>Google로 로그인</button></section>:portal.isPending?<p role="status">담당 학급 확인 중…</p>:portal.isError?<section className="card card-pad"><p role="alert">{errorText(portal.error)}</p><button className="btn btn-outline" onClick={()=>portal.refetch()}>다시 확인</button></section>:portal.data&&<>
 <section className="card card-pad"><h2 className="section-title">{portal.data.name} 선생님 · {portal.data.classes.join(', ')}</h2><p className="section-copy">담당 학급에 반성문 대상자가 새로 발생하면 이 기기로 알려드립니다.</p>
 {ios&&!installed?<p>아이폰에서는 Safari의 공유 메뉴 → 홈 화면에 추가 후, 추가된 아이콘으로 열어주세요.</p>:!supported?<p>이 브라우저는 푸시 알림을 지원하지 않습니다. 최신 Chrome 또는 홈 화면에 추가한 Safari 앱을 이용해주세요.</p>:<div className="teacher-actions"><button className="btn btn-primary" disabled={pending||!portal.data.publicKey} onClick={enable}>{subscribed?'알림 등록 갱신':'이 기기에서 알림 받기'}</button>{subscribed&&<><button className="btn btn-outline" disabled={pending} onClick={()=>action(async()=>{const {error}=await supabase.rpc('test_homeroom_push',{p_endpoint:endpoint});if(error)throw error;setMessage('테스트 알림을 요청했습니다. 약 1분 이내 도착합니다.');})}>테스트 알림</button><button className="btn btn-outline" disabled={pending} onClick={()=>action(async()=>{await disable();setMessage('이 기기의 알림을 해제했습니다.');})}>알림 해제</button></>}</div>}
 {!portal.data.publicKey&&<p>알림 서버 설정을 준비 중입니다.</p>}</section>
 <section className="card card-pad"><div className="section-row"><h2 className="section-title">담당 학급 반성문</h2><button className="btn btn-outline" onClick={()=>portal.refetch()}>새로고침</button></div>{rows.length===0?<p>현재 반성문 기록이 없습니다.</p>:<div className="table-wrap"><table className="data-table"><thead><tr><th>학급</th><th>학생</th><th>발생일</th><th>상태</th></tr></thead><tbody>{rows.map(r=><tr key={r.id}><td>{r.homeroom}</td><td>{r.student_name}</td><td>{r.recorded_at.slice(0,10)}</td><td>{r.submitted?'제출 완료':r.status==='DOUBLE'?'2배 제출 대상':'미제출'}</td></tr>)}</tbody></table></div>}</section>
 </>}{message&&<p role="status" className="card card-pad">{message}</p>}<p className="muted">알림 내용에는 학생 이름을 표시하지 않습니다. 알림을 누르면 로그인 후 담당 학급을 확인합니다.</p></main>;
}
