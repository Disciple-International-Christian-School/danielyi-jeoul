-- Project defaults explicitly grant anon EXECUTE, independently of PUBLIC.
revoke all on function public.homeroom_portal(), public.register_homeroom_push(jsonb),
 public.disable_homeroom_push(text), public.test_homeroom_push(text) from anon;
revoke all on function private.current_homeroom_staff() from anon,authenticated;
