-- Run only on an isolated database after the November hybrid transition migration.
-- All writes (including the simulated closeout) are rolled back.
begin;

insert into discipline.seondo_policy (singleton, starts_at)
values (true, timestamptz '2026-11-18 00:00+09');

-- A policy-activation day after Nov 16 must still include the full Nov 16 week.
select private.seondo_finalize(timestamptz '2026-11-30 23:59+09');

do $$
begin
  if (select count(*) from discipline.seondo_closures
      where kind='WEEKLY' and period_start in (date '2026-11-16',date '2026-11-23')) <> 2 then
    raise exception 'The two new-policy November weeks did not close';
  end if;
  if exists(select 1 from discipline.seondo_closures
      where kind='MONTHLY' and period_start=date '2026-11-01') then
    raise exception 'Unapproved old-policy history must block November committee referrals';
  end if;
  if exists(select 1 from discipline.seondo_monthly_committee
      where month_start=date '2026-11-01') then
    raise exception 'Premature November committee rows were created';
  end if;
end;
$$;

-- December is independent of the previous month's pending approval.
select private.seondo_finalize(timestamptz '2026-12-31 23:59+09');

do $$
begin
  if not exists(select 1 from discipline.seondo_closures
      where kind='MONTHLY' and period_start=date '2026-12-01') then
    raise exception 'December should finalize even if November history awaits review';
  end if;
  if exists(select 1 from discipline.seondo_monthly_committee
      where month_start=date '2026-12-01' and grade between 1 and 6) then
    raise exception 'Elementary students must not enter the monthly committee roster';
  end if;
end;
$$;

rollback;
