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
--   5. No write policy (INSERT/UPDATE/DELETE) is still `true`. 0052 only
--      touched SELECT; 0054 scoped the three writes it left open.
--   6. The two audit readers scope by warehouse (0055). They are SECURITY
--      DEFINER, so `audit_log`'s own policy never applies and the predicate
--      in the body is the only thing standing between an auditor and every
--      warehouse's trail.
--   7. Every mutation RPC is still service_role-only. This is what makes the
--      edge functions the single gate in front of them — if one of these ever
--      became executable by `authenticated`, it would be reachable straight
--      over PostgREST with no permission and no warehouse check at all.
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
),
open_write_policies as (
  select tablename, policyname, cmd
    from pg_policies
   where schemaname = 'public' and cmd <> 'SELECT'
     and (coalesce(qual, 'true') = 'true' and coalesce(with_check, 'true') = 'true')
),
audit_readers as (
  select p.proname, p.prosrc like '%can_access_warehouse%' as scoped
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('audit_log_query', 'audit_event_types')
),
-- The mutation RPCs the edge functions call on the service role. If any of
-- these becomes executable by `authenticated`, the gate is gone.
mutation_rpcs(proname) as (values
  ('ship_plan'), ('cancel_shipment'), ('adjust_stock'), ('record_pick'),
  ('start_pick_list'), ('complete_pick_list'), ('cancel_pick_list'),
  ('start_inspection'), ('save_inspection_item'), ('complete_inspection'),
  ('start_stock_count'), ('record_count_line'), ('complete_stock_count'),
  ('cancel_stock_count'), ('create_transfer_order'), ('submit_transfer_order'),
  ('approve_transfer_order'), ('reject_transfer_order'),
  ('cancel_transfer_order'), ('start_transfer_picking'),
  ('complete_transfer_picking'), ('start_transfer_receiving'),
  ('record_transfer_pick'), ('record_transfer_receipt'),
  ('complete_transfer_receiving'), ('reconcile_delivery_plan'),
  ('cancel_reconciliation'), ('log_audit')
),
client_reachable_mutations as (
  select m.proname
    from mutation_rpcs m
    join pg_proc p on p.proname = m.proname
    join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'public'
   where has_function_privilege('authenticated', p.oid, 'execute')
      or has_function_privilege('anon', p.oid, 'execute')
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
union all
select '5. write policies still open (using/check true)',
       case when count(*) = 0 then 'OK (0)'
            else 'FAIL: ' || string_agg(tablename || ' ' || cmd || '/' || policyname, ', ') end
  from open_write_policies
union all
select '6. audit readers scoped by warehouse',
       'total ' || count(*) || ', scoped ' || count(*) filter (where scoped) ||
       case when count(*) = 2 and count(*) = count(*) filter (where scoped)
            then ' -> OK' else ' -> FAIL' end
  from audit_readers
union all
select '7. mutation RPCs reachable by a client role',
       case when count(*) = 0 then 'OK (0)'
            else 'FAIL: ' || string_agg(proname, ', ') end
  from client_reachable_mutations
order by 1;
