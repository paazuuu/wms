-- 0071_inbound_exceptions.sql
-- Phase B, step 7: exception handling.
--
-- §36 lists "Exception handling" last in Phase B and §39 puts it in the Inbound
-- completion checklist, but no section defines it — so it has to be derived from
-- what inbound actually produces when things go wrong. Reading the pipeline
-- built in 0066–0070, the answer is already there in pieces:
--
--   * receiving computes `shortfall` / `over` / `unexpected` per line, and then
--     writes the word onto the line and moves on;
--   * QC records FAIL and HOLD, and 0068 makes those move the stock;
--   * put-away can find no bin a parcel is allowed into.
--
-- Every one of those is a fact nobody owns. A status on a row tells you what
-- happened; it does not tell you who noticed, what was decided, by whom, or
-- whether anyone is still waiting for the supplier to answer. That gap is what
-- "exception handling" names: the difference between a discrepancy that has been
-- *recorded* and one that has been *dealt with*.
--
-- Two rules shape the design.
--
-- **An exception never moves stock.** Resolving one may call an existing RPC —
-- `move_stock_status`, `adjust_stock` — and that RPC posts to the ledger as
-- usual. The exception records the decision; the ledger records the effect. Same
-- separation §5 draws between a document and a projection, and it is what keeps
-- §37-4 ("履歴削除で帳尻を合わせない") true: a resolved shortfall leaves both the
-- original receipt and the correction visible.
--
-- **Detection is idempotent.** Exceptions are raised at the moment of detection,
-- inside the operation that detected them, not by a nightly sweep — so the same
-- receipt being re-read, retried or replayed must not pile up duplicates. Each
-- automatically raised exception carries a `source_key` that names exactly what
-- it was raised for, and that key is unique. This is §37-12's idempotency rule
-- applied to a derived record rather than to a stock mutation.

-- ---------------------------------------------------------------------------
-- 1. The vocabulary
-- ---------------------------------------------------------------------------

create table if not exists public.exception_types (
  code                text primary key,
  name                text not null,
  category            text not null check (category in ('RECEIVING', 'QC', 'PUTAWAY', 'STOCK', 'OTHER')),
  severity            text not null default 'WARNING' check (severity in ('INFO', 'WARNING', 'BLOCKER')),
  -- False for the ones that are worth knowing but need no decision — the floor
  -- should not be made to close a ticket saying "yes, four fewer arrived, and
  -- the purchase order already says so".
  requires_resolution boolean not null default true,
  sort_order          integer not null default 100,
  is_active           boolean not null default true
);

alter table public.exception_types enable row level security;
drop policy if exists "read exception types" on public.exception_types;
create policy "read exception types" on public.exception_types
  for select using (auth.uid() is not null);

insert into public.exception_types
  (code, name, category, severity, requires_resolution, sort_order) values
  ('SHORTFALL',          '数量不足',     'RECEIVING', 'WARNING', true,  10),
  ('OVER_RECEIPT',       '過剰入荷',     'RECEIVING', 'WARNING', true,  20),
  ('UNEXPECTED_ITEM',    '予定外の商品', 'RECEIVING', 'BLOCKER', true,  30),
  ('LOT_MISSING',        'ロット未記録', 'RECEIVING', 'BLOCKER', true,  40),
  ('EXPIRY_TOO_SOON',    '期限が近い',   'RECEIVING', 'WARNING', true,  50),
  ('UNREGISTERED_PRODUCT', '未登録商品', 'RECEIVING', 'BLOCKER', true,  60),
  ('QC_FAIL',            '検品不合格',   'QC',        'BLOCKER', true,  70),
  ('QC_HOLD',            '検品保留',     'QC',        'WARNING', true,  80),
  ('QC_NOT_HELD',        '検品対象が保留在庫にない', 'QC', 'INFO', false, 90),
  ('NO_SUITABLE_BIN',    '格納先なし',   'PUTAWAY',   'BLOCKER', true, 100),
  ('DAMAGED_ON_ARRIVAL', '到着時破損',   'RECEIVING', 'BLOCKER', true, 110),
  ('MISLABELLED',        'ラベル相違',   'RECEIVING', 'WARNING', true, 120),
  ('OTHER',              'その他',       'OTHER',     'WARNING', true, 900)
on conflict (code) do update
  set name = excluded.name, category = excluded.category,
      severity = excluded.severity,
      requires_resolution = excluded.requires_resolution,
      sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- 2. The exception itself
-- ---------------------------------------------------------------------------

create table if not exists public.exceptions (
  id                     bigserial primary key,
  company_id             bigint not null references public.companies(id),
  warehouse_id           bigint references public.warehouses(id),
  exception_type         text not null references public.exception_types(code),
  -- Where it happened. Nullable individually because an exception can belong to
  -- a receipt, a line, a parcel or an inspection, and pretending otherwise would
  -- mean a table per source.
  reconciliation_id      bigint references public.delivery_reconciliations(id) on delete cascade,
  reconciliation_line_id bigint references public.reconciliation_lines(id) on delete set null,
  receipt_item_id        bigint references public.receipt_items(id) on delete set null,
  inspection_id          bigint references public.inspections(id) on delete set null,
  product_id             bigint references public.products(id) on delete set null,
  lot_id                 bigint references public.lots(id) on delete set null,
  jan_code               text,
  quantity               integer,
  note                   text,
  status                 text not null default 'OPEN'
                           check (status in ('OPEN', 'ACKNOWLEDGED', 'RESOLVED', 'CANCELLED')),
  resolution             text check (resolution is null or resolution in
                           ('ACCEPTED', 'SUPPLIER_CLAIM', 'RETURNED', 'SCRAPPED',
                            'CORRECTED', 'RECOUNTED', 'NO_ACTION')),
  resolution_note        text,
  resolved_by            uuid,
  resolved_at            timestamptz,
  acknowledged_by        uuid,
  acknowledged_at        timestamptz,
  raised_by              uuid,
  -- Null for one a person raised; set for one detection raised, and unique, so
  -- replaying the operation that found it cannot raise it twice.
  source_key             text unique,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),

  constraint exceptions_resolution_shape check (
    (status = 'RESOLVED') = (resolution is not null))
);

comment on table public.exceptions is
  'Something that went wrong in a warehouse operation, and what was decided about it. Never moves stock itself: a resolution that changes stock does it through the usual RPC so the ledger stays the single source (§5, §37-4).';

create index if not exists exceptions_open_idx
  on public.exceptions (warehouse_id, exception_type)
  where status in ('OPEN', 'ACKNOWLEDGED');
create index if not exists exceptions_reconciliation_idx
  on public.exceptions (reconciliation_id) where reconciliation_id is not null;
create index if not exists exceptions_product_idx
  on public.exceptions (product_id) where product_id is not null;

alter table public.exceptions enable row level security;
drop policy if exists "read exceptions" on public.exceptions;
create policy "read exceptions" on public.exceptions
  for select using (
    (public.has_permission('receiving.view')
     or public.has_permission('inspection.view')
     or public.has_permission('inventory.view'))
    and (warehouse_id is null or public.can_access_warehouse(warehouse_id)));

-- ---------------------------------------------------------------------------
-- 3. Raising one
-- ---------------------------------------------------------------------------
--
-- The _impl checks no permission, because detection calls it from inside
-- operations that were already gated. `raise_exception` is the door for a person
-- flagging something the system did not catch, and that one is gated.

create or replace function public.raise_exception_impl(
  p_exception_type text,
  p_warehouse_id   bigint,
  p_source_key     text default null,
  p_reconciliation_id bigint default null,
  p_reconciliation_line_id bigint default null,
  p_receipt_item_id bigint default null,
  p_inspection_id  bigint default null,
  p_product_id     bigint default null,
  p_lot_id         bigint default null,
  p_jan_code       text default null,
  p_quantity       integer default null,
  p_note           text default null
) returns bigint
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company bigint;
  v_code    text := upper(btrim(coalesce(p_exception_type, '')));
  v_key     text := nullif(btrim(coalesce(p_source_key, '')), '');
  v_id      bigint;
begin
  if not exists (select 1 from public.exception_types
                  where code = v_code and is_active) then
    raise exception 'unknown exception type %', p_exception_type;
  end if;

  select id into v_company from public.companies order by id limit 1;

  insert into public.exceptions (
    company_id, warehouse_id, exception_type, reconciliation_id,
    reconciliation_line_id, receipt_item_id, inspection_id, product_id, lot_id,
    jan_code, quantity, note, raised_by, source_key)
  values (
    v_company, p_warehouse_id, v_code, p_reconciliation_id,
    p_reconciliation_line_id, p_receipt_item_id, p_inspection_id, p_product_id,
    p_lot_id, p_jan_code, p_quantity, p_note, auth.uid(), v_key)
  -- The idempotency that lets detection run inside a retryable operation.
  on conflict (source_key) do nothing
  returning id into v_id;

  if v_id is not null then
    perform public.log_audit('exception.raised', 'exception', v_id::text,
      p_warehouse_id,
      jsonb_build_object('type', v_code, 'jan_code', p_jan_code,
                         'quantity', p_quantity, 'note', p_note));
  end if;
  return v_id;
end;
$$;

revoke all on function public.raise_exception_impl(text, bigint, text, bigint, bigint, bigint, bigint, bigint, bigint, text, integer, text)
  from public, anon, authenticated, service_role;

create or replace function public.raise_exception(
  p_exception_type    text,
  p_warehouse_id      bigint,
  p_note              text default null,
  p_reconciliation_id bigint default null,
  p_product_id        bigint default null,
  p_jan_code          text default null,
  p_quantity          integer default null,
  p_receipt_item_id   bigint default null,
  p_inspection_id     bigint default null
) returns bigint
language plpgsql
security definer
set search_path to ''
as $$
begin
  if not (public.has_permission('receiving.confirm')
          or public.has_permission('inspection.confirm')
          or public.has_permission('inventory.adjust')) then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  -- No source_key: a person raising the same concern twice is two concerns, and
  -- silently swallowing the second would lose a report.
  return public.raise_exception_impl(
    p_exception_type, p_warehouse_id, null, p_reconciliation_id, null,
    p_receipt_item_id, p_inspection_id, p_product_id, null, p_jan_code,
    p_quantity, p_note);
end;
$$;

revoke all on function public.raise_exception(text, bigint, text, bigint, bigint, text, integer, bigint, bigint)
  from public, anon;
grant execute on function public.raise_exception(text, bigint, text, bigint, bigint, text, integer, bigint, bigint)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Dealing with one
-- ---------------------------------------------------------------------------

create or replace function public.acknowledge_exception(p_exception_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare v_row public.exceptions;
begin
  select * into v_row from public.exceptions where id = p_exception_id;
  if v_row.id is null then
    raise exception 'exception % not found', p_exception_id;
  end if;
  if not (public.has_permission('receiving.confirm')
          or public.has_permission('inspection.confirm')
          or public.has_permission('inventory.adjust')) then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  if v_row.warehouse_id is not null and not public.can_access_warehouse(v_row.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_row.status <> 'OPEN' then
    raise exception 'exception % is already %', p_exception_id, v_row.status;
  end if;

  update public.exceptions
     set status = 'ACKNOWLEDGED', acknowledged_by = auth.uid(),
         acknowledged_at = now(), updated_at = now()
   where id = p_exception_id;

  perform public.log_audit('exception.acknowledged', 'exception',
    p_exception_id::text, v_row.warehouse_id,
    jsonb_build_object('type', v_row.exception_type));

  return jsonb_build_object('exception_id', p_exception_id, 'status', 'ACKNOWLEDGED');
end;
$$;

revoke all on function public.acknowledge_exception(bigint) from public, anon;
grant execute on function public.acknowledge_exception(bigint) to authenticated, service_role;

create or replace function public.resolve_exception(
  p_exception_id bigint,
  p_resolution   text,
  p_note         text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_row public.exceptions;
  v_res text := upper(btrim(coalesce(p_resolution, '')));
begin
  select * into v_row from public.exceptions where id = p_exception_id;
  if v_row.id is null then
    raise exception 'exception % not found', p_exception_id;
  end if;
  if not (public.has_permission('receiving.confirm')
          or public.has_permission('inspection.confirm')
          or public.has_permission('inventory.adjust')) then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  if v_row.warehouse_id is not null and not public.can_access_warehouse(v_row.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_row.status in ('RESOLVED', 'CANCELLED') then
    raise exception 'exception % is already %', p_exception_id, v_row.status;
  end if;
  if v_res not in ('ACCEPTED', 'SUPPLIER_CLAIM', 'RETURNED', 'SCRAPPED',
                   'CORRECTED', 'RECOUNTED', 'NO_ACTION') then
    raise exception 'unknown resolution %', p_resolution;
  end if;
  -- A resolution that is only a word is not a resolution. The three that mean
  -- someone did something to the goods have to say what.
  if v_res in ('RETURNED', 'SCRAPPED', 'CORRECTED')
     and nullif(btrim(coalesce(p_note, '')), '') is null then
    raise exception 'resolving as % needs a note saying what was done', v_res;
  end if;

  update public.exceptions
     set status = 'RESOLVED', resolution = v_res,
         resolution_note = nullif(btrim(coalesce(p_note, '')), ''),
         resolved_by = auth.uid(), resolved_at = now(), updated_at = now()
   where id = p_exception_id;

  perform public.log_audit('exception.resolved', 'exception',
    p_exception_id::text, v_row.warehouse_id,
    jsonb_build_object('type', v_row.exception_type, 'resolution', v_res,
                       'note', p_note));

  -- Deliberately no stock movement here. Scrapping the goods is
  -- `adjust_stock`; sending them back is a return; putting them beyond use is
  -- `move_stock_status`. Each of those posts to the ledger and is audited on its
  -- own terms, and folding them in here would give one call two reasons to fail.
  return jsonb_build_object(
    'exception_id', p_exception_id, 'status', 'RESOLVED', 'resolution', v_res);
end;
$$;

revoke all on function public.resolve_exception(bigint, text, text) from public, anon;
grant execute on function public.resolve_exception(bigint, text, text) to authenticated, service_role;

create or replace function public.cancel_exception(p_exception_id bigint, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare v_row public.exceptions;
begin
  select * into v_row from public.exceptions where id = p_exception_id;
  if v_row.id is null then
    raise exception 'exception % not found', p_exception_id;
  end if;
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  if v_row.warehouse_id is not null and not public.can_access_warehouse(v_row.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_row.status = 'RESOLVED' then
    raise exception 'exception % is resolved and cannot be cancelled', p_exception_id;
  end if;

  update public.exceptions
     set status = 'CANCELLED', resolution_note = coalesce(p_reason, resolution_note),
         updated_at = now()
   where id = p_exception_id;

  perform public.log_audit('exception.cancelled', 'exception',
    p_exception_id::text, v_row.warehouse_id,
    jsonb_build_object('type', v_row.exception_type, 'reason', p_reason));
  return jsonb_build_object('exception_id', p_exception_id, 'status', 'CANCELLED');
end;
$$;

revoke all on function public.cancel_exception(bigint, text) from public, anon;
grant execute on function public.cancel_exception(bigint, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Detection, at the point of detection
-- ---------------------------------------------------------------------------
--
-- One function per stage, called from inside the operation that produced the
-- facts. Each exception's `source_key` names the exact thing it is about, so
-- running the operation again finds the same keys and inserts nothing.

create or replace function public.detect_receiving_exceptions(p_reconciliation_id bigint)
returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
  v_raised int := 0;
  v_id bigint;
  r record;
begin
  select coalesce(dp.warehouse_id, public.default_warehouse_id())
    into v_warehouse
    from public.delivery_reconciliations dr
    join public.delivery_plans dp on dp.id = dr.delivery_plan_id
   where dr.id = p_reconciliation_id;
  if v_warehouse is null then
    return 0;
  end if;

  -- Line-level: what receiving already worked out, now given an owner.
  for r in
    select rl.id, rl.jan_code, rl.status, rl.planned_quantity, rl.actual_quantity,
           rl.product_id
      from public.reconciliation_lines rl
     where rl.reconciliation_id = p_reconciliation_id
  loop
    if r.status = 'shortfall' then
      v_id := public.raise_exception_impl(
        'SHORTFALL', v_warehouse,
        format('recon:%s:line:%s:shortfall', p_reconciliation_id, r.id),
        p_reconciliation_id, r.id, null, null, r.product_id, null, r.jan_code,
        greatest(coalesce(r.planned_quantity, 0) - coalesce(r.actual_quantity, 0), 0),
        format('予定 %s に対して %s', r.planned_quantity, r.actual_quantity));
      if v_id is not null then v_raised := v_raised + 1; end if;
    elsif r.status = 'over' then
      v_id := public.raise_exception_impl(
        'OVER_RECEIPT', v_warehouse,
        format('recon:%s:line:%s:over', p_reconciliation_id, r.id),
        p_reconciliation_id, r.id, null, null, r.product_id, null, r.jan_code,
        coalesce(r.actual_quantity, 0) - coalesce(r.planned_quantity, 0),
        format('予定 %s に対して %s', r.planned_quantity, r.actual_quantity));
      if v_id is not null then v_raised := v_raised + 1; end if;
    elsif r.status = 'unexpected' then
      v_id := public.raise_exception_impl(
        'UNEXPECTED_ITEM', v_warehouse,
        format('recon:%s:line:%s:unexpected', p_reconciliation_id, r.id),
        p_reconciliation_id, r.id, null, null, r.product_id, null, r.jan_code,
        r.actual_quantity, '予定に無い商品が届いた');
      if v_id is not null then v_raised := v_raised + 1; end if;
    end if;
  end loop;

  -- Parcel-level: what the receipt items themselves reveal.
  for r in
    select ri.id, ri.jan_code, ri.product_id, ri.lot_id, ri.quantity, ri.expiry,
           ri.reconciliation_line_id,
           p.tracking_mode, p.id as known_product,
           l.expiry_date
      from public.receipt_items ri
      left join public.products p on p.id = ri.product_id
      left join public.lots l on l.id = ri.lot_id
     where ri.reconciliation_id = p_reconciliation_id
  loop
    -- A JAN nobody has registered: the stock arrived and has nowhere to belong.
    if r.known_product is null then
      v_id := public.raise_exception_impl(
        'UNREGISTERED_PRODUCT', v_warehouse,
        format('recon:%s:item:%s:unregistered', p_reconciliation_id, r.id),
        p_reconciliation_id, r.reconciliation_line_id, r.id, null, null, null,
        r.jan_code, r.quantity, 'JAN が商品マスタに無い');
      if v_id is not null then v_raised := v_raised + 1; end if;

    -- §9's rule the other way round: a product tracked by lot that arrived
    -- without one cannot be recalled, rotated or expired.
    elsif r.tracking_mode in ('LOT', 'LOT_AND_SERIAL', 'EXPIRY') and r.lot_id is null then
      v_id := public.raise_exception_impl(
        'LOT_MISSING', v_warehouse,
        format('recon:%s:item:%s:lot_missing', p_reconciliation_id, r.id),
        p_reconciliation_id, r.reconciliation_line_id, r.id, null, r.product_id,
        null, r.jan_code, r.quantity,
        format('%s 管理の商品にロットが記録されていない', r.tracking_mode));
      if v_id is not null then v_raised := v_raised + 1; end if;
    end if;

    -- Goods that are already near the end of their life on the day they arrive.
    -- Thirty days is the default threshold and the one knob here worth moving
    -- later; it is deliberately not a per-product setting yet, because no such
    -- column exists and inventing one to hold a guess is worse than a documented
    -- default.
    if coalesce(r.expiry, r.expiry_date) is not null
       and coalesce(r.expiry, r.expiry_date) <= current_date + 30 then
      v_id := public.raise_exception_impl(
        'EXPIRY_TOO_SOON', v_warehouse,
        format('recon:%s:item:%s:expiry', p_reconciliation_id, r.id),
        p_reconciliation_id, r.reconciliation_line_id, r.id, null, r.product_id,
        r.lot_id, r.jan_code, r.quantity,
        format('期限 %s（入荷時点で残り %s 日）',
               coalesce(r.expiry, r.expiry_date),
               coalesce(r.expiry, r.expiry_date) - current_date));
      if v_id is not null then v_raised := v_raised + 1; end if;
    end if;
  end loop;

  return v_raised;
end;
$$;

revoke all on function public.detect_receiving_exceptions(bigint)
  from public, anon, authenticated;
grant execute on function public.detect_receiving_exceptions(bigint) to service_role;

create or replace function public.detect_qc_exceptions(
  p_inspection_id bigint,
  p_fail_status   text default 'DAMAGED'
) returns integer
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_warehouse bigint;
  v_recon bigint;
  v_raised int := 0;
  v_id bigint;
  r record;
begin
  select warehouse_id, reconciliation_id into v_warehouse, v_recon
    from public.inspections where id = p_inspection_id;
  if v_warehouse is null then
    return 0;
  end if;

  for r in
    select i.id, i.jan_code, i.product_id, i.lot_id, i.result,
           i.actual_quantity, i.passed_quantity, i.failed_quantity, i.note
      from public.inspection_items i
     where i.inspection_id = p_inspection_id
       and (i.result in ('FAIL', 'HOLD') or i.failed_quantity > 0)
  loop
    v_id := public.raise_exception_impl(
      case when r.result = 'HOLD' then 'QC_HOLD' else 'QC_FAIL' end,
      v_warehouse,
      format('inspection:%s:item:%s', p_inspection_id, r.id),
      v_recon, null, null, p_inspection_id, r.product_id, r.lot_id, r.jan_code,
      case when r.failed_quantity > 0 then r.failed_quantity else r.actual_quantity end,
      concat_ws(' / ',
        case when r.result = 'HOLD' then '検品保留'
             else format('検品不合格（%s へ移動）', upper(btrim(coalesce(p_fail_status, 'DAMAGED')))) end,
        r.note));
    if v_id is not null then v_raised := v_raised + 1; end if;
  end loop;

  return v_raised;
end;
$$;

revoke all on function public.detect_qc_exceptions(bigint, text)
  from public, anon, authenticated;
grant execute on function public.detect_qc_exceptions(bigint, text) to service_role;

-- ---------------------------------------------------------------------------
-- 6. Wiring detection in without restating the operations
-- ---------------------------------------------------------------------------
--
-- `reconcile_delivery_plan` and `complete_inspection` are long, and restating
-- either one here to add a single call would mean two copies of a function whose
-- behaviour this migration is not changing — and the next person would have to
-- diff them to be sure. Instead the body is read back from the catalogue and the
-- call is spliced in at a marker, with an assertion that the marker was there.
-- If either function is ever rewritten in a way that removes the marker, this
-- migration fails loudly rather than silently not wiring detection up. The same
-- technique 0056 and 0060 used.

do $wire$
declare
  v_src    text;
  v_marker text;
  v_patch  text;
begin
  -- Receiving: detect after the receipt is complete and its lines are final,
  -- immediately before it writes its own audit entry.
  v_src := pg_get_functiondef('public.reconcile_delivery_plan(bigint, boolean, text, jsonb)'::regprocedure);
  v_marker := E'  perform public.log_audit(\n    \'receiving.confirmed\',';
  if position(v_marker in v_src) = 0 then
    raise exception 'reconcile_delivery_plan no longer has the audit marker this migration splices at';
  end if;
  v_patch := E'  perform public.detect_receiving_exceptions(v_recon_id);\n\n' || v_marker;
  execute replace(v_src, v_marker, v_patch);

  v_src := pg_get_functiondef('public.complete_inspection(bigint, text, text)'::regprocedure);
  v_marker := E'  perform public.log_audit(\n    \'inspection.confirmed\',';
  if position(v_marker in v_src) = 0 then
    raise exception 'complete_inspection no longer has the audit marker this migration splices at';
  end if;
  v_patch := E'  perform public.detect_qc_exceptions(p_inspection_id, v_fail_code);\n\n' || v_marker;
  execute replace(v_src, v_marker, v_patch);
end $wire$;

-- The splice recreates both functions, so their grants are reasserted.
revoke all on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.reconcile_delivery_plan(bigint, boolean, text, jsonb)
  to service_role;
revoke all on function public.complete_inspection(bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.complete_inspection(bigint, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- 7. Reading them
-- ---------------------------------------------------------------------------

create or replace function public.open_exceptions(
  p_warehouse_id bigint default null,
  p_category     text default null,
  p_include_closed boolean default false,
  p_limit        integer default 100
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
begin
  if not (public.has_permission('receiving.view')
          or public.has_permission('inspection.view')
          or public.has_permission('inventory.view')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(t) order by t.severity_rank, t.created_at desc)
    from (
      select e.id as exception_id,
             e.exception_type, et.name as exception_name,
             et.category, et.severity, et.requires_resolution,
             case et.severity when 'BLOCKER' then 0 when 'WARNING' then 1 else 2 end as severity_rank,
             e.status, e.resolution, e.resolution_note,
             e.warehouse_id, e.reconciliation_id, e.reconciliation_line_id,
             e.receipt_item_id, e.inspection_id,
             e.product_id, e.jan_code, p.name as product_name,
             e.lot_id, l.lot_code, l.expiry_date,
             e.quantity, e.note,
             dr.reference_no, dp.delivery_number, dp.supplier_name,
             e.raised_by, e.created_at,
             e.acknowledged_at, e.resolved_at
        from public.exceptions e
        join public.exception_types et on et.code = e.exception_type
        left join public.products p on p.id = e.product_id
        left join public.lots l on l.id = e.lot_id
        left join public.delivery_reconciliations dr on dr.id = e.reconciliation_id
        left join public.delivery_plans dp on dp.id = dr.delivery_plan_id
       where (p_warehouse_id is null or e.warehouse_id = p_warehouse_id)
         and (e.warehouse_id is null or public.can_access_warehouse(e.warehouse_id))
         and (p_category is null or et.category = upper(btrim(p_category)))
         and (p_include_closed or e.status in ('OPEN', 'ACKNOWLEDGED'))
       order by case et.severity when 'BLOCKER' then 0 when 'WARNING' then 1 else 2 end,
                e.created_at desc
       limit greatest(coalesce(p_limit, 100), 1)
    ) t), '[]'::jsonb);
end;
$$;

revoke all on function public.open_exceptions(bigint, text, boolean, integer)
  from public, anon;
grant execute on function public.open_exceptions(bigint, text, boolean, integer)
  to authenticated, service_role;

-- One number per kind, for the tile on the dashboard that says whether the dock
-- needs someone.
create or replace function public.exception_summary(p_warehouse_id bigint default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
begin
  if not (public.has_permission('receiving.view')
          or public.has_permission('inspection.view')
          or public.has_permission('inventory.view')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return jsonb_build_object(
    'open', coalesce((
      select count(*) from public.exceptions e
       where e.status in ('OPEN', 'ACKNOWLEDGED')
         and (p_warehouse_id is null or e.warehouse_id = p_warehouse_id)
         and (e.warehouse_id is null or public.can_access_warehouse(e.warehouse_id))), 0),
    'blockers', coalesce((
      select count(*) from public.exceptions e
       join public.exception_types et on et.code = e.exception_type
       where e.status in ('OPEN', 'ACKNOWLEDGED') and et.severity = 'BLOCKER'
         and (p_warehouse_id is null or e.warehouse_id = p_warehouse_id)
         and (e.warehouse_id is null or public.can_access_warehouse(e.warehouse_id))), 0),
    'by_type', coalesce((
      select jsonb_agg(jsonb_build_object(
        'exception_type', x.exception_type, 'name', x.name,
        'category', x.category, 'severity', x.severity, 'open', x.n)
        order by x.n desc, x.exception_type)
      from (
        select e.exception_type, et.name, et.category, et.severity, count(*)::int as n
          from public.exceptions e
          join public.exception_types et on et.code = e.exception_type
         where e.status in ('OPEN', 'ACKNOWLEDGED')
           and (p_warehouse_id is null or e.warehouse_id = p_warehouse_id)
           and (e.warehouse_id is null or public.can_access_warehouse(e.warehouse_id))
         group by 1, 2, 3, 4) x), '[]'::jsonb));
end;
$$;

revoke all on function public.exception_summary(bigint) from public, anon;
grant execute on function public.exception_summary(bigint) to authenticated, service_role;

create or replace function public.list_exception_types()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'code', t.code, 'name', t.name, 'category', t.category,
    'severity', t.severity, 'requires_resolution', t.requires_resolution)
    order by t.sort_order), '[]'::jsonb)
  from public.exception_types t where t.is_active;
$$;

revoke all on function public.list_exception_types() from public, anon;
grant execute on function public.list_exception_types() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 8. Housekeeping
-- ---------------------------------------------------------------------------

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
