-- 0051 — Add the missing permission checks to the read RPCs.
--
-- 0048 stopped these being callable without signing in. This asks the second
-- question: may *this* signed-in user read this? Fourteen `security definer`
-- read RPCs had no `has_permission()` check of any kind, while their siblings
-- (`purchase_order_index`, `sales_order_detail`, `putaway_queue`, ...) all do.
-- So this restores a convention the schema already had rather than inventing
-- one.
--
-- WHY A WRAPPER INSTEAD OF EDITING EACH BODY
--
-- 0043 added its checks by re-creating the functions with the guard inlined.
-- That is fine for a 20-line function and wrong for `dashboard_metrics`, which
-- is ~200 lines of aggregate SQL computing the figures the warehouse runs on.
-- Re-creating it to add four lines means a reviewer has to diff 200 lines of
-- SQL by eye to satisfy themselves nothing else moved, and a single mistyped
-- `sum()` would be silent.
--
-- So each function is renamed to `<name>_impl` and a small plpgsql wrapper
-- takes over its name and signature. `alter function ... rename` keeps the
-- same OID, so the body is provably byte-identical — not re-typed, not
-- re-parsed, not touched. The diff shows only the guard. Callers are
-- unaffected: the wrapper keeps the original name, argument list and
-- defaults, so the client, the edge functions and the three put-away
-- functions that call `warehouse_uses_locations` internally all resolve to it
-- unchanged.
--
-- The `_impl` functions are stripped of every grant (`{postgres=X}` only), so
-- the unguarded version is not reachable through PostgREST at all. Nothing
-- can call one except the wrapper, whose `security definer` body runs as the
-- owner.
--
-- Each wrapper is ALSO explicitly revoked from `public, anon` before being
-- granted. This is not belt-and-braces: `create function` grants EXECUTE to
-- PUBLIC by default, so without it every wrapper here would have re-opened
-- the exact anon hole 0048 closed. A dry run confirmed that — the first
-- attempt came back `anon: true` on all fourteen.
--
-- WHY THESE PERMISSION CODES
--
-- The rule is: match the gate the UI already uses to reach the screen that
-- calls it. Picking a stricter code would lock out operators who can open the
-- screen but not read it — an empty screen with a permission error, which is
-- worse than no check.
--
-- Checking who actually calls each one changed the answer in both directions:
--
--   * Eight are called ONLY from edge functions, on the service-role client.
--     There `auth.uid()` is null, `has_permission()` takes its trusted
--     server-side branch and returns true, so these guards cannot lock out
--     any real flow. Their real user-facing check already lives in the edge
--     function (`require_permission.ts`). The guard here is the second line
--     for someone calling the RPC directly with their own JWT — which is
--     precisely the path that was open.
--
--   * Three are called from the Flutter client with a real user JWT, and all
--     three are reachable from controls every role has: the home dashboard,
--     the top-bar search button, the top-bar scan box. Those get
--     `warehouse.view`, which all 11 roles hold. That gate is deliberately
--     weak-but-correct: it blocks anon (already blocked) and a signed-in user
--     with no role assigned yet, and nothing else. Anything stricter would
--     break the scan box for a packer or shipper, who lack `inventory.view`.
--
-- Where a finer permission genuinely exists and the screen is only reachable
-- through it, the finer code is used — `pick.confirm`, `inspection.view` or
-- `.confirm`, `count.perform` or `.approve`, the three `transfer.*`. There is
-- no `pick.view` / `transfer.view` / `count.view` in the permissions table, so
-- read/write separation for those entities is not expressible today; adding
-- such rows means deciding which roles get them, which is a product decision
-- and not a migration.
--
-- The raise text keeps the `not permitted: <code> required` shape so the
-- client's `humanizeApiErrorMessage` regex turns it into a readable message.
-- Where several codes are accepted, the message names the primary one.
--
-- NOT CHANGED: `bin_by_code` already had its `inventory.view` check and is
-- left exactly as it was.

-- dashboard_metrics -> warehouse.view   (client: home dashboard, audit, search)
alter function public.dashboard_metrics(integer, integer, bigint) rename to dashboard_metrics_impl;
revoke all on function public.dashboard_metrics_impl(integer, integer, bigint) from public, anon, authenticated, service_role;

create function public.dashboard_metrics(p_days integer default 14, p_low_threshold integer default 10, p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('warehouse.view')) then
    raise exception 'not permitted: warehouse.view required';
  end if;
  return public.dashboard_metrics_impl(p_days, p_low_threshold, p_warehouse_id);
end;
$$;

revoke all on function public.dashboard_metrics(integer, integer, bigint) from public, anon;
grant execute on function public.dashboard_metrics(integer, integer, bigint) to authenticated, service_role;

-- global_search -> warehouse.view   (client: top-bar search)
alter function public.global_search(text, bigint, integer) rename to global_search_impl;
revoke all on function public.global_search_impl(text, bigint, integer) from public, anon, authenticated, service_role;

create function public.global_search(p_query text, p_warehouse_id bigint default null, p_limit integer default 8)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('warehouse.view')) then
    raise exception 'not permitted: warehouse.view required';
  end if;
  return public.global_search_impl(p_query, p_warehouse_id, p_limit);
end;
$$;

revoke all on function public.global_search(text, bigint, integer) from public, anon;
grant execute on function public.global_search(text, bigint, integer) to authenticated, service_role;

-- stock_ledger -> warehouse.view   (client: the top-bar scan destination)
alter function public.stock_ledger(text, bigint, integer, text) rename to stock_ledger_impl;
revoke all on function public.stock_ledger_impl(text, bigint, integer, text) from public, anon, authenticated, service_role;

create function public.stock_ledger(p_jan_code text default null, p_warehouse_id bigint default null, p_limit integer default 100, p_scope text default 'WAREHOUSE')
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('warehouse.view')) then
    raise exception 'not permitted: warehouse.view required';
  end if;
  return public.stock_ledger_impl(p_jan_code, p_warehouse_id, p_limit, p_scope);
end;
$$;

revoke all on function public.stock_ledger(text, bigint, integer, text) from public, anon;
grant execute on function public.stock_ledger(text, bigint, integer, text) to authenticated, service_role;

-- stock_availability -> inventory.view   (edge: picking)
alter function public.stock_availability(bigint, text) rename to stock_availability_impl;
revoke all on function public.stock_availability_impl(bigint, text) from public, anon, authenticated, service_role;

create function public.stock_availability(p_warehouse_id bigint default null, p_jan_code text default null)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('inventory.view')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  return public.stock_availability_impl(p_warehouse_id, p_jan_code);
end;
$$;

revoke all on function public.stock_availability(bigint, text) from public, anon;
grant execute on function public.stock_availability(bigint, text) to authenticated, service_role;

-- bin_stock_overview -> inventory.view   (no caller)
alter function public.bin_stock_overview(bigint) rename to bin_stock_overview_impl;
revoke all on function public.bin_stock_overview_impl(bigint) from public, anon, authenticated, service_role;

create function public.bin_stock_overview(p_warehouse_id bigint)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('inventory.view')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  return public.bin_stock_overview_impl(p_warehouse_id);
end;
$$;

revoke all on function public.bin_stock_overview(bigint) from public, anon;
grant execute on function public.bin_stock_overview(bigint) to authenticated, service_role;

-- default_staging_bin -> inventory.view   (no caller)
alter function public.default_staging_bin(bigint) rename to default_staging_bin_impl;
revoke all on function public.default_staging_bin_impl(bigint) from public, anon, authenticated, service_role;

create function public.default_staging_bin(p_warehouse_id bigint)
returns bigint
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('inventory.view')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  return public.default_staging_bin_impl(p_warehouse_id);
end;
$$;

revoke all on function public.default_staging_bin(bigint) from public, anon;
grant execute on function public.default_staging_bin(bigint) to authenticated, service_role;

-- warehouse_uses_locations -> warehouse.view   (nested: confirm_putaway / putaway / putaway_queue)
alter function public.warehouse_uses_locations(bigint) rename to warehouse_uses_locations_impl;
revoke all on function public.warehouse_uses_locations_impl(bigint) from public, anon, authenticated, service_role;

create function public.warehouse_uses_locations(p_warehouse_id bigint)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('warehouse.view')) then
    raise exception 'not permitted: warehouse.view required';
  end if;
  return public.warehouse_uses_locations_impl(p_warehouse_id);
end;
$$;

revoke all on function public.warehouse_uses_locations(bigint) from public, anon;
grant execute on function public.warehouse_uses_locations(bigint) to authenticated, service_role;

-- warehouse_overview -> warehouse.view   (edge: warehouses)
alter function public.warehouse_overview() rename to warehouse_overview_impl;
revoke all on function public.warehouse_overview_impl() from public, anon, authenticated, service_role;

create function public.warehouse_overview()
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('warehouse.view')) then
    raise exception 'not permitted: warehouse.view required';
  end if;
  return public.warehouse_overview_impl();
end;
$$;

revoke all on function public.warehouse_overview() from public, anon;
grant execute on function public.warehouse_overview() to authenticated, service_role;

-- pick_list_index -> pick.confirm   (edge: picking)
alter function public.pick_list_index(bigint, text, integer) rename to pick_list_index_impl;
revoke all on function public.pick_list_index_impl(bigint, text, integer) from public, anon, authenticated, service_role;

create function public.pick_list_index(p_warehouse_id bigint default null, p_status text default null, p_limit integer default 50)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('pick.confirm')) then
    raise exception 'not permitted: pick.confirm required';
  end if;
  return public.pick_list_index_impl(p_warehouse_id, p_status, p_limit);
end;
$$;

revoke all on function public.pick_list_index(bigint, text, integer) from public, anon;
grant execute on function public.pick_list_index(bigint, text, integer) to authenticated, service_role;

-- pick_list_detail -> pick.confirm   (edge: picking)
alter function public.pick_list_detail(bigint) rename to pick_list_detail_impl;
revoke all on function public.pick_list_detail_impl(bigint) from public, anon, authenticated, service_role;

create function public.pick_list_detail(p_pick_list_id bigint)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('pick.confirm')) then
    raise exception 'not permitted: pick.confirm required';
  end if;
  return public.pick_list_detail_impl(p_pick_list_id);
end;
$$;

revoke all on function public.pick_list_detail(bigint) from public, anon;
grant execute on function public.pick_list_detail(bigint) to authenticated, service_role;

-- transfer_order_index -> transfer.create   (edge: transfers)
alter function public.transfer_order_index(bigint, text, integer) rename to transfer_order_index_impl;
revoke all on function public.transfer_order_index_impl(bigint, text, integer) from public, anon, authenticated, service_role;

create function public.transfer_order_index(p_warehouse_id bigint default null, p_status text default null, p_limit integer default 50)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('transfer.create') or public.has_permission('transfer.approve') or public.has_permission('transfer.receive')) then
    raise exception 'not permitted: transfer.create required';
  end if;
  return public.transfer_order_index_impl(p_warehouse_id, p_status, p_limit);
end;
$$;

revoke all on function public.transfer_order_index(bigint, text, integer) from public, anon;
grant execute on function public.transfer_order_index(bigint, text, integer) to authenticated, service_role;

-- transfer_order_detail -> transfer.create   (edge: transfers)
alter function public.transfer_order_detail(bigint) rename to transfer_order_detail_impl;
revoke all on function public.transfer_order_detail_impl(bigint) from public, anon, authenticated, service_role;

create function public.transfer_order_detail(p_transfer_id bigint)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('transfer.create') or public.has_permission('transfer.approve') or public.has_permission('transfer.receive')) then
    raise exception 'not permitted: transfer.create required';
  end if;
  return public.transfer_order_detail_impl(p_transfer_id);
end;
$$;

revoke all on function public.transfer_order_detail(bigint) from public, anon;
grant execute on function public.transfer_order_detail(bigint) to authenticated, service_role;

-- inspection_detail -> inspection.view   (edge: inspections)
alter function public.inspection_detail(bigint) rename to inspection_detail_impl;
revoke all on function public.inspection_detail_impl(bigint) from public, anon, authenticated, service_role;

create function public.inspection_detail(p_inspection_id bigint)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('inspection.view') or public.has_permission('inspection.confirm')) then
    raise exception 'not permitted: inspection.view required';
  end if;
  return public.inspection_detail_impl(p_inspection_id);
end;
$$;

revoke all on function public.inspection_detail(bigint) from public, anon;
grant execute on function public.inspection_detail(bigint) to authenticated, service_role;

-- stock_count_detail -> count.perform   (edge: stock-ops)
alter function public.stock_count_detail(bigint) rename to stock_count_detail_impl;
revoke all on function public.stock_count_detail_impl(bigint) from public, anon, authenticated, service_role;

create function public.stock_count_detail(p_count_id bigint)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not (public.has_permission('count.perform') or public.has_permission('count.approve')) then
    raise exception 'not permitted: count.perform required';
  end if;
  return public.stock_count_detail_impl(p_count_id);
end;
$$;

revoke all on function public.stock_count_detail(bigint) from public, anon;
grant execute on function public.stock_count_detail(bigint) to authenticated, service_role;
