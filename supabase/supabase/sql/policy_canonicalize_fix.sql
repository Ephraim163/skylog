-- Create canonical org-based policies on six tables
do $$
declare t text;
begin
  FOREACH t IN ARRAY ARRAY['work_orders','staff','audits','tools','rii','crs'] LOOP
    execute format('drop policy if exists org_isolation_select on public.%I', t);
    execute format('drop policy if exists org_isolation_write  on public.%I', t);
    execute format('drop policy if exists org_isolation_update on public.%I', t);
    execute format('drop policy if exists org_isolation_delete on public.%I', t);

    execute format($q$create policy org_isolation_select on public.%I
      for select to authenticated, service_role using (org_id = any (current_user_org_ids()))$q$, t);

    execute format($q$create policy org_isolation_write on public.%I
      for insert to authenticated, service_role with check (org_id = any (current_user_org_ids()))$q$, t);

    execute format($q$create policy org_isolation_update on public.%I
      for update to authenticated, service_role
      using (org_id = any (current_user_org_ids()))
      with check (org_id = any (current_user_org_ids()))$q$, t);

    execute format($q$create policy org_isolation_delete on public.%I
      for delete to authenticated, service_role using (org_id = any (current_user_org_ids()))$q$, t);
  END LOOP;
end$$;
