create extension if not exists pg_net with schema extensions;
create function private.dispatch_homeroom_push() returns bigint language sql security definer set search_path='' as $$
 select net.http_post(
 url:='https://jgrzsfomcwfiukkaqtos.supabase.co/functions/v1/homeroom-push',
 headers:=jsonb_build_object('Content-Type','application/json','x-dispatch-token',c.dispatch_token),
 body:='{}'::jsonb,timeout_milliseconds:=20000)
 from private.web_push_config c
$$;
revoke all on function private.dispatch_homeroom_push() from public,anon,authenticated;
select cron.schedule('daniels-scale-homeroom-push','* * * * *','select private.dispatch_homeroom_push()');
