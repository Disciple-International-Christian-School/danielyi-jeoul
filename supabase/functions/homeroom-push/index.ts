import { createClient } from 'npm:@supabase/supabase-js@2.47.10';
import webpush from 'npm:web-push@3.6.7';

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return new Response(null,{status:405});
  const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const {data:config,error:configError}=await db.rpc('homeroom_push_config');
  if(configError || !config) return new Response(null,{status:503});
  if(request.headers.get('x-dispatch-token')!==config.dispatch_token) return new Response(null,{status:401});
  webpush.setVapidDetails('mailto:dicsrhkgkr@gmail.com',config.public_key,config.private_key);
  const {data:jobs,error}=await db.rpc('claim_homeroom_push');
  if(error) return new Response(null,{status:500});
  const outcomes=await Promise.all(jobs.map(async (job:any)=>{
    let code=503;
    try {
      const response=await webpush.sendNotification({endpoint:job.endpoint,keys:job.keys},JSON.stringify({
        title:'다니엘저울',body:job.kind==='TEST'?'휴대전화 알림이 연결되었습니다.':job.kind==='DOUBLE'?'담당 학급에 반성문 2배 제출 대상자가 발생했습니다.':'담당 학급에 반성문 제출 대상자가 발생했습니다.',
        tag:job.id,url:'/teacher'
      }),{TTL:300,timeout:10000});
      code=response.statusCode;
    } catch(error) { code=(error as {statusCode?:number}).statusCode??503; }
    const {error:saveError}=await db.rpc('finish_homeroom_push',{p_id:job.id,p_code:code});
    return {ok:!saveError && code>=200 && code<300};
  }));
  return Response.json({processed:outcomes.length,sent:outcomes.filter(x=>x.ok).length});
});
