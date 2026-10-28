-- Grade-routing regression: no student data is changed.
begin;
do $test$
begin
  if exists(select 1 from public.v_reflections where grade=9 and assigned_scope <> 'HIGH'::public.discipline_scope) then raise exception 'G9 reflection scope must be HIGH'; end if;
  if exists(select 1 from public.v_reflections where grade between 7 and 8 and assigned_scope <> 'MIDDLE'::public.discipline_scope) then raise exception 'G7-G8 reflection scope must be MIDDLE'; end if;
  if exists(select 1 from public.v_reflections where grade between 10 and 12 and assigned_scope <> 'HIGH'::public.discipline_scope) then raise exception 'G10-G12 reflection scope must stay HIGH'; end if;
  if position('i.grade between 7 and 8' in pg_get_functiondef('private.discipline_history(uuid,date,date)'::regprocedure))=0 or position('i.grade between 9 and 12' in pg_get_functiondef('private.discipline_history(uuid,date,date)'::regprocedure))=0 then raise exception 'History RPC grade scope mismatch'; end if;
end $test$;
select 'G9 HIGH / G7-G8 MIDDLE / history RPC passed' result;
rollback;
