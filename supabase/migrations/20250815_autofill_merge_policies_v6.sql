
-- SkyLogEco — Auto-merge permissive policies (v6: use string_agg, no array/unnest)
begin;

create or replace function public.current_user_org_ids()
returns uuid[]
language sql
stable
security definer
as $$
  select coalesce(
    (select array_agg((j)#>>'{}')
       from jsonb_array_elements( coalesce( nullif(current_setting('request.jwt.claims', true), '' )::jsonb -> 'org_ids', '[]'::jsonb) ) as j),
    '{}'
  )::uuid[];
$$;

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
        bool_or(is_perm)                                                as any_perm,
        nullif(string_agg(qual_clean, ' OR '), '')                      as using_sql,
        nullif(string_agg(check_clean, ' OR '), '')                     as check_sql
      from cleaned
      group by schemaname, tablename, cmd
    )
    select
      schemaname,
      tablename,
      cmd,
      coalesce(using_sql, 'true')  as using_sql,
      coalesce(check_sql, 'true')  as check_sql
    from agg
    where any_perm = true and cmd in ('insert','update','delete')
  loop
    polname := format('MERGED_%s_%s', r.tablename, case r.cmd when 'insert' then 'ins' when 'update' then 'upd' else 'del' end);

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
    end if;
  end loop;
end $$ language plpgsql;

commit;
