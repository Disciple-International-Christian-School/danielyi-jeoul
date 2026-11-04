-- Run against a configured project; all test subscriptions and queue entries roll back.
begin;
do $$
declare uid uuid; sid uuid; p jsonb; sub uuid; ep text:='https://fcm.googleapis.com/fcm/send/dics-rollback-test'; denied boolean:=false;
begin
 if has_table_privilege('authenticated','core.staff_accounts','SELECT') or has_function_privilege('authenticated','public.homeroom_push_config()','EXECUTE') or has_function_privilege('anon','public.homeroom_portal()','EXECUTE') then raise exception 'Privilege exposure'; end if;
 perform set_config('request.jwt.claim.sub','',true);
 begin perform public.homeroom_portal(); exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'Anonymous portal access'; end if;
 select u.id,s.id into uid,sid from auth.users u join core.staff_accounts s on lower(u.email)=any(s.login_emails) where s.is_active and u.email_confirmed_at is not null limit 1;
 if uid is null then raise exception 'No verified staff account available for testing'; end if;
 perform set_config('request.jwt.claim.sub',uid::text,true);
 p:=public.homeroom_portal();
 if jsonb_array_length(p->'classes')=0 then raise exception 'No assigned classes returned'; end if;
 if exists(select 1 from jsonb_array_elements(p->'reflections') r where not (p->'classes') ? (r->>'homeroom')) then raise exception 'Cross-class record leak'; end if;
 denied:=false;
 begin perform public.register_homeroom_push(jsonb_build_object('endpoint','https://example.com/private','keys',jsonb_build_object('p256dh',repeat('A',87),'auth',repeat('A',22)))); exception when others then denied:=true; end;
 if not denied then raise exception 'Invalid endpoint accepted'; end if;
 sub:=public.register_homeroom_push(jsonb_build_object('endpoint',ep,'keys',jsonb_build_object('p256dh',repeat('A',87),'auth',repeat('A',22))));
 if (select user_id from private.web_push_subscriptions where id=sub)<>uid then raise exception 'Subscription owner mismatch'; end if;
 perform public.claim_homeroom_push();
 if exists(select 1 from private.web_push_deliveries where subscription_id=sub and kind<>'TEST') then raise exception 'Historical notification backfill'; end if;
 perform public.test_homeroom_push(ep);
 if (select count(*) from private.web_push_deliveries where subscription_id=sub and kind='TEST')<>1 then raise exception 'Test notification missing'; end if;
 denied:=false;
 begin perform public.test_homeroom_push(ep); exception when others then denied:=true; end;
 if not denied then raise exception 'Test rate limit failed'; end if;
 perform public.disable_homeroom_push(ep);
 if (select active from private.web_push_subscriptions where id=sub) then raise exception 'Unsubscribe failed'; end if;
 perform public.claim_homeroom_push();
 if exists(select 1 from private.web_push_deliveries where subscription_id=sub and state='PENDING') then raise exception 'Disabled subscription still pending'; end if;
end $$;
rollback;
