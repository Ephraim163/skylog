-- ====================================================================
--  ⚠️🚨 SQL EXECUTION WARNING — LIVE DATABASE CHANGE 🚨⚠️
--  ENV: SUPABASE / PGADMIN / PSQL
--  READ: Review DROPs/ALTERs. Backup first. Confirm project URL.
-- ====================================================================

set search_path = public;

-- Helper: org_ids from JWT
create or replace function current_user_org_ids()
returns uuid[] language sql stable as $$
  select coalesce(array_agg(elem::uuid), array[]::uuid[])
  from jsonb_array_elements_text(
    coalesce(current_setting('request.jwt.claims', true)::jsonb->'org_ids','[]'::jsonb)
  ) elem;
$$;

-- ORGS (read-only by org)
alter table if exists orgs enable row level security;
drop policy if exists "orgs select same org" on orgs;
create policy "orgs select same org"
on orgs for select to authenticated
using (id = any(current_user_org_ids()));

-- WORK_ORDERS (org-scoped)
alter table if exists work_orders enable row level security;
drop policy if exists "ro_wo"              on work_orders;
drop policy if exists "ro_all"             on work_orders;
drop policy if exists "wo_all"             on work_orders;
drop policy if exists "wo_write"           on work_orders;
drop policy if exists "work_orders_read"   on work_orders;
drop policy if exists "work_orders_write"  on work_orders;
drop policy if exists "wo read same org"   on work_orders;
drop policy if exists "wo insert same org" on work_orders;
drop policy if exists "wo update same org" on work_orders;
drop policy if exists "wo delete same org" on work_orders;

create policy "wo read same org"
on work_orders for select to authenticated
using (org_id = any(current_user_org_ids()));

create policy "wo insert same org"
on work_orders for insert to authenticated
with check (org_id = any(current_user_org_ids()));

create policy "wo update same org"
on work_orders for update to authenticated
using     (org_id = any(current_user_org_ids()))
with check(org_id = any(current_user_org_ids()));

create policy "wo delete same org"
on work_orders for delete to authenticated
using (org_id = any(current_user_org_ids()));

-- STAFF (org-scoped)
alter table if exists staff enable row level security;
drop policy if exists "staff_all"              on staff;
drop policy if exists "staff_mod"              on staff;
drop policy if exists "staff_insert"           on staff;
drop policy if exists "ro_staff"               on staff;
drop policy if exists "staff_read"             on staff;
drop policy if exists "staff_sel"              on staff;
drop policy if exists "staff read same org"    on staff;
drop policy if exists "staff insert same org"  on staff;
drop policy if exists "staff update same org"  on staff;

create policy "staff read same org"
on staff for select to authenticated
using (org_id = any(current_user_org_ids()));

create policy "staff insert same org"
on staff for insert to authenticated
with check (org_id = any(current_user_org_ids()));

create policy "staff update same org"
on staff for update to authenticated
using     (org_id = any(current_user_org_ids()))
with check(org_id = any(current_user_org_ids()));

-- Idempotent indexes + defaults
create index if not exists idx_wo_org    on work_orders(org_id);
create index if not exists idx_staff_org on staff(org_id);
alter table if exists work_orders alter column created_at set default now();
