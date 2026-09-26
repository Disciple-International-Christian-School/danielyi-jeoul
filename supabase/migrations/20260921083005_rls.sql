-- daniels-scale: row-level security
-- RLS is the authorization layer (spec §3, §30). UI hiding is cosmetic.
-- Roles: SEONDO (선도부) manages students/items/records/reflections,
--        SASAENG (사생회) manages punishments. Both read everything.
-- The client only ever holds the publishable key; never service_role.

-- security definer so the admins-table policy can consult admins without
-- recursing into its own policy. Kept in `private` (not exposed via PostgREST).
create or replace function private.current_admin_role()
returns public.admin_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.admins where user_id = (select auth.uid())
$$;

grant execute on function private.current_admin_role() to authenticated;

alter table public.admins enable row level security;
alter table public.students enable row level security;
alter table public.point_items enable row level security;
alter table public.point_records enable row level security;
alter table public.reflection_records enable row level security;
alter table public.punishments enable row level security;

-- ---------------------------------------------------------------- reads (any admin)
create policy admins_read on public.admins
  for select to authenticated
  using (private.current_admin_role() is not null);

create policy students_read on public.students
  for select to authenticated
  using (private.current_admin_role() is not null);

create policy point_items_read on public.point_items
  for select to authenticated
  using (private.current_admin_role() is not null);

create policy point_records_read on public.point_records
  for select to authenticated
  using (private.current_admin_role() is not null);

create policy reflection_records_read on public.reflection_records
  for select to authenticated
  using (private.current_admin_role() is not null);

create policy punishments_read on public.punishments
  for select to authenticated
  using (private.current_admin_role() is not null);

-- ---------------------------------------------------------------- SEONDO writes
-- Soft deletes are updates (deleted_at); no DELETE policies exist anywhere,
-- so history can never be hard-deleted from the client (spec §21).
create policy students_write on public.students
  for insert to authenticated
  with check (private.current_admin_role() = 'SEONDO');
create policy students_update on public.students
  for update to authenticated
  using (private.current_admin_role() = 'SEONDO')
  with check (private.current_admin_role() = 'SEONDO');

create policy point_items_write on public.point_items
  for insert to authenticated
  with check (private.current_admin_role() = 'SEONDO');
create policy point_items_update on public.point_items
  for update to authenticated
  using (private.current_admin_role() = 'SEONDO')
  with check (private.current_admin_role() = 'SEONDO');

create policy point_records_write on public.point_records
  for insert to authenticated
  with check (private.current_admin_role() = 'SEONDO');
create policy point_records_update on public.point_records
  for update to authenticated
  using (private.current_admin_role() = 'SEONDO')
  with check (private.current_admin_role() = 'SEONDO');

-- reflection rows are inserted by the point_records trigger, which runs as the
-- invoking user — SEONDO therefore needs insert rights here too.
create policy reflection_records_write on public.reflection_records
  for insert to authenticated
  with check (private.current_admin_role() = 'SEONDO');
create policy reflection_records_update on public.reflection_records
  for update to authenticated
  using (private.current_admin_role() = 'SEONDO')
  with check (private.current_admin_role() = 'SEONDO');

-- ---------------------------------------------------------------- SASAENG writes
create policy punishments_write on public.punishments
  for insert to authenticated
  with check (private.current_admin_role() = 'SASAENG');
create policy punishments_update on public.punishments
  for update to authenticated
  using (private.current_admin_role() = 'SASAENG')
  with check (private.current_admin_role() = 'SASAENG');
