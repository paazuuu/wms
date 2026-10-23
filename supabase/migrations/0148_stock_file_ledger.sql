-- 0148: a stock file kept as a record for seven years, checked in by an
-- inspector before its stock counts.
--
-- 1. Each stock-file import carries the date of the document (its issue or
--    creation date, read from the file; else the day it was uploaded), so
--    the imports can be browsed on a calendar years later.
-- 2. A memo and whether the supplier has been paid, per import.
-- 3. Added stock waits for inspection: the file's lines are kept as
--    「検品未完了」 and only an inspector's check books them into stock.
-- 4. Seven years after its date, an import is deleted with its files
--    (stock_file_expired lists them; purge-expired deletes them, daily).
--
-- Additive: nothing is removed. Imports made before keep their stock.

-- 1–3: columns -------------------------------------------------------------

alter table public.master_imports
  add column if not exists document_date date,
  -- content (read from the file), file (its own metadata) or uploaded.
  add column if not exists document_date_source text,
  add column if not exists paid boolean not null default false,
  add column if not exists paid_at timestamptz,
  add column if not exists paid_by uuid,
  add column if not exists note text,
  add column if not exists note_at timestamptz,
  add column if not exists note_by uuid;

alter table public.master_imports drop constraint if exists master_imports_status_check;
alter table public.master_imports add constraint master_imports_status_check
  check (status = any (array['reading', 'stopped', 'master_done', 'stock_done', 'cancelled', 'awaiting_inspection']));

alter table public.master_import_lines
  add column if not exists inspected_at timestamptz,
  add column if not exists inspected_by uuid,
  add column if not exists inspected_quantity integer;

create index if not exists master_imports_stock_file_date
  on public.master_imports (coalesce(document_date, (created_at at time zone 'Asia/Tokyo')::date))
  where source = 'stock_file';
create index if not exists master_imports_awaiting
  on public.master_imports (warehouse_id) where status = 'awaiting_inspection';

-- 3: staging and inspection ------------------------------------------------

-- A file's added stock, kept until it is inspected. Nothing is booked.
--   p_lines [{line_no, jan_code, quantity}]
create or replace function public.stock_file_stage(
  p_warehouse_id bigint, p_lines jsonb, p_file_name text default null, p_file_type text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  e jsonb;
  v_no int := 0;
  v_jan text;
  v_qty int;
  v_product bigint;
  v_lines int := 0;
  v_total int := 0;
  v_skipped jsonb := '[]'::jsonb;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'no lines to put in';
  end if;
  insert into public.master_imports (company_id, status, source, warehouse_id, original_name, original_type, line_count)
  values ((select id from public.companies order by id limit 1), 'awaiting_inspection', 'stock_file', p_warehouse_id,
          public.tidy_text(p_file_name), public.tidy_text(p_file_type), jsonb_array_length(p_lines))
  returning id into v_id;
  for e in select x.value from jsonb_array_elements(p_lines) as x(value) loop
    v_no := coalesce(nullif(btrim(coalesce(e->>'line_no', '')), '')::int, v_no + 1);
    v_jan := nullif(btrim(coalesce(e->>'jan_code', '')), '');
    v_qty := coalesce(nullif(btrim(coalesce(e->>'quantity', '')), '')::int, 0);
    if v_jan is null then
      raise exception 'line %: a JAN is required', v_no;
    end if;
    if v_qty < 0 then
      raise exception 'line %: a quantity cannot be negative', v_no;
    end if;
    select id into v_product from public.products where jan_code = v_jan order by id limit 1;
    if v_product is null then
      v_skipped := v_skipped || jsonb_build_object('line_no', v_no, 'jan_code', v_jan);
      continue;
    end if;
    insert into public.master_import_lines (import_id, line_no, jan_code, product_id, quantity, movement_ids)
    values (v_id, v_no, v_jan, v_product, v_qty, '{}');
    v_lines := v_lines + 1;
    v_total := v_total + v_qty;
  end loop;
  update public.master_imports set
    issues = case when jsonb_array_length(v_skipped) > 0
                  then jsonb_build_array(jsonb_build_object('code', 'unknown_jan', 'lines', v_skipped))
                  else '[]'::jsonb end,
    updated_at = now()
   where id = v_id;
  perform public.log_audit('inventory.stock_file_staged', 'master_import', v_id::text, p_warehouse_id,
    jsonb_build_object('lines', v_lines, 'quantity', v_total, 'skipped', jsonb_array_length(v_skipped)));
  return jsonb_build_object('import_id', v_id, 'lines', v_lines, 'change', 0, 'awaiting', v_total, 'skipped', v_skipped,
                            'detail', '[]'::jsonb);
end;
$$;
revoke all on function public.stock_file_stage(bigint, jsonb, text, text) from public, anon;
grant execute on function public.stock_file_stage(bigint, jsonb, text, text) to authenticated, service_role;

-- The inspector's check: each line counted is booked into stock as counted.
--   p_lines [{line_no, quantity}] — the quantity found; the file's when left out.
-- Lines already checked are left as they are. When none is left, the
-- import is done.
create or replace function public.stock_file_inspect(p_id bigint, p_lines jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
  e jsonb;
  l public.master_import_lines;
  v_qty int;
  v_before int;
  v_name text;
  v_m bigint;
  v_lines int := 0;
  v_change int := 0;
  v_diff int := 0;
  v_left int;
begin
  if not (public.has_permission('inspection.confirm') or public.has_permission('inventory.adjust')) then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  select * into v_imp from public.master_imports where id = p_id for update;
  if v_imp.id is null or v_imp.source <> 'stock_file' then
    raise exception 'import % not found', p_id;
  end if;
  if v_imp.status <> 'awaiting_inspection' or v_imp.undone_at is not null then
    raise exception 'import % is not waiting for inspection', p_id;
  end if;
  if not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'no lines checked';
  end if;
  for e in select x.value from jsonb_array_elements(p_lines) as x(value) loop
    select * into l from public.master_import_lines
     where import_id = p_id and line_no = (e->>'line_no')::int for update;
    if l.id is null then
      raise exception 'line % is not in import %', e->>'line_no', p_id;
    end if;
    if l.inspected_at is not null then
      continue;
    end if;
    v_qty := coalesce(nullif(btrim(coalesce(e->>'quantity', '')), '')::int, l.quantity);
    if v_qty < 0 then
      raise exception 'line %: a quantity cannot be negative', l.line_no;
    end if;
    select on_hand into v_before from public.stock_levels
     where warehouse_id = v_imp.warehouse_id and jan_code = l.jan_code for update;
    v_before := coalesce(v_before, 0);
    select name into v_name from public.products where id = l.product_id;
    v_m := case when v_qty = 0 then null else public.master_import_post(v_imp.warehouse_id, l.jan_code, l.product_id, v_qty,
      'OTHER', '在庫ファイル取込 #' || p_id || ' を検品して追加', p_id::text, v_name) end;
    update public.stock_levels set product_name = coalesce(v_name, product_name), product_id = coalesce(product_id, l.product_id)
     where warehouse_id = v_imp.warehouse_id and jan_code = l.jan_code;
    update public.master_import_lines set
      inspected_at = now(), inspected_by = auth.uid(), inspected_quantity = v_qty,
      on_hand_before = v_before, added = v_qty, on_hand_after = v_before + v_qty,
      movement_ids = array_remove(array[v_m], null)
     where id = l.id;
    v_lines := v_lines + 1;
    v_change := v_change + v_qty;
    v_diff := v_diff + (v_qty - l.quantity);
  end loop;
  select count(*) into v_left from public.master_import_lines where import_id = p_id and inspected_at is null;
  update public.master_imports set
    stock_lines = (select count(*) from public.master_import_lines where import_id = p_id and inspected_at is not null),
    stock_added = (select coalesce(sum(added), 0) from public.master_import_lines where import_id = p_id),
    status = case when v_left = 0 then 'stock_done' else status end,
    stock_at = case when v_left = 0 then now() else stock_at end,
    stock_by = case when v_left = 0 then auth.uid() else stock_by end,
    updated_at = now()
   where id = p_id;
  perform public.log_audit('inventory.stock_file_inspected', 'master_import', p_id::text, v_imp.warehouse_id,
    jsonb_build_object('lines', v_lines, 'change', v_change, 'difference', v_diff, 'left', v_left));
  return jsonb_build_object('import_id', p_id, 'lines', v_lines, 'change', v_change, 'difference', v_diff, 'left', v_left);
end;
$$;
revoke all on function public.stock_file_inspect(bigint, jsonb) from public, anon;
grant execute on function public.stock_file_inspect(bigint, jsonb) to authenticated, service_role;

-- Imports waiting for inspection, newest first, with what is left of each.
create or replace function public.stock_file_awaiting(p_warehouse_id bigint default null)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not (public.master_import_viewer() or public.has_permission('inspection.view')
                        or public.has_permission('inspection.confirm')) then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', m.id, 'original_name', m.original_name, 'warehouse_id', m.warehouse_id, 'warehouse_name', w.name,
             'created_at', m.created_at, 'document_date', m.document_date,
             'created_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = m.created_by),
             'lines', (select count(*) from public.master_import_lines l where l.import_id = m.id),
             'left', (select count(*) from public.master_import_lines l where l.import_id = m.id and l.inspected_at is null),
             'quantity_left', (select coalesce(sum(l.quantity), 0) from public.master_import_lines l
                                where l.import_id = m.id and l.inspected_at is null))
           order by m.created_at desc, m.id desc)
      from public.master_imports m
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and m.status = 'awaiting_inspection' and m.undone_at is null
       and public.can_access_warehouse(m.warehouse_id)
       and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)), '[]'::jsonb) end;
$$;
revoke all on function public.stock_file_awaiting(bigint) from public, anon;
grant execute on function public.stock_file_awaiting(bigint) to authenticated, service_role;

-- What is waiting for inspection, per warehouse and product — beside the
-- stock there is, never in it.
--   [{warehouse_id, product_id, jan_code, quantity}]
create or replace function public.stock_pending_inspection(p_warehouse_id bigint default null)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not public.master_import_viewer() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object('warehouse_id', x.warehouse_id, 'product_id', x.product_id,
                                        'jan_code', x.jan_code, 'quantity', x.quantity))
      from (select m.warehouse_id, l.product_id, l.jan_code, sum(l.quantity)::int as quantity
              from public.master_import_lines l
              join public.master_imports m on m.id = l.import_id
             where m.source = 'stock_file' and m.status = 'awaiting_inspection' and m.undone_at is null
               and l.inspected_at is null
               and public.can_access_warehouse(m.warehouse_id)
               and (p_warehouse_id is null or m.warehouse_id = p_warehouse_id)
             group by m.warehouse_id, l.product_id, l.jan_code) x), '[]'::jsonb) end;
$$;
revoke all on function public.stock_pending_inspection(bigint) from public, anon;
grant execute on function public.stock_pending_inspection(bigint) to authenticated, service_role;

-- 1–2: date, payment and memo ---------------------------------------------

-- Changes what is noted on an import. Keys left out are left as they are.
--   p_patch {document_date, document_date_source, paid, note}
create or replace function public.stock_file_import_update(p_id bigint, p_patch jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_imp public.master_imports;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  select * into v_imp from public.master_imports where id = p_id for update;
  if v_imp.id is null or v_imp.source <> 'stock_file' then
    raise exception 'import % not found', p_id;
  end if;
  if v_imp.warehouse_id is not null and not public.can_access_warehouse(v_imp.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if p_patch ? 'document_date' then
    if nullif(p_patch->>'document_date', '') is null then
      raise exception 'a document date is required';
    end if;
    if (p_patch->>'document_date')::date > current_date + 31 or (p_patch->>'document_date')::date < date '2000-01-01' then
      raise exception 'document date % is out of range', p_patch->>'document_date';
    end if;
    update public.master_imports set document_date = (p_patch->>'document_date')::date,
      document_date_source = coalesce(nullif(p_patch->>'document_date_source', ''), 'manual')
     where id = p_id;
  end if;
  if p_patch ? 'paid' then
    update public.master_imports set paid = coalesce((p_patch->>'paid')::boolean, false),
      paid_at = case when coalesce((p_patch->>'paid')::boolean, false) then now() end,
      paid_by = case when coalesce((p_patch->>'paid')::boolean, false) then auth.uid() end
     where id = p_id and paid is distinct from coalesce((p_patch->>'paid')::boolean, false);
  end if;
  if p_patch ? 'note' then
    update public.master_imports set note = nullif(left(btrim(coalesce(p_patch->>'note', '')), 4000), ''),
      note_at = now(), note_by = auth.uid()
     where id = p_id;
  end if;
  update public.master_imports set updated_at = now() where id = p_id;
  perform public.log_audit('inventory.stock_file_noted', 'master_import', p_id::text, v_imp.warehouse_id, p_patch);
  return (select jsonb_build_object('id', id, 'document_date', document_date, 'document_date_source', document_date_source,
                                    'paid', paid, 'paid_at', paid_at, 'note', note)
            from public.master_imports where id = p_id);
end;
$$;
revoke all on function public.stock_file_import_update(bigint, jsonb) from public, anon;
grant execute on function public.stock_file_import_update(bigint, jsonb) to authenticated, service_role;

-- Stock-file imports dated between two days (the document's date, else the
-- day it came in), for the calendar.
create or replace function public.stock_file_calendar(p_from date, p_to date)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not public.master_import_viewer() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', m.id, 'day', d.day, 'document_date', m.document_date, 'document_date_source', m.document_date_source,
             'created_at', m.created_at, 'original_name', m.original_name, 'warehouse_name', w.name,
             'status', m.status, 'undone_at', m.undone_at, 'line_count', m.line_count,
             'stock_lines', m.stock_lines, 'stock_added', m.stock_added, 'paid', m.paid, 'note', m.note)
           order by d.day, m.id)
      from public.master_imports m
      cross join lateral (select coalesce(m.document_date, (m.created_at at time zone 'Asia/Tokyo')::date) as day) d
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and d.day between p_from and p_to
       and (m.warehouse_id is null or public.can_access_warehouse(m.warehouse_id))), '[]'::jsonb) end;
$$;
revoke all on function public.stock_file_calendar(date, date) from public, anon;
grant execute on function public.stock_file_calendar(date, date) to authenticated, service_role;

-- Earlier imports of the same file or lines: those waiting for inspection
-- count too, since they will go in.
create or replace function public.stock_file_import_duplicates(p_file text, p_lines text)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not public.master_import_viewer() then '[]'::jsonb else coalesce((
    select jsonb_agg(jsonb_build_object(
             'import_id', m.id, 'at', coalesce(m.stock_at, m.created_at), 'file_name', m.original_name,
             'warehouse_name', w.name, 'lines', coalesce(nullif(m.stock_lines, 0), m.line_count), 'change', m.stock_added,
             'same_file', m.file_fingerprint = p_file, 'same_lines', m.lines_fingerprint = p_lines,
             'awaiting', m.status = 'awaiting_inspection')
           order by m.id desc)
      from public.master_imports m
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and m.status in ('stock_done', 'awaiting_inspection') and m.undone_at is null
       and ((p_file is not null and m.file_fingerprint = p_file) or (p_lines is not null and m.lines_fingerprint = p_lines))
  ), '[]'::jsonb) end;
$$;

-- The history list, with the date, payment and memo.
create or replace function public.master_imports_list(p_limit integer default 50)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select case when not public.master_import_viewer() then '[]'::jsonb else coalesce((
    select jsonb_agg(to_jsonb(x) order by x.created_at desc, x.id desc)
      from (select m.id, m.status, m.source, m.supplier_id, s.name as supplier_name, m.warehouse_id,
                   w.name as warehouse_name, m.original_name, m.original_path, m.converted_name, m.converted_path,
                   m.corrected_name, m.corrected_path, m.line_count, m.issues, m.master_created, m.master_updated,
                   m.master_mapped, m.stock_lines, m.stock_added, m.created_at, m.master_at, m.stock_at,
                   m.undone_at, m.document_date, m.document_date_source, m.paid, m.note,
                   (select coalesce(u.name, u.email) from public.app_users u where u.id = m.created_by) as created_by_name
              from public.master_imports m
              left join public.delivery_suppliers s on s.id = m.supplier_id
              left join public.warehouses w on w.id = m.warehouse_id
             order by m.created_at desc, m.id desc
             limit greatest(1, least(coalesce(p_limit, 50), 200))) x), '[]'::jsonb) end;
$$;

-- An import with its lines; each line says whether and how it was inspected.
create or replace function public.master_import_detail(p_id bigint, p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_head jsonb;
begin
  if not (public.master_import_viewer() or public.has_permission('inspection.confirm')) then
    raise exception 'not permitted: product.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  select to_jsonb(m) - 'company_id' into v_head from public.master_imports m where m.id = p_id;
  if v_head is null then
    raise exception 'import % not found', p_id;
  end if;
  return v_head || jsonb_build_object('lines', coalesce((
    select jsonb_agg(jsonb_build_object(
             'line_no', l.line_no, 'jan_code', l.jan_code, 'product_id', l.product_id,
             'name', p.name, 'name_en', p.name_en, 'maker', p.maker, 'sku', p.sku,
             'supplier_name', l.supplier_name, 'quantity', l.quantity, 'master_status', l.master_status,
             'on_hand_before', l.on_hand_before, 'on_hand_set', l.on_hand_set, 'added', l.added,
             'on_hand_after', l.on_hand_after,
             'inspected_at', l.inspected_at, 'inspected_quantity', l.inspected_quantity,
             'inspected_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = l.inspected_by),
             'on_hand_now', case when p_warehouse_id is null then null else coalesce((
                select sl.on_hand from public.stock_levels sl
                 where sl.warehouse_id = p_warehouse_id and sl.jan_code = l.jan_code), 0) end)
           order by l.line_no)
      from public.master_import_lines l
      left join public.products p on p.id = l.product_id
     where l.import_id = p_id), '[]'::jsonb));
end;
$$;

-- 4: seven years ------------------------------------------------------------

-- Stock-file imports past seven years from their date, with every kept
-- file to delete. Read by purge-expired (service role) before it deletes.
create or replace function public.stock_file_expired(p_limit int default 200)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', m.id, 'day', coalesce(m.document_date, (m.created_at at time zone 'Asia/Tokyo')::date),
           'files', (select coalesce(jsonb_agg(jsonb_build_object('bucket', 'master-import-files', 'path', p)), '[]'::jsonb)
                       from unnest(array_remove(array[m.original_path, m.converted_path, m.corrected_path], null)) p)
                    || coalesce((select jsonb_build_array(jsonb_build_object('bucket', 'import-documents', 'path', d.storage_path,
                                                                             'document_id', d.id))
                                   from public.import_documents d
                                  where d.id = m.document_id and d.storage_path is not null
                                    and d.delivery_plan_id is null and d.shipment_plan_id is null
                                    and not exists (select 1 from public.master_imports o
                                                     where o.document_id = d.id and o.id <> m.id
                                                       and coalesce(o.document_date, (o.created_at at time zone 'Asia/Tokyo')::date)
                                                           >= (current_date - interval '7 years')::date)),
                                '[]'::jsonb))), '[]'::jsonb)
    from (select * from public.master_imports
           where source = 'stock_file'
             and coalesce(document_date, (created_at at time zone 'Asia/Tokyo')::date) < (current_date - interval '7 years')::date
           order by id
           limit greatest(1, least(coalesce(p_limit, 200), 1000))) m;
$$;
revoke all on function public.stock_file_expired(int) from public, anon, authenticated;
grant execute on function public.stock_file_expired(int) to service_role;

-- The deleting itself is purge-expired's (an edge function, service role):
-- files first through the Storage API (they cannot be removed from SQL),
-- then the import (its lines go with it) and the kept copies nothing else
-- refers to. The stock it moved stays in the ledger, so today's stock does
-- not change.
--
-- It is called once a day by pg_cron with a shared secret: a random value
-- kept only in the vault, sent by the job and compared here. No person
-- needs to see it.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'purge_expired_secret') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'purge_expired_secret',
      'Sent by the daily pg_cron job to purge-expired (0148).');
  end if;
end $$;

create or replace function public.purge_secret_matches(p_secret text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(length(p_secret) >= 24 and p_secret = (
    select decrypted_secret from vault.decrypted_secrets where name = 'purge_expired_secret' limit 1), false);
$$;
revoke all on function public.purge_secret_matches(text) from public, anon, authenticated;
grant execute on function public.purge_secret_matches(text) to service_role;

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Every day at 03:17 in Japan (18:17 UTC).
select cron.schedule(
  'purge-expired-stock-files',
  '17 18 * * *',
  $job$
  select net.http_post(
    url := 'https://vjunicsfobglmncjucbb.supabase.co/functions/v1/purge-expired',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-purge-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'purge_expired_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000);
  $job$
);

comment on function public.stock_file_stage(bigint, jsonb, text, text) is
  'Stock file kept for inspection (0148): lines stay 検品未完了 until stock_file_inspect books them.';
