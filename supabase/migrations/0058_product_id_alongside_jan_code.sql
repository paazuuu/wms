-- Phase A, step 3 of the identity work: put `product_id` alongside `jan_code`
-- on every table that keys stock or a document line by JAN text.
--
-- 0057 gave a product a stable id and a set of barcode aliases. Nothing used
-- it yet. This migration adds the column that will eventually replace
-- `jan_code` as the join key, on all sixteen tables that carry one:
--
--   stock_levels, bin_stock, stock_movements, stock_adjustments,
--   pick_tasks, inspection_items, reconciliation_lines, stock_count_lines,
--   transfer_order_lines, shipment_lines, shipment_carton_items,
--   delivery_plan_lines, purchase_order_lines, sales_order_lines,
--   work_order_components, putaway_confirmations
--
-- This is the 併走 (run-in-parallel) step, not the switch-over. `jan_code`
-- keeps its name, its type, its place in two primary keys
-- (`stock_levels (warehouse_id, jan_code)`, `bin_stock (bin_id, jan_code)`)
-- and every RPC signature. Nothing reads `product_id` yet. Reads move over
-- once the column is populated and trusted, which is a later step and a
-- reversible one.
--
-- WHY NULLABLE, AND WHY NOTHING IS AUTO-CREATED
--
-- `products` is empty, and today's write paths do not require a product to
-- exist: `adjust_stock(p_jan_code, p_product_name)` will happily create a
-- stock level for a JAN nobody registered, carrying a free-text name. That is
-- exactly the "stock CRUD" shape §3 and §11 move away from, but it is also
-- how the app works right now, and a NOT NULL column would break every one of
-- those paths on the spot.
--
-- So `product_id` is nullable and resolution is best-effort. What this
-- migration deliberately does NOT do is invent a product when a scan presents
-- an unknown JAN. Auto-creating master data from a barcode is how a product
-- table fills up with "4901234567890 / (unnamed)" rows, and §30's rule — AI and
-- scans produce candidates, humans confirm domain data — applies just as much
-- to a barcode as to OCR. Instead the gap is made visible:
-- `unlinked_jan_codes()` lists the codes in use that no product accounts for,
-- so someone can register them, and `link_products_by_jan()` (also fired
-- whenever a product is created) links the history that was already there.

-- ---------------------------------------------------------------------------
-- 1. The resolver: JAN text -> product id
-- ---------------------------------------------------------------------------

-- Tries the alias table first, so an EAN, a case code or an internal SKU
-- resolves as readily as the JAN itself — that is the point of 0057. Falls back
-- to `products.jan_code` for a product whose primary alias has somehow not been
-- created. Returns null for a code no product accounts for; that is a normal
-- answer here, not an error.
--
-- No company parameter: there is one company, and `product_barcodes` is unique
-- per company, so the lookup is unambiguous. When a second company arrives this
-- gains a parameter and the callers below pass it — which is why the callers all
-- go through this one function.
create or replace function public.product_for_jan(p_jan_code text)
returns bigint
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select b.product_id
       from public.product_barcodes b
      where b.barcode = public.normalize_barcode(p_jan_code)
      limit 1),
    (select p.id
       from public.products p
      where p.jan_code = p_jan_code
      limit 1));
$$;

revoke all on function public.product_for_jan(text) from public, anon;
grant execute on function public.product_for_jan(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Add the column, the foreign key, the index and the fill trigger
-- ---------------------------------------------------------------------------

-- Fills `product_id` from `jan_code` on write, and only when the caller did not
-- supply one — an explicit product_id always wins, so a future caller that
-- knows the product does not get second-guessed by a text lookup.
create or replace function public.fill_product_id()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.product_id is null and new.jan_code is not null then
    new.product_id := public.product_for_jan(new.jan_code);
  end if;
  return new;
end;
$$;

revoke all on function public.fill_product_id() from public, anon;

-- One loop rather than sixty-four hand-written statements: every one of these
-- tables gets exactly the same treatment, and a loop cannot apply it to
-- fifteen of them and quietly skip the sixteenth. The list is explicit (not
-- "every table with a jan_code") so adding a table is a decision someone makes
-- here, and the loop asserts each one actually has both columns before it
-- touches anything.
do $mig$
declare
  t text;
  tables constant text[] := array[
    'stock_levels', 'bin_stock', 'stock_movements', 'stock_adjustments',
    'pick_tasks', 'inspection_items', 'reconciliation_lines',
    'stock_count_lines', 'transfer_order_lines', 'shipment_lines',
    'shipment_carton_items', 'delivery_plan_lines', 'purchase_order_lines',
    'sales_order_lines', 'work_order_components', 'putaway_confirmations'
  ];
begin
  foreach t in array tables loop
    if not exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = t and column_name = 'jan_code'
    ) then
      raise exception '%.jan_code does not exist — refusing to add product_id to it', t;
    end if;

    execute format(
      'alter table public.%I add column if not exists product_id bigint', t);

    -- `restrict`, not `cascade` or `set null`: §37-4 says history is not
    -- balanced by deleting it, and detaching a movement from its product is a
    -- quieter version of the same thing. A product with history cannot be
    -- deleted, which is already true in practice — the app only deactivates.
    if not exists (
      select 1 from pg_constraint
       where conrelid = format('public.%I', t)::regclass
         and conname = t || '_product_id_fkey'
    ) then
      execute format(
        'alter table public.%I add constraint %I foreign key (product_id) '
        'references public.products (id) on delete restrict',
        t, t || '_product_id_fkey');
    end if;

    execute format(
      'create index if not exists %I on public.%I (product_id)',
      t || '_product_id_idx', t);

    execute format('drop trigger if exists %I on public.%I',
      t || '_fill_product_id', t);
    execute format(
      'create trigger %I before insert or update of jan_code, product_id '
      'on public.%I for each row execute function public.fill_product_id()',
      t || '_fill_product_id', t);
  end loop;
end $mig$;

-- ---------------------------------------------------------------------------
-- 3. Linking history, forwards and backwards
-- ---------------------------------------------------------------------------

-- Re-resolve every row that has no product yet. Safe to run repeatedly: it only
-- touches rows where `product_id is null`, and it cannot unlink anything.
-- Returns how many rows it linked per table so a caller can see what happened.
--
-- Not gated on a permission because it is called from the products trigger
-- below, where there is no caller to check; it is service-role-only instead
-- (no grant to `authenticated`), which is the same posture as every other
-- mutation in this database.
create or replace function public.link_products_by_jan(p_product_id bigint default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  t text;
  tables constant text[] := array[
    'stock_levels', 'bin_stock', 'stock_movements', 'stock_adjustments',
    'pick_tasks', 'inspection_items', 'reconciliation_lines',
    'stock_count_lines', 'transfer_order_lines', 'shipment_lines',
    'shipment_carton_items', 'delivery_plan_lines', 'purchase_order_lines',
    'sales_order_lines', 'work_order_components', 'putaway_confirmations'
  ];
  n bigint;
  result jsonb := '{}'::jsonb;
begin
  foreach t in array tables loop
    if p_product_id is null then
      execute format(
        'update public.%I s
            set product_id = public.product_for_jan(s.jan_code)
          where s.product_id is null
            and s.jan_code is not null
            and public.product_for_jan(s.jan_code) is not null', t);
    else
      -- Scoped to one product: match its own codes rather than resolving every
      -- row's code and comparing. That keeps the products trigger an indexed
      -- lookup, and evaluates the resolver not at all.
      execute format(
        'update public.%I s
            set product_id = $1
          where s.product_id is null
            and s.jan_code is not null
            and (public.normalize_barcode(s.jan_code) in (
                   select b.barcode from public.product_barcodes b
                    where b.product_id = $1)
                 or s.jan_code = (select p.jan_code from public.products p
                                   where p.id = $1))', t)
        using p_product_id;
    end if;
    get diagnostics n = row_count;
    if n > 0 then
      result := result || jsonb_build_object(t, n);
    end if;
  end loop;
  return result;
end;
$$;

revoke all on function public.link_products_by_jan(bigint) from public, anon, authenticated;
grant execute on function public.link_products_by_jan(bigint) to service_role;

-- Registering a product links the history that was already using its code.
-- This is what makes "register the master data later" a workable answer rather
-- than a permanent gap: receive stock today under a bare JAN, register the
-- product next week, and the movements, plan lines and counts link themselves.
create or replace function public.link_history_on_product_insert()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  perform public.link_products_by_jan(new.id);
  return null;
end;
$$;

revoke all on function public.link_history_on_product_insert() from public, anon;

-- After the 0057 barcode trigger, so the primary alias exists by the time
-- product_for_jan() is asked. Trigger order within the same event is
-- alphabetical by trigger name, and `products_primary_barcode` sorts before
-- `products_zz_link_history` — hence the name.
drop trigger if exists products_zz_link_history on public.products;
create trigger products_zz_link_history
  after insert on public.products
  for each row execute function public.link_history_on_product_insert();

-- Backfill for rows that already exist. `delivery_plan_lines` holds 69 of them
-- and every other table is empty; `products` is empty too, so this links
-- nothing today. It is here so a database rebuilt from this history, or one
-- that gains products before this migration, ends in the same place.
do $backfill$ begin perform public.link_products_by_jan(); end $backfill$;

-- ---------------------------------------------------------------------------
-- 4. Make the gap visible instead of silent
-- ---------------------------------------------------------------------------

-- Which codes are in use that no product accounts for, and where. This is the
-- worklist for registering master data, and the measure of how far the
-- switch-over is from being safe: when this returns nothing, `product_id` is
-- as complete as `jan_code` and reads can start moving over.
create or replace function public.unlinked_jan_codes(p_limit integer default 200)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not (public.has_permission('product.view')
          or public.has_permission('inventory.view')) then
    raise exception 'not permitted: product.view required';
  end if;

  return coalesce((
    select jsonb_agg(row_to_json(x)::jsonb order by x.total_rows desc, x.jan_code)
      from (
        select jan_code,
               max(product_name) filter (where product_name is not null
                                           and product_name <> '') as seen_as,
               sum(n) as total_rows,
               jsonb_object_agg(src, n) as sources
          from (
            select jan_code, product_name, 'stock_levels' as src, count(*) as n
              from public.stock_levels where product_id is null group by 1,2
            union all
            select jan_code, product_name, 'bin_stock', count(*)
              from public.bin_stock where product_id is null group by 1,2
            union all
            select jan_code, product_name, 'stock_movements', count(*)
              from public.stock_movements where product_id is null group by 1,2
            union all
            select jan_code, product_name, 'delivery_plan_lines', count(*)
              from public.delivery_plan_lines where product_id is null group by 1,2
            union all
            select jan_code, product_name, 'shipment_lines', count(*)
              from public.shipment_lines where product_id is null group by 1,2
            union all
            select jan_code, product_name, 'pick_tasks', count(*)
              from public.pick_tasks where product_id is null group by 1,2
            union all
            select jan_code, product_name, 'stock_count_lines', count(*)
              from public.stock_count_lines where product_id is null group by 1,2
            union all
            select jan_code, product_name, 'inspection_items', count(*)
              from public.inspection_items where product_id is null group by 1,2
          ) parts
         where jan_code is not null and jan_code <> ''
         group by jan_code
         order by sum(n) desc, jan_code
         limit greatest(coalesce(p_limit, 200), 1)
      ) x),
    '[]'::jsonb);
end;
$$;

revoke all on function public.unlinked_jan_codes(integer) from public, anon;
grant execute on function public.unlinked_jan_codes(integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. How complete is the parallel column?
-- ---------------------------------------------------------------------------

-- Per-table linked/unlinked counts. The switch-over criterion in one call:
-- every row with a jan_code also has a product_id.
create or replace function public.product_id_coverage()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  t text;
  tables constant text[] := array[
    'stock_levels', 'bin_stock', 'stock_movements', 'stock_adjustments',
    'pick_tasks', 'inspection_items', 'reconciliation_lines',
    'stock_count_lines', 'transfer_order_lines', 'shipment_lines',
    'shipment_carton_items', 'delivery_plan_lines', 'purchase_order_lines',
    'sales_order_lines', 'work_order_components', 'putaway_confirmations'
  ];
  total bigint;
  linked bigint;
  result jsonb := '{}'::jsonb;
  grand_total bigint := 0;
  grand_linked bigint := 0;
begin
  if not (public.has_permission('product.view')
          or public.has_permission('inventory.view')) then
    raise exception 'not permitted: product.view required';
  end if;

  foreach t in array tables loop
    execute format(
      'select count(*), count(product_id) from public.%I where jan_code is not null', t)
      into total, linked;
    grand_total := grand_total + total;
    grand_linked := grand_linked + linked;
    if total > 0 then
      result := result || jsonb_build_object(t,
        jsonb_build_object('rows', total, 'linked', linked,
                           'unlinked', total - linked));
    end if;
  end loop;

  return jsonb_build_object(
    'tables', result,
    'rows', grand_total,
    'linked', grand_linked,
    'unlinked', grand_total - grand_linked,
    'ready_to_switch', grand_total = grand_linked);
end;
$$;

revoke all on function public.product_id_coverage() from public, anon;
grant execute on function public.product_id_coverage() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. Trigger functions are not client-callable, uniformly
-- ---------------------------------------------------------------------------

-- Postgres refuses a direct call to a trigger function ("trigger functions can
-- only be called as triggers"), so a grant to anon or authenticated is inert —
-- but it is inert in a way a reviewer has to stop and verify. This makes the
-- whole set uniform, including `fill_default_warehouse` from 0050, which still
-- carried the default grant. verify_security.sql check 10 keeps it that way,
-- which matters because Phase A will add more triggers.
do $tighten$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $tighten$;
