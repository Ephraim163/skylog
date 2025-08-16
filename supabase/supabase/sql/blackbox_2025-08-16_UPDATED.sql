/*
===========================================================
 BlackBox: Smoke Suite Reset & Reseed
 Generated: 2025-08-16 01:44:08Z UTC
===========================================================

This script consolidates all work from the session:
- Removes legacy functions and views
- Enforces dedup + uniqueness for Staff smoke badge
- Defines final functions:
    1) reseed_smoke_suite(p_org uuid, p_prefix text)
    2) reset_all_smoke(p_org uuid, p_prefix text default 'SMOKE')
- (Optional) status view for ad-hoc verification

SAFE TO RUN MULTIPLE TIMES.
*/

-- =======================================================
-- 0) Session safety (optional)
-- =======================================================
-- set search_path to public;

-- =======================================================
-- 1) Drop legacy objects (safe)
-- =======================================================
drop view if exists smoke_suite_status;
drop function if exists run_smoke_status();

drop function if exists reset_smoke_suite();
drop function if exists reset_smoke_suite_v4(uuid, text);
drop function if exists reset_smoke_suite_v5(uuid, text);

drop function if exists cleanup_all_suites(uuid);
drop function if exists cleanup_all_suites(uuid, text);

drop function if exists reseed_smoke_suite(uuid);
drop function if exists reset_all_smoke();
drop function if exists reset_all_smoke(uuid);
drop function if exists reset_all_smoke(uuid, text);

-- =======================================================
-- 2) One-time dedup + uniqueness guard for Staff
--    Keeps exactly one 'ST-SMOKE' per org and enforces unique constraint.
-- =======================================================

-- Deduplicate existing SMOKE staff (keep one per (org, badge_no))
with ranked as (
  select id, org_id, badge_no,
         row_number() over (partition by org_id, badge_no order by id) as rn
  from staff
  where badge_no like 'ST-SMOKE%'
)
delete from staff s
using ranked r
where s.id = r.id and r.rn > 1;

-- Add a uniqueness constraint if not already present
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'staff_org_badge_uidx'
  ) then
    alter table staff
      add constraint staff_org_badge_uidx unique (org_id, badge_no);
  end if;
end;
$$;

-- =======================================================
-- 3) Final reseed function
--    Inserts exactly one set: WO, Staff, CRS, RII, Tool, Audit
--    Uses on conflict do nothing for idempotency
-- =======================================================
create or replace function reseed_smoke_suite(p_org uuid, p_prefix text)
returns table(phase text, item text, count int)
language plpgsql
as $$
begin
  -- Work Order
  insert into work_orders (id, org_id)
  values ('WO-'||p_prefix, p_org)
  on conflict do nothing;

  -- Staff
  insert into staff (id, org_id, name, badge_no)
  values (gen_random_uuid(), p_org, 'Smoke Tester', 'ST-'||p_prefix)
  on conflict do nothing;

  -- CRS
  insert into crs (id, org_id, work_order_id)
  values ('CRS-'||p_prefix, p_org, 'WO-'||p_prefix)
  on conflict do nothing;

  -- RII
  insert into rii (id, org_id, work_order_id)
  values ('RII-'||p_prefix, p_org, 'WO-'||p_prefix)
  on conflict do nothing;

  -- Tools (schema does not include work_order_id)
  insert into tools (id, org_id, name)
  values ('TL-'||p_prefix, p_org, 'Smoke Line Audit Tool')
  on conflict do nothing;

  -- Audits (remarks column not present; use scope/due/corrective_action)
  insert into audits (id, org_id, work_order_id, scope, due, corrective_action)
  values ('AUDIT-'||p_prefix, p_org, 'WO-'||p_prefix, 'general', now(), 'None')
  on conflict do nothing;

  -- Return reseed counts
  return query
  select 'reseed','Work Order',count(*)::int from work_orders where id='WO-'||p_prefix and org_id=p_org
  union all select 'reseed','Staff',count(*)::int from staff where badge_no='ST-'||p_prefix and org_id=p_org
  union all select 'reseed','CRS',count(*)::int from crs where id='CRS-'||p_prefix and org_id=p_org
  union all select 'reseed','RII',count(*)::int from rii where id='RII-'||p_prefix and org_id=p_org
  union all select 'reseed','Tool',count(*)::int from tools where id='TL-'||p_prefix and org_id=p_org
  union all select 'reseed','Audit',count(*)::int from audits where id='AUDIT-'||p_prefix and org_id=p_org;
end;
$$;

-- =======================================================
-- 4) Final reset function
--    1) Cleanup deletes by prefix
--    2) Return cleanup counts (post-delete remaining = expected 0)
--    3) Call reseed and return reseed counts
-- =======================================================
create or replace function reset_all_smoke(p_org uuid, p_prefix text default 'SMOKE')
returns table(phase text, item text, count int)
language plpgsql
as $$
begin
  -- Cleanup deletes
  delete from audits where id like 'AUDIT-'||p_prefix||'%' and org_id=p_org;
  delete from tools  where id like 'TL-'   ||p_prefix||'%' and org_id=p_org;
  delete from rii    where id like 'RII-'  ||p_prefix||'%' and org_id=p_org;
  delete from crs    where id like 'CRS-'  ||p_prefix||'%' and org_id=p_org;
  delete from staff  where badge_no = 'ST-'||p_prefix and org_id=p_org;
  delete from work_orders where id = 'WO-'||p_prefix and org_id=p_org;

  -- Cleanup status (remaining counts, typically zeros)
  return query
  select 'cleanup','Audits',count(*)::int from audits where id like 'AUDIT-'||p_prefix||'%' and org_id=p_org
  union all select 'cleanup','Tools',count(*)::int from tools where id like 'TL-'||p_prefix||'%' and org_id=p_org
  union all select 'cleanup','RII',count(*)::int from rii where id like 'RII-'||p_prefix||'%' and org_id=p_org
  union all select 'cleanup','CRS',count(*)::int from crs where id like 'CRS-'||p_prefix||'%' and org_id=p_org
  union all select 'cleanup','Staff',count(*)::int from staff where badge_no='ST-'||p_prefix and org_id=p_org
  union all select 'cleanup','Work Orders',count(*)::int from work_orders where id='WO-'||p_prefix and org_id=p_org;

  -- Reseed
  return query
  select * from reseed_smoke_suite(p_org, p_prefix);
end;
$$;

-- =======================================================
-- 5) Optional: Status view (uncomment to create)
--    Counts existing SMOKE items without running reset
-- =======================================================
-- create or replace view smoke_suite_status as
-- select 'Work Order' as item, count(*) as existing from work_orders where id='WO-SMOKE'
-- union all select 'Staff', count(*) from staff where badge_no='ST-SMOKE'
-- union all select 'CRS', count(*) from crs where id='CRS-SMOKE'
-- union all select 'RII', count(*) from rii where id='RII-SMOKE'
-- union all select 'Tool', count(*) from tools where id='TL-SMOKE'
-- union all select 'Audit', count(*) from audits where id='AUDIT-SMOKE';

-- =======================================================
-- 6) Usage examples (replace with your org UUID)
-- =======================================================
-- select * from reset_all_smoke('17dfbe07-06bf-4770-8a41-08243561fa11'::uuid);           -- default 'SMOKE'
-- select * from reset_all_smoke('17dfbe07-06bf-4770-8a41-08243561fa11'::uuid, 'SMOKE');
-- select * from reseed_smoke_suite('17dfbe07-06bf-4770-8a41-08243561fa11'::uuid, 'SMOKE');
