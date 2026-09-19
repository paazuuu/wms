-- §37 warehouse scope for the eleven read RPCs that never had it.
--
-- 0044-0047 were described as putting warehouse scope into the read RPCs. They
-- put it into the three INDEX functions — `pick_list_index`,
-- `transfer_order_index`, `warehouse_overview` — and that is all. The other
-- eleven wrappers created by 0051 are SECURITY DEFINER with no warehouse
-- predicate anywhere, so they return whatever they are asked for:
--
--   pick_list_detail, transfer_order_detail, inspection_detail,
--   stock_count_detail, bin_stock_overview, default_staging_bin,
--   warehouse_uses_locations, stock_availability, stock_ledger,
--   global_search, dashboard_metrics
--
-- 0053-0055 gated them at each edge-function call site, which closes the app's
-- own path. It does not close the direct one: every wrapper is granted to
-- `authenticated`, so any signed-in user can call
-- `pick_list_detail(<some other warehouse's id>)` straight over PostgREST and
-- read it. This migration puts the check where it cannot be bypassed.
--
-- Two shapes, because two different questions are being asked.
--
-- A. The warehouse is a parameter, or is reachable from an id. The wrapper can
--    answer before delegating, so the guard goes there, next to the
--    has_permission() check 0051 put there — all authorization in the wrapper,
--    all data in the _impl, which stays byte-identical.
--
--      * bin_stock_overview / default_staging_bin / warehouse_uses_locations
--        take a non-null warehouse, so they raise. The message is the shape
--        0046 established and `humanizeApiErrorMessage`'s regex matches
--        (`not permitted: <code> required`), so the client shows its
--        translated "no permission" text rather than raw English.
--      * the four detail functions look the warehouse up from the row and
--        return NULL when it is out of scope, deliberately NOT raising: out of
--        scope has to be indistinguishable from absent, or the error itself
--        tells a caller that a row exists in a warehouse they cannot see. The
--        edge functions already turn a null detail into a 404.
--
-- B. The warehouse is a NULLABLE parameter and null means "every warehouse".
--    A wrapper cannot fix this: narrowing null to a single id would be wrong
--    for an operator scoped to two warehouses, and the _impl only accepts one
--    scalar. So the predicate has to go inside the body, next to the existing
--    `(p_warehouse_id is null or ... = p_warehouse_id)` filter, which then
--    reads "the warehouse asked for, and only if it is mine".
--
--    Those four bodies hold 20 such predicates between them (dashboard_metrics
--    alone has 13 across its CTEs). Rather than restate 10 KB of aggregate SQL
--    here — where a reviewer would have to diff it by eye to see that only the
--    predicates changed — the rewrite is done as a textual transform of what
--    `pg_get_functiondef` returns, and it ASSERTS the number of predicates it
--    found before touching anything. A body that has drifted fails the
--    migration instead of being silently half-scoped.

-- ---------------------------------------------------------------------------
-- A1. Warehouse is a required parameter: check it and refuse.
-- ---------------------------------------------------------------------------

create or replace function public.bin_stock_overview(p_warehouse_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('inventory.view')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return public.bin_stock_overview_impl(p_warehouse_id);
end; $$;

create or replace function public.default_staging_bin(p_warehouse_id bigint)
returns bigint language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('inventory.view')) then
    raise exception 'not permitted: inventory.view required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return public.default_staging_bin_impl(p_warehouse_id);
end; $$;

create or replace function public.warehouse_uses_locations(p_warehouse_id bigint)
returns boolean language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('warehouse.view')) then
    raise exception 'not permitted: warehouse.view required';
  end if;
  if not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return public.warehouse_uses_locations_impl(p_warehouse_id);
end; $$;

-- ---------------------------------------------------------------------------
-- A2. Warehouse comes from the row: return NULL, which reads as "not found".
-- ---------------------------------------------------------------------------

create or replace function public.pick_list_detail(p_pick_list_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('pick.confirm')) then
    raise exception 'not permitted: pick.confirm required';
  end if;
  if not exists (
    select 1 from public.pick_lists l
     where l.id = p_pick_list_id
       and public.can_access_warehouse(l.warehouse_id)
  ) then
    return null;
  end if;
  return public.pick_list_detail_impl(p_pick_list_id);
end; $$;

create or replace function public.inspection_detail(p_inspection_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('inspection.view') or public.has_permission('inspection.confirm')) then
    raise exception 'not permitted: inspection.view required';
  end if;
  if not exists (
    select 1 from public.inspections i
     where i.id = p_inspection_id
       and public.can_access_warehouse(i.warehouse_id)
  ) then
    return null;
  end if;
  return public.inspection_detail_impl(p_inspection_id);
end; $$;

create or replace function public.stock_count_detail(p_count_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('count.perform') or public.has_permission('count.approve')) then
    raise exception 'not permitted: count.perform required';
  end if;
  if not exists (
    select 1 from public.stock_counts c
     where c.id = p_count_id
       and public.can_access_warehouse(c.warehouse_id)
  ) then
    return null;
  end if;
  return public.stock_count_detail_impl(p_count_id);
end; $$;

-- Either end is enough, matching 0052's `transfer_orders_read` policy: the
-- receiving warehouse has to be able to open a transfer it did not raise.
create or replace function public.transfer_order_detail(p_transfer_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('transfer.create') or public.has_permission('transfer.approve') or public.has_permission('transfer.receive')) then
    raise exception 'not permitted: transfer.create required';
  end if;
  if not exists (
    select 1 from public.transfer_orders o
     where o.id = p_transfer_id
       and (public.can_access_warehouse(o.source_warehouse_id)
            or public.can_access_warehouse(o.destination_warehouse_id))
  ) then
    return null;
  end if;
  return public.transfer_order_detail_impl(p_transfer_id);
end; $$;

-- ---------------------------------------------------------------------------
-- B. Nullable warehouse: the predicate has to live in the body, so "every
--    warehouse" becomes "every warehouse I may see".
-- ---------------------------------------------------------------------------

do $mig$
declare
  r record;
  def text;
  newdef text;
  n_simple int;
  n_transfer int;
  -- Anchored on the opening `(p_warehouse_id is null or ` with a literal
  -- space, which is what keeps it from also matching the multi-line
  -- source/destination predicate handled separately below.
  simple_pat constant text :=
    '\(p_warehouse_id is null or ([a-z_]+\.)?warehouse_id = p_warehouse_id\)';
  transfer_pat constant text :=
    '\(p_warehouse_id is null\s+or t\.source_warehouse_id = p_warehouse_id\s+or t\.destination_warehouse_id = p_warehouse_id\)';
  -- How many scope predicates each body is known to contain. A mismatch means
  -- the body changed since this was written, and half-scoping it would be
  -- worse than not running.
  expected constant jsonb := jsonb_build_object(
    'stock_availability_impl', 1,
    'stock_ledger_impl', 1,
    'global_search_impl', 5,
    'dashboard_metrics_impl', 13);
begin
  for r in
    select p.oid, p.proname
      from pg_proc p
      join pg_namespace ns on ns.oid = p.pronamespace
     where ns.nspname = 'public'
       and p.proname in (
         'stock_availability_impl', 'stock_ledger_impl',
         'global_search_impl', 'dashboard_metrics_impl')
     order by p.proname
  loop
    def := pg_get_functiondef(r.oid);
    n_simple := coalesce(array_length(regexp_split_to_array(def, simple_pat), 1), 1) - 1;
    n_transfer := coalesce(array_length(regexp_split_to_array(def, transfer_pat), 1), 1) - 1;

    if n_simple + n_transfer <> (expected ->> r.proname)::int then
      raise exception
        'refusing to rewrite %: found % scope predicates (% simple, % transfer), expected %',
        r.proname, n_simple + n_transfer, n_simple, n_transfer,
        (expected ->> r.proname)::int;
    end if;

    -- \1 is the optional `alias.`; a non-participating group substitutes empty,
    -- which is what the two unqualified `warehouse_id` sites need.
    newdef := regexp_replace(def, simple_pat,
      '(p_warehouse_id is null or \1warehouse_id = p_warehouse_id)'
      || ' and public.can_access_warehouse(\1warehouse_id)', 'g');
    newdef := regexp_replace(newdef, transfer_pat,
      '(p_warehouse_id is null'
      || ' or t.source_warehouse_id = p_warehouse_id'
      || ' or t.destination_warehouse_id = p_warehouse_id)'
      || ' and (public.can_access_warehouse(t.source_warehouse_id)'
      || ' or public.can_access_warehouse(t.destination_warehouse_id))', 'g');

    if newdef = def then
      raise exception 'rewrite of % produced no change', r.proname;
    end if;

    -- `create or replace` keeps the ACL, so the _impl stays ungranted.
    execute newdef;
    raise notice 'scoped %: % predicate(s)', r.proname, n_simple + n_transfer;
  end loop;
end $mig$;
