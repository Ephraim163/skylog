-- Fix: has_membership used by RLS policies
create or replace function public.has_membership(p_org uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_orgs u
    where u.user_id = auth.uid()
      and u.org_id = p_org
  );
$$;