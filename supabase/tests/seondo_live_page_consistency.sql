-- Manual regression on a connected Daniel's Scale test/production DB.
-- Reads the current live notice and simulates "print cutoff" inside a ROLLBACK.
-- Requires an active SEONDO lead; NEVER stores a real notice or merit allocation.
begin;

select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from public.admins
   where role = 'SEONDO' and is_lead and is_active limit 1),
  true
);

create temporary table _preview_new as
select (j->>'reflection_id')::integer as reflection_id,
       (j->>'pages')::integer as pages
from jsonb_array_elements(public.get_seondo_notice(private.kst_today())->'preview_entries') j
where not (j->>'is_double')::boolean;

do $$
begin
  if exists (select 1 from _preview_new where pages is null or pages <= 0) then
    raise exception 'Live notice entries must have positive calculated pages';
  end if;
  if exists (select 1 from discipline.seondo_notice_batches
             where notice_day = private.kst_today()) then
    raise notice 'A real batch exists; skipping simulated cutoff';
    return;
  end if;
end;
$$;

-- Only run if no real batch for this date, otherwise retain the existing one.
do $$
begin
  if not exists(select 1 from discipline.seondo_notice_batches
                where notice_day = private.kst_today()) then
    perform private.seondo_notice_action_at(false, now());
    if exists (
      select 1 from _preview_new p
      full join discipline.seondo_notice_entries e
        on e.reflection_id = p.reflection_id and not e.is_double
      where (p.reflection_id is null and e.pages > 0)
         or (e.reflection_id is null)
         or (p.pages is distinct from e.pages and e.pages > 0)
    ) then
      raise exception 'Live estimated pages differ from the frozen notice';
    end if;
  end if;
end;
$$;

rollback;
