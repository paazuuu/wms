-- 0202: 出荷内容の変更 — a list not shipped yet (出庫予定, or 在庫外出荷 not
-- taken back) put right where it is, keeping its 出荷先カード, warehouse,
-- day, gross weight numbers and packing lists.
-- * outbound_file_lines_edit(id, edits): row by row —
--     {line_id, quantity}: a new quantity (its amount scaled with it);
--     {line_id, action}: 'skip' leaves the row out (出荷しない: it ships
--       nothing and keeps nothing; the row stays, to be put back), 'ship'
--       puts it back (a 在庫外出荷's rows are records);
--     {add: true, product_id, quantity, unit_price?}: a product of the
--       library added as a new row at the end.
-- * outbound_file_replace_lines(id, lines, file…): the rows replaced by
--   those read from another file. The rows there were are not lost: they
--   move to a copy of the list, taken back and with no day (so on no
--   calendar or list), that says what replaced it (replaced_by).
-- Either way the totals are worked out again; キープ, 不足 and the night run
-- follow from the rows as they are now.

alter table public.outbound_files add column if not exists replaced_by bigint references public.outbound_files(id);

-- The list's totals from its rows (as outbound_file_plan works them out).
create or replace function public.outbound_file_retotal(p_id bigint)
returns void
language sql security definer set search_path = '' as $$
  update public.outbound_files f set
    line_count = x.n, quantity_total = x.q, shipped_total = x.s, short_total = x.sh, amount_total = x.a
    from (select count(*) filter (where action <> 'skip') as n,
                 coalesce(sum(quantity) filter (where action <> 'skip'), 0) as q,
                 coalesce(sum(shipped_quantity), 0) as s, coalesce(sum(short_quantity), 0) as sh,
                 sum(coalesce(amount, quantity * unit_price_tax)) filter (where action <> 'skip') as a
            from public.outbound_file_lines where file_id = p_id) x
   where f.id = p_id;
$$;
revoke all on function public.outbound_file_retotal(bigint) from public, anon, authenticated;

create or replace function public.outbound_file_lines_edit(p_id bigint, p_edits jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_e jsonb;
  v_l public.outbound_file_lines;
  v_p public.products;
  v_qty integer;
  v_action text;
  v_row integer;
  v_unit numeric;
  v_n integer := 0;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if v_f.undone_at is not null or (v_f.status <> 'planned' and v_f.kind <> 'proxy') then
    raise exception 'outbound_not_editable';
  end if;
  for v_e in select * from jsonb_array_elements(coalesce(p_edits, '[]'::jsonb)) loop
    if coalesce((v_e->>'add')::boolean, false) then
      select * into v_p from public.products where id = nullif(v_e->>'product_id', '')::bigint;
      if v_p.id is null then
        raise exception 'product % not found', v_e->>'product_id';
      end if;
      v_qty := greatest(coalesce(public.price_num(v_e->>'quantity'), 0), 0)::integer;
      v_unit := public.price_num(v_e->>'unit_price');
      select coalesce(max(row_no), 0) + 1 into v_row from public.outbound_file_lines where file_id = p_id;
      insert into public.outbound_file_lines (
        file_id, row_no, jan_code, product_id, product_name, maker, item_code, quantity, shipped_quantity,
        short_quantity, unit_price, unit_price_tax, tax_rate, action, matched_by, currency, currency_source)
      values (p_id, v_row, v_p.jan_code, v_p.id, v_p.name, v_p.maker, v_p.sku, v_qty, 0, 0,
              v_unit, case when v_unit is null then null else round(v_unit * 1.1, 2) end, 10,
              case when v_f.kind = 'proxy' then 'record' else 'ship' end, 'picked',
              coalesce(nullif(v_f.currency, ''), 'JPY'), 'manual');
      v_n := v_n + 1;
      continue;
    end if;
    select * into v_l from public.outbound_file_lines
     where id = nullif(v_e->>'line_id', '')::bigint and file_id = p_id for update;
    if v_l.id is null then
      raise exception 'outbound line % not found', v_e->>'line_id';
    end if;
    if v_e ? 'quantity' then
      v_qty := greatest(coalesce(public.price_num(v_e->>'quantity'), 0), 0)::integer;
      update public.outbound_file_lines set
        quantity = v_qty,
        amount = case when amount is not null and v_l.quantity > 0 then round(amount * v_qty / v_l.quantity, 2) end
       where id = v_l.id;
      v_n := v_n + 1;
    end if;
    if v_e ? 'action' then
      v_action := v_e->>'action';
      if v_action not in ('ship', 'record', 'skip') then
        raise exception 'outbound_action %', v_action;
      end if;
      if v_action = 'ship' and (v_f.kind = 'proxy' or v_l.product_id is null) then
        v_action := 'record';
      end if;
      update public.outbound_file_lines set action = v_action where id = v_l.id;
      v_n := v_n + 1;
    end if;
  end loop;
  perform public.outbound_file_retotal(p_id);
  perform public.log_audit('outbound.lines_edited', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('edits', p_edits));
  return v_n;
end;
$$;
revoke all on function public.outbound_file_lines_edit(bigint, jsonb) from public, anon;
grant execute on function public.outbound_file_lines_edit(bigint, jsonb) to authenticated;

create or replace function public.outbound_file_replace_lines(
  p_id bigint, p_lines jsonb, p_file_name text, p_storage_path text default null, p_content_type text default null,
  p_byte_size integer default null, p_fingerprint text default null, p_sheet_name text default null,
  p_columns jsonb default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_old bigint;
  v_line jsonb;
  v_action text;
  v_pid bigint;
  v_p public.products;
  v_qty integer;
  v_supplier text;
  v_sid bigint;
  v_unit numeric;
  v_unit_tax numeric;
  v_rate numeric;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if v_f.undone_at is not null or (v_f.status <> 'planned' and v_f.kind <> 'proxy') then
    raise exception 'outbound_not_editable';
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'outbound_no_lines';
  end if;
  if p_storage_path is not null and p_storage_path not like v_f.warehouse_id::text || '/%' then
    raise exception 'outbound_file_path';
  end if;

  -- The list as it was, kept: taken back, on no day, saying what replaced it.
  update public.outbound_files set storage_path = null where id = p_id;
  insert into public.outbound_files (warehouse_id, shipped_on, file_name, storage_path, content_type, byte_size,
                                     sheet_name, destination, note, columns, line_count, quantity_total,
                                     shipped_total, short_total, amount_total, created_at, created_by,
                                     undone_at, undone_by, kind, principal, destination_id, ship_to, status,
                                     planned_on, date_undecided, currency, fx_cny_jpy, replaced_by)
  values (v_f.warehouse_id, v_f.shipped_on, v_f.file_name, v_f.storage_path, v_f.content_type, v_f.byte_size,
          v_f.sheet_name, v_f.destination, coalesce(v_f.note || ' / ', '') || 'replaced by #' || p_id, v_f.columns,
          v_f.line_count, v_f.quantity_total, v_f.shipped_total, v_f.short_total, v_f.amount_total,
          v_f.created_at, v_f.created_by, now(), auth.uid(), v_f.kind, v_f.principal, v_f.destination_id,
          v_f.ship_to, v_f.status, v_f.planned_on, true, v_f.currency, v_f.fx_cny_jpy, p_id)
  returning id into v_old;
  update public.outbound_file_lines set file_id = v_old where file_id = p_id;

  update public.outbound_files set
    file_name = coalesce(nullif(btrim(coalesce(p_file_name, '')), ''), v_f.file_name),
    storage_path = p_storage_path, content_type = p_content_type, byte_size = p_byte_size,
    fingerprint = p_fingerprint, sheet_name = p_sheet_name, columns = coalesce(p_columns, '{}'::jsonb),
    auto_hold_at = null, auto_hold_short = null
   where id = p_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_action := coalesce(nullif(v_line->>'action', ''), 'ship');
    if v_action not in ('ship', 'record', 'skip') then
      raise exception 'outbound_action %', v_action;
    end if;
    v_pid := nullif(v_line->>'product_id', '')::bigint;
    v_p := null;
    if v_pid is not null then
      select * into v_p from public.products where id = v_pid;
      if v_p.id is null then
        raise exception 'product % not found', v_pid;
      end if;
    end if;
    if v_action = 'ship' and (v_pid is null or v_f.kind = 'proxy') then
      v_action := 'record';
    end if;
    v_qty := greatest(coalesce(public.price_num(v_line->>'quantity'), 0), 0)::integer;
    v_supplier := nullif(btrim(coalesce(v_line->>'supplier', '')), '');
    v_sid := null;
    if v_supplier is not null then
      select id into v_sid from public.delivery_suppliers
       where lower(btrim(name)) = lower(v_supplier) or lower(btrim(coalesce(code, ''))) = lower(v_supplier)
       order by id limit 1;
    end if;
    v_rate := coalesce(public.price_num(v_line->>'tax_rate'), 10);
    v_unit := public.price_num(v_line->>'unit_price');
    v_unit_tax := public.price_num(v_line->>'unit_price_tax');
    if v_unit is null and v_unit_tax is not null then v_unit := round(v_unit_tax / (1 + v_rate / 100), 2); end if;
    if v_unit_tax is null and v_unit is not null then v_unit_tax := round(v_unit * (1 + v_rate / 100), 2); end if;
    insert into public.outbound_file_lines (
      file_id, row_no, jan_code, product_id, product_name, maker, item_code, supplier_name, supplier_id,
      quantity, shipped_quantity, short_quantity, unit_price, unit_price_tax, tax_rate, list_price, amount,
      order_number, arrival, order_date, action, matched_by, raw)
    values (
      p_id, coalesce(nullif(v_line->>'row_no', '')::integer, 0),
      coalesce(v_p.jan_code, nullif(btrim(coalesce(v_line->>'jan', '')), '')), v_pid,
      coalesce(v_p.name, nullif(btrim(coalesce(v_line->>'product_name', '')), '')),
      nullif(btrim(coalesce(v_line->>'maker', '')), ''), nullif(btrim(coalesce(v_line->>'code', '')), ''),
      v_supplier, v_sid, v_qty, 0, 0,
      v_unit, v_unit_tax, v_rate, public.price_num(v_line->>'list_price'), public.price_num(v_line->>'amount'),
      nullif(btrim(coalesce(v_line->>'order_number', '')), ''), nullif(btrim(coalesce(v_line->>'arrival', '')), ''),
      nullif(btrim(coalesce(v_line->>'order_date', '')), ''), v_action, nullif(v_line->>'matched_by', ''),
      v_line->'raw');
  end loop;
  perform public.outbound_file_retotal(p_id);
  perform public.log_audit('outbound.lines_replaced', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('previous', v_old, 'file', p_file_name, 'lines', jsonb_array_length(p_lines)));
  return v_old;
end;
$$;
revoke all on function public.outbound_file_replace_lines(bigint, jsonb, text, text, text, integer, text, text, jsonb)
  from public, anon;
grant execute on function public.outbound_file_replace_lines(bigint, jsonb, text, text, text, integer, text, text, jsonb)
  to authenticated;
