
-- SkyLogEco — Merge SELECT too and drop duplicates when MERGED_* exists
begin;

-- 1) Build MERGED policies for SELECT in addition to DML
do $$
declare
  r record;
  polname text;
  rolelist text := 'authenticated, service_role';
begin
  for r in
    with cleaned as (
      select
        schemaname,
        tablename,
        lower(cmd) as cmd,
        (coalesce(permissive,'') ilike 'permissive') as is_perm,
        nullif(regexp_replace(trim(qual), '[;[:space:]]+$', '', 'g'), '')       as qual_clean,
        nullif(regexp_replace(trim(with_check), '[;[:space:]]+$', '', 'g'), '') as check_clean
      from pg_policies
    ),
    agg as (
      select
        schemaname, tablename, cmd,
        bool_or(is_perm)                                          as any_perm,
        array_remove(array_agg(qual_clean), null)                 as using_arr,
        array_remove(array_agg(check_clean), null)                as check_arr
      from cleaned
      group by schemaname, tablename, cmd
    )
    select
      schemaname, tablename, cmd,
      coalesce(array_to_string( array(select '('||q||')' from unnest(using_arr) as q), ' OR '), 'true') as using_sql,
      coalesce(array_to_string( array(select '('||q||')' from unnest(check_arr) as q), ' OR '), 'true') as check_sql
    from agg
    where any_perm = true and cmd in ('insert','update','delete','select')
  loop
    polname := format('MERGED_%s_%s',
      r.tablename,
      case r.cmd when 'insert' then 'ins' when 'update' then 'upd' when 'delete' then 'del' else 'sel' end
    );

    if r.cmd = 'insert' then
      execute format('drop policy if exists %I on %I.%I', polname, r.schemaname, r.tablename);
      execute format($f$
        create policy %I on %I.%I
          as permissive for insert
          to %s
          with check (%s)
      $f$, polname, r.schemaname, r.tablename, rolelist, r.check_sql);

    elsif r.cmd = 'update' then
      execute format('drop policy if exists %I on %I.%I', polname, r.schemaname, r.tablename);
      execute format($f$
        create policy %I on %I.%I
          as permissive for update
          to %s
          using (%s)
          with check (%s)
      $f$, polname, r.schemaname, r.tablename, rolelist, r.using_sql, r.check_sql);

    elsif r.cmd = 'delete' then
      execute format('drop policy if exists %I on %I.%I', polname, r.schemaname, r.tablename);
      execute format($f$
        create policy %I on %I.%I
          as permissive for delete
          to %s
          using (%s)
      $f$, polname, r.schemaname, r.tablename, rolelist, r.using_sql);

    elsif r.cmd = 'select' then
      execute format('drop policy if exists %I on %I.%I', polname, r.schemaname, r.tablename);
      execute format($f$
        create policy %I on %I.%I
          as permissive for select
          to %s
          using (%s)
      $f$, polname, r.schemaname, r.tablename, rolelist, r.using_sql);
    end if;
  end loop;
end $$ language plpgsql;

-- 2) Drop duplicate permissive policies when a MERGED_* for same table+cmd exists
do $$
declare
  p record;
begin
  for p in
    with merged as (
      select schemaname, tablename, cmd
      from pg_policies
      where policyname like 'MERGED_%'
    )
    select a.schemaname, a.tablename, a.policyname
    from pg_policies a
    join merged m using (schemaname, tablename, cmd)
    where a.permissive ilike 'permissive'
      and a.policyname not like 'MERGED_%'
  loop
    execute format('drop policy if exists %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$ language plpgsql;

commit;
