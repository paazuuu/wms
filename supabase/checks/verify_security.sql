-- Read-only security verification for the §37 / anon-exposure work
-- (migrations 0048–0053). Safe to paste into the Supabase SQL editor as
-- often as you like: it only SELECTs from the catalogues, it changes
-- nothing. Every row must read "OK".
--
--   1. No business RPC is executable by `anon` (or by PUBLIC, which is the
--      default grant `create function` hands out and the reason each
--      migration revokes from `public, anon` and not just `anon`).
--      my_access / my_roles are excluded on purpose — the sign-in screen
--      calls them before a session exists.
--   2. No SELECT policy is still `using (true)`. Five tables are excluded
--      because they hold no per-warehouse data: companies, roles,
--      permissions, role_permissions, delivery_suppliers.
--   3. Each of the 14 read RPCs is a thin wrapper whose body calls
--      has_permission() before delegating to its _impl (migration 0051).
--   4. No _impl function is reachable by anon, authenticated or
--      service_role — only the guarded wrapper can reach it.
with func_acl as (
  select p.oid, p.proname,
         pg_get_function_identity_arguments(p.oid) as args,
         a.grantee::regrole::text as grantee,
         a.privilege_type
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where n.nspname = 'public'
),
anon_exec as (
  select distinct proname
    from func_acl
   where privilege_type = 'EXECUTE'
     -- '-' is PUBLIC (grantee 0), i.e. the default grant left standing.
     and grantee in ('anon', '-')
     and proname not in ('my_access', 'my_roles')
),
open_policies as (
  select tablename, policyname
    from pg_policies
   where schemaname = 'public' and cmd = 'SELECT' and qual = 'true'
     and tablename not in (
       'companies', 'roles', 'permissions', 'role_permissions', 'delivery_suppliers')
),
impl_reachable as (
  select distinct proname
    from func_acl
   where proname like '%\_impl'
     and privilege_type = 'EXECUTE'
     and grantee in ('anon', 'authenticated', 'service_role', '-')
),
wrappers as (
  select p.proname, p.prosrc like '%has_permission%' as guarded
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and exists (
       select 1 from pg_proc q
         join pg_namespace m on m.oid = q.pronamespace
        where m.nspname = 'public' and q.proname = p.proname || '_impl')
)
select '1. anon-executable business RPCs' as check,
       case when count(*) = 0 then 'OK (0)'
            else 'FAIL: ' || string_agg(proname, ', ') end as result
  from anon_exec
union all
select '2. unscoped SELECT policies (using true)',
       case when count(*) = 0 then 'OK (0)'
            else 'FAIL: ' || string_agg(tablename || '/' || policyname, ', ') end
  from open_policies
union all
select '3. guard wrappers',
       'total ' || count(*) || ', guarded ' || count(*) filter (where guarded) ||
       case when count(*) = count(*) filter (where guarded) then ' -> OK' else ' -> FAIL' end
  from wrappers
union all
select '4. _impl reachable by any client role',
       case when count(*) = 0 then 'OK (0)'
            else 'FAIL: ' || string_agg(proname, ', ') end
  from impl_reachable
order by 1;
