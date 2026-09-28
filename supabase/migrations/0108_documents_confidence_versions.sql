-- 0108 — the supplier's invoice laid against the order, the delivery and the
-- inspection; how sure the AI has to be; and versions of what was learned.
--
-- 1. Invoices and the four-way match (spec §51, §55, §63)
--    `supplier_invoices` / `supplier_invoice_lines` hold a supplier's invoice
--    (typed, or read from a PDF/photo by the document reader and checked by a
--    person). `document_match(po)` lays, product by product, what was
--    ordered, invoiced, delivered (the delivery note), received and
--    inspected side by side and flags every difference — quantity, price,
--    short delivery, short inspection, damage, lines not ordered or not
--    invoiced — within the supplier's tolerance (`supplier_match_rules`).
--    `document_exceptions()` is the queue of those differences across open
--    orders (§53). Nothing is settled automatically: an invoice is approved
--    by a person (§43); approving it updates the supply terms the profit
--    engine reads (§62: invoice → terms → cost → profit).
--
-- 2. AI confidence thresholds (§50)
--    `ai_settings` holds the two thresholds — at or above `auto_threshold` a
--    reading is an automatic candidate, from `review_threshold` it is
--    "check recommended", below it a person reviews it. Changed from the
--    admin screen (`set_ai_settings`, ai.review). Confidence itself is
--    explainable, not a model's private number: it comes from whether the
--    two independent AI reads agreed, the check digit, the split of name and
--    品番, and the arithmetic of the line.
--
-- 3. Versions of what was learned (§60)
--    `notation_library_versions` keeps each trading company's dictionary
--    (dialects and column headings) as a numbered version: taken by hand,
--    and every time a checked sample is learned. Nothing is overwritten;
--    an old version can be restored alongside the current one, so documents
--    in an old format still read.

-- ------------------------------------------------------------ 2. AI settings

create table if not exists public.ai_settings (
  id smallint primary key default 1 check (id = 1),
  auto_threshold numeric not null default 0.95 check (auto_threshold between 0 and 1),
  review_threshold numeric not null default 0.80 check (review_threshold between 0 and 1),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (review_threshold <= auto_threshold)
);
insert into public.ai_settings (id) values (1) on conflict do nothing;
alter table public.ai_settings enable row level security;
drop policy if exists "ai_settings: signed-in can read" on public.ai_settings;
create policy "ai_settings: signed-in can read" on public.ai_settings for select to authenticated using (true);

create or replace function public.get_ai_settings()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('auto_threshold', auto_threshold, 'review_threshold', review_threshold,
                            'updated_at', updated_at)
    from public.ai_settings where id = 1;
$$;

create or replace function public.set_ai_settings(p_auto numeric, p_review numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not (public.has_permission('ai.review') or public.has_permission('user.manage')) then
    raise exception 'not permitted: ai.review required';
  end if;
  if p_auto is null or p_review is null or p_auto < 0 or p_auto > 1 or p_review < 0 or p_review > 1 then
    raise exception 'thresholds must be between 0 and 1';
  end if;
  if p_review > p_auto then
    raise exception 'the review threshold cannot be above the automatic one';
  end if;
  update public.ai_settings set auto_threshold = p_auto, review_threshold = p_review,
         updated_at = now(), updated_by = auth.uid()
   where id = 1;
  perform public.log_audit('ai.settings', 'ai_settings', '1', null,
    jsonb_build_object('auto_threshold', p_auto, 'review_threshold', p_review));
  return public.get_ai_settings();
end;
$$;

revoke all on function public.get_ai_settings() from public, anon;
revoke all on function public.set_ai_settings(numeric, numeric) from public, anon;
grant execute on function public.get_ai_settings() to authenticated, service_role;
grant execute on function public.set_ai_settings(numeric, numeric) to authenticated, service_role;

-- ------------------------------------------------------------ 3. versions

create table if not exists public.notation_library_versions (
  id bigint generated always as identity primary key,
  partner_id bigint not null references public.delivery_suppliers(id) on delete cascade,
  version integer not null,
  source text not null default 'manual' check (source in ('manual', 'training', 'restore')),
  training_id bigint references public.notation_trainings(id) on delete set null,
  note text,
  dialects jsonb not null default '[]'::jsonb,
  column_aliases jsonb not null default '[]'::jsonb,
  dialect_count integer not null default 0,
  alias_count integer not null default 0,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (partner_id, version)
);
alter table public.notation_library_versions enable row level security;
drop policy if exists "notation_library_versions: signed-in can read" on public.notation_library_versions;
create policy "notation_library_versions: signed-in can read" on public.notation_library_versions
  for select to authenticated using (true);

-- The company's dictionary as it stands, kept as the next version.
create or replace function public.snapshot_notation_library_impl(
  p_partner_id bigint, p_note text, p_source text, p_training_id bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_dialects jsonb;
  v_aliases jsonb;
begin
  -- One writer at a time per company, so version numbers never collide.
  perform pg_advisory_xact_lock(hashtext('notation_library'), p_partner_id::integer);
  select coalesce(jsonb_agg(jsonb_build_object(
           'field', d.field, 'raw_value', d.raw_value, 'raw_values', to_jsonb(d.raw_values),
           'value_key', d.value_key, 'product_id', d.product_id, 'maker_id', d.maker_id,
           'scope_maker_id', d.scope_maker_id, 'confirmed', d.confirmed, 'source', d.source,
           'seen_count', d.seen_count) order by d.field, d.value_key), '[]')
    into v_dialects
    from public.notation_dialects d where d.partner_id = p_partner_id;
  select coalesce(jsonb_agg(jsonb_build_object(
           'header_raw', a.header_raw, 'header_key', a.header_key, 'field', a.field,
           'source', a.source, 'seen_count', a.seen_count) order by a.header_key), '[]')
    into v_aliases
    from public.column_aliases a where a.partner_id = p_partner_id;
  insert into public.notation_library_versions
    (partner_id, version, source, training_id, note, dialects, column_aliases, dialect_count, alias_count)
  values (p_partner_id,
          coalesce((select max(version) from public.notation_library_versions where partner_id = p_partner_id), 0) + 1,
          coalesce(p_source, 'manual'), p_training_id, nullif(btrim(p_note), ''),
          v_dialects, v_aliases, jsonb_array_length(v_dialects), jsonb_array_length(v_aliases))
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.snapshot_notation_library_impl(bigint, text, text, bigint) from public, anon, authenticated;

create or replace function public.snapshot_notation_library(p_partner_id bigint, p_note text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
  if not public.notation_training_allowed() then
    raise exception 'not permitted: product.manage required';
  end if;
  if p_partner_id is null then raise exception 'partner_id is required'; end if;
  v_id := public.snapshot_notation_library_impl(p_partner_id, p_note, 'manual', null);
  perform public.log_audit('notation.library_version', 'notation_library_version', v_id::text, null,
    jsonb_build_object('partner_id', p_partner_id, 'note', p_note));
  return v_id;
end;
$$;

-- Learning a checked sample makes a new version by itself.
create or replace function public.notation_trainings_a_version()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'learned' and old.status is distinct from 'learned' and new.partner_id is not null then
    perform public.snapshot_notation_library_impl(new.partner_id, new.file_name, 'training', new.id);
  end if;
  return new;
end;
$$;
drop trigger if exists notation_trainings_a_version on public.notation_trainings;
create trigger notation_trainings_a_version after update on public.notation_trainings
  for each row execute function public.notation_trainings_a_version();

create or replace function public.list_notation_library_versions(p_partner_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', v.id, 'partner_id', v.partner_id, 'version', v.version, 'source', v.source,
             'training_id', v.training_id, 'note', v.note,
             'dialect_count', v.dialect_count, 'alias_count', v.alias_count,
             'created_at', v.created_at,
             'created_by_name', (select u.name from public.app_users u where u.id = v.created_by),
             -- What changed since the version before it.
             'added', (select count(*) from jsonb_array_elements(v.dialects) x
                        where not exists (select 1 from jsonb_array_elements(coalesce(p.dialects, '[]')) y
                                           where y->>'field' = x->>'field' and y->>'value_key' = x->>'value_key'
                                             and coalesce(y->>'scope_maker_id', '') = coalesce(x->>'scope_maker_id', ''))),
             'removed', (select count(*) from jsonb_array_elements(coalesce(p.dialects, '[]')) y
                          where not exists (select 1 from jsonb_array_elements(v.dialects) x
                                             where y->>'field' = x->>'field' and y->>'value_key' = x->>'value_key'
                                               and coalesce(y->>'scope_maker_id', '') = coalesce(x->>'scope_maker_id', '')))
           ) order by v.version desc)
      from public.notation_library_versions v
      left join public.notation_library_versions p
        on p.partner_id = v.partner_id and p.version = v.version - 1
     where v.partner_id = p_partner_id), '[]');
end;
$$;

-- An old version brought back alongside the current dictionary: what is
-- missing now is added back; a writing that now means something else is
-- reported, never overwritten. The result is kept as a new version.
create or replace function public.restore_notation_library_version(p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v public.notation_library_versions%rowtype;
  d jsonb;
  a jsonb;
  v_dialects integer := 0;
  v_aliases integer := 0;
  v_conflicts jsonb := '[]'::jsonb;
  cur public.notation_dialects%rowtype;
  v_new bigint;
begin
  if not public.notation_training_allowed() then
    raise exception 'not permitted: product.manage required';
  end if;
  select * into v from public.notation_library_versions where id = p_id;
  if not found then raise exception 'version % not found', p_id; end if;

  for d in select * from jsonb_array_elements(v.dialects) loop
    select * into cur from public.notation_dialects x
     where coalesce(x.partner_id, 0) = v.partner_id and x.field = d->>'field'
       and x.value_key = d->>'value_key'
       and coalesce(x.scope_maker_id, 0) = coalesce((d->>'scope_maker_id')::bigint, 0);
    if not found then
      insert into public.notation_dialects (partner_id, field, raw_value, raw_values, value_key,
        product_id, maker_id, scope_maker_id, confirmed, source, seen_count)
      values (v.partner_id, d->>'field', d->>'raw_value',
        coalesce((select array_agg(e) from jsonb_array_elements_text(coalesce(d->'raw_values', '[]')) e), array[d->>'raw_value']),
        d->>'value_key', (d->>'product_id')::bigint, (d->>'maker_id')::bigint,
        (d->>'scope_maker_id')::bigint, coalesce((d->>'confirmed')::boolean, false),
        'restore', coalesce((d->>'seen_count')::integer, 1));
      v_dialects := v_dialects + 1;
    elsif cur.product_id is distinct from (d->>'product_id')::bigint
       or cur.maker_id is distinct from (d->>'maker_id')::bigint then
      v_conflicts := v_conflicts || jsonb_build_object('field', d->>'field', 'raw_value', d->>'raw_value',
        'now_product_id', cur.product_id, 'then_product_id', (d->>'product_id')::bigint);
    end if;
  end loop;

  for a in select * from jsonb_array_elements(v.column_aliases) loop
    if not exists (select 1 from public.column_aliases x
                    where coalesce(x.partner_id, 0) = v.partner_id and x.header_key = a->>'header_key') then
      insert into public.column_aliases (partner_id, header_raw, header_key, field, source, seen_count)
      values (v.partner_id, a->>'header_raw', a->>'header_key', a->>'field', 'restore',
              coalesce((a->>'seen_count')::integer, 1));
      v_aliases := v_aliases + 1;
    end if;
  end loop;

  v_new := public.snapshot_notation_library_impl(v.partner_id, 'v' || v.version, 'restore', null);
  perform public.log_audit('notation.library_restore', 'notation_library_version', p_id::text, null,
    jsonb_build_object('dialects', v_dialects, 'aliases', v_aliases, 'conflicts', jsonb_array_length(v_conflicts)));
  return jsonb_build_object('restored_dialects', v_dialects, 'restored_aliases', v_aliases,
                            'conflicts', v_conflicts, 'version_id', v_new);
end;
$$;

revoke all on function public.snapshot_notation_library(bigint, text) from public, anon;
revoke all on function public.list_notation_library_versions(bigint) from public, anon;
revoke all on function public.restore_notation_library_version(bigint) from public, anon;
grant execute on function public.snapshot_notation_library(bigint, text) to authenticated, service_role;
grant execute on function public.list_notation_library_versions(bigint) to authenticated, service_role;
grant execute on function public.restore_notation_library_version(bigint) to authenticated, service_role;

-- A version 1 for every company that has learned something already.
do $$
declare r record;
begin
  for r in select distinct partner_id from public.notation_dialects where partner_id is not null
            and not exists (select 1 from public.notation_library_versions v where v.partner_id = notation_dialects.partner_id)
  loop
    perform public.snapshot_notation_library_impl(r.partner_id, null, 'manual', null);
  end loop;
end $$;

-- ------------------------------------------------------------ 1. invoices

create table if not exists public.supplier_match_rules (
  partner_id bigint primary key references public.delivery_suppliers(id) on delete cascade,
  -- A difference within these is not flagged (§52 許容不足).
  qty_tolerance_pct numeric not null default 0 check (qty_tolerance_pct >= 0),
  price_tolerance_pct numeric not null default 0 check (price_tolerance_pct >= 0),
  note text,
  updated_at timestamptz not null default now()
);

create table if not exists public.supplier_invoices (
  id bigint generated always as identity primary key,
  invoice_number text not null,
  partner_id bigint references public.delivery_suppliers(id) on delete restrict,
  purchase_order_id bigint references public.purchase_orders(id) on delete set null,
  delivery_plan_id bigint references public.delivery_plans(id) on delete set null,
  invoice_date date,
  due_date date,
  currency text,
  subtotal numeric,
  tax numeric,
  total numeric,
  status text not null default 'open' check (status in ('open', 'matched', 'mismatch', 'approved', 'void')),
  source text not null default 'manual' check (source in ('manual', 'document')),
  -- How sure the reading was, per header field (§50), when it was read.
  confidence jsonb,
  note text,
  approved_by uuid,
  approved_at timestamptz,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists supplier_invoices_number
  on public.supplier_invoices (coalesce(partner_id, 0), invoice_number) where status <> 'void';
create index if not exists supplier_invoices_po on public.supplier_invoices (purchase_order_id);

create table if not exists public.supplier_invoice_lines (
  id bigint generated always as identity primary key,
  invoice_id bigint not null references public.supplier_invoices(id) on delete cascade,
  line_no integer not null,
  product_id bigint references public.products(id) on delete set null,
  jan_code text,
  product_code text,
  product_name text,
  maker text,
  quantity numeric not null default 0,
  unit_price numeric,
  discount_rate numeric,
  amount numeric,
  -- Per field (§50): {"jan": 0.99, "quantity": 0.6, ...}
  confidence jsonb,
  flags jsonb,
  unique (invoice_id, line_no)
);

do $$
declare t text;
begin
  foreach t in array array['supplier_invoices', 'supplier_invoice_lines', 'supplier_match_rules'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s: purchasing can read" on public.%I', t, t);
  end loop;
end $$;
create policy "supplier_invoices: purchasing can read" on public.supplier_invoices for select to authenticated
  using (public.has_permission('purchase_order.view') or public.has_permission('purchase_order.manage')
         or public.has_permission('purchase_order.approve') or public.has_permission('receiving.view'));
create policy "supplier_invoice_lines: purchasing can read" on public.supplier_invoice_lines for select to authenticated
  using (exists (select 1 from public.supplier_invoices i where i.id = invoice_id));
create policy "supplier_match_rules: purchasing can read" on public.supplier_match_rules for select to authenticated
  using (true);

create or replace function public.documents_can_view()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.has_permission('purchase_order.view') or public.has_permission('purchase_order.manage')
      or public.has_permission('purchase_order.approve') or public.has_permission('receiving.view')
      or public.has_permission('inspection.view');
$$;

create or replace function public.documents_can_manage()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.has_permission('purchase_order.manage') or public.has_permission('purchase_order.approve');
$$;

-- The product a line means: its id when given, else our JAN.
create or replace function public.doc_product_key(p_product_id bigint, p_jan text)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(p_product_id,
                  (select p.id from public.products p where p.jan_code = public.normalize_jan(p_jan) limit 1))::text;
$$;

-- Ordered / invoiced / delivered / received / inspected, product by product.
create or replace function public.document_match_impl(p_purchase_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_po public.purchase_orders%rowtype;
  v_rule public.supplier_match_rules%rowtype;
  v_qtol numeric;
  v_ptol numeric;
  v_lines jsonb;
  v_invoices jsonb;
  v_deliveries jsonb;
  v_po_amount numeric;
  v_inv_amount numeric;
  v_inv_total numeric;
  v_has_invoice boolean;
  v_has_delivery boolean;
  v_flags integer;
begin
  select * into v_po from public.purchase_orders where id = p_purchase_order_id;
  if not found then raise exception 'purchase order % not found', p_purchase_order_id; end if;
  select * into v_rule from public.supplier_match_rules where partner_id = v_po.supplier_id;
  v_qtol := coalesce(v_rule.qty_tolerance_pct, 0) / 100.0;
  v_ptol := coalesce(v_rule.price_tolerance_pct, 0) / 100.0;

  select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'invoice_number', i.invoice_number,
           'invoice_date', i.invoice_date, 'status', i.status, 'total', i.total, 'source', i.source)
           order by i.created_at), '[]')
    into v_invoices
    from public.supplier_invoices i where i.purchase_order_id = p_purchase_order_id and i.status <> 'void';
  v_has_invoice := jsonb_array_length(v_invoices) > 0;

  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'delivery_number', d.delivery_number,
           'delivery_date', d.delivery_date, 'status', d.status) order by d.created_at), '[]')
    into v_deliveries
    from public.delivery_plans d where d.purchase_order_id = p_purchase_order_id;
  v_has_delivery := jsonb_array_length(v_deliveries) > 0;

  with src as (
    select public.doc_product_key(l.product_id, l.jan_code) as k, l.jan_code, l.product_name,
           l.quantity::numeric as ordered, (l.quantity * coalesce(l.unit_price, 0))::numeric as ordered_amount,
           0::numeric as invoiced, 0::numeric as invoiced_amount, 0::numeric as delivered, 0::numeric as received,
           0::numeric as inspected, 0::numeric as passed, 0::numeric as failed
      from public.purchase_order_lines l where l.purchase_order_id = p_purchase_order_id
    union all
    select public.doc_product_key(il.product_id, il.jan_code), il.jan_code, il.product_name,
           0, 0, il.quantity, coalesce(il.amount, il.quantity * coalesce(il.unit_price, 0)), 0, 0, 0, 0, 0
      from public.supplier_invoice_lines il
      join public.supplier_invoices i on i.id = il.invoice_id
     where i.purchase_order_id = p_purchase_order_id and i.status <> 'void'
    union all
    select public.doc_product_key(dl.product_id, dl.jan_code), dl.jan_code, dl.product_name,
           0, 0, 0, 0, dl.planned_quantity, coalesce(dl.received_quantity, 0), 0, 0, 0
      from public.delivery_plan_lines dl
      join public.delivery_plans d on d.id = dl.delivery_plan_id
     where d.purchase_order_id = p_purchase_order_id
    union all
    select public.doc_product_key(ii.product_id, ii.jan_code), ii.jan_code, ii.product_name,
           0, 0, 0, 0, 0, 0,
           coalesce(ii.counted_quantity, coalesce(ii.passed_quantity, 0) + coalesce(ii.failed_quantity, 0)),
           coalesce(ii.passed_quantity, 0), coalesce(ii.failed_quantity, 0)
      from public.inspection_items ii
      join public.inspections ins on ins.id = ii.inspection_id
      join public.delivery_plans d on d.id = ins.delivery_plan_id
     where d.purchase_order_id = p_purchase_order_id
  ),
  agg as (
    select coalesce(k, 'jan:' || coalesce(max(jan_code), '?')) as k,
           max(jan_code) as jan_code, max(product_name) as product_name,
           sum(ordered) ordered, sum(ordered_amount) ordered_amount,
           sum(invoiced) invoiced, sum(invoiced_amount) invoiced_amount,
           sum(delivered) delivered, sum(received) received,
           sum(inspected) inspected, sum(passed) passed, sum(failed) failed
      from src group by k
  ),
  flagged as (
    select a.*,
           case when a.ordered > 0 then a.ordered_amount / a.ordered end as order_price,
           case when a.invoiced > 0 then a.invoiced_amount / a.invoiced end as invoice_price,
           array_remove(array[
             case when a.ordered = 0 and (a.invoiced > 0 or a.delivered > 0) then 'not_ordered' end,
             case when v_has_invoice and a.ordered > 0 and a.invoiced = 0 then 'not_invoiced' end,
             case when a.invoiced > 0 and a.ordered > 0
                   and abs(a.invoiced - a.ordered) > a.ordered * v_qtol then 'invoice_qty' end,
             case when a.invoiced > 0 and a.ordered > 0 and a.ordered_amount > 0
                   and abs(a.invoiced_amount / a.invoiced - a.ordered_amount / a.ordered)
                       > (a.ordered_amount / a.ordered) * v_ptol + 0.005 then 'invoice_price' end,
             case when a.invoiced > 0 and a.received < a.invoiced - a.invoiced * v_qtol
                   and v_has_delivery then 'short_delivery' end,
             case when a.inspected > 0 and a.inspected < a.received - a.received * v_qtol then 'inspect_short' end,
             case when a.failed > 0 then 'defective' end
           ], null) as flags
      from agg a
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'key', f.k, 'product_id', case when f.k ~ '^\d+$' then f.k::bigint end,
           'jan_code', f.jan_code, 'product_name', f.product_name,
           'ordered', f.ordered, 'order_price', round(f.order_price, 2),
           'invoiced', f.invoiced, 'invoice_price', round(f.invoice_price, 2),
           'delivered', f.delivered, 'received', f.received,
           'inspected', f.inspected, 'passed', f.passed, 'failed', f.failed,
           'difference', f.received - greatest(f.invoiced, f.ordered),
           'flags', to_jsonb(f.flags)) order by cardinality(f.flags) desc, f.product_name), '[]'),
         coalesce(sum(f.ordered_amount), 0), coalesce(sum(f.invoiced_amount), 0),
         coalesce(sum(cardinality(f.flags)), 0)
    into v_lines, v_po_amount, v_inv_amount, v_flags
    from flagged f;

  select sum(coalesce(i.total, 0)) into v_inv_total
    from public.supplier_invoices i where i.purchase_order_id = p_purchase_order_id and i.status <> 'void';

  return jsonb_build_object(
    'purchase_order_id', v_po.id, 'po_number', v_po.po_number, 'supplier_id', v_po.supplier_id,
    'supplier_name', v_po.supplier_name, 'warehouse_id', v_po.warehouse_id, 'po_status', v_po.status,
    'order_date', v_po.order_date, 'expected_date', v_po.expected_date,
    'invoices', v_invoices, 'deliveries', v_deliveries,
    'lines', v_lines,
    'po_amount', v_po_amount, 'invoice_lines_amount', v_inv_amount, 'invoice_total', v_inv_total,
    'amount_difference', v_inv_amount - v_po_amount,
    'qty_tolerance_pct', coalesce(v_rule.qty_tolerance_pct, 0),
    'price_tolerance_pct', coalesce(v_rule.price_tolerance_pct, 0),
    'status', case when not v_has_invoice then 'pending'
                   when v_flags = 0 then 'match' else 'mismatch' end);
end;
$$;
revoke all on function public.document_match_impl(bigint) from public, anon, authenticated;

create or replace function public.document_match(p_purchase_order_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_wh bigint;
begin
  if not public.documents_can_view() then
    raise exception 'not permitted: purchase_order.view required';
  end if;
  select warehouse_id into v_wh from public.purchase_orders where id = p_purchase_order_id;
  if v_wh is not null and not public.can_access_warehouse(v_wh) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return public.document_match_impl(p_purchase_order_id);
end;
$$;

-- Every difference on recent orders, one row each (§53 exception queue).
create or replace function public.document_exceptions(p_warehouse_id bigint default null, p_days integer default 180)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  po record;
  m jsonb;
  l jsonb;
  f text;
  v_out jsonb := '[]'::jsonb;
begin
  if not public.documents_can_view() then
    raise exception 'not permitted: purchase_order.view required';
  end if;
  for po in
    select p.id from public.purchase_orders p
     where p.status in ('SUBMITTED', 'APPROVED', 'COMPLETED')
       and p.created_at >= now() - make_interval(days => greatest(1, coalesce(p_days, 180)))
       and (p_warehouse_id is null or p.warehouse_id = p_warehouse_id)
       and (p.warehouse_id is null or public.can_access_warehouse(p.warehouse_id))
       and (exists (select 1 from public.supplier_invoices i where i.purchase_order_id = p.id and i.status not in ('void', 'approved'))
            or exists (select 1 from public.delivery_plans d where d.purchase_order_id = p.id))
     order by p.created_at desc
  loop
    m := public.document_match_impl(po.id);
    for l in select * from jsonb_array_elements(m->'lines') loop
      for f in select * from jsonb_array_elements_text(l->'flags') loop
        v_out := v_out || jsonb_build_object(
          'purchase_order_id', m->'purchase_order_id', 'po_number', m->'po_number',
          'supplier_name', m->'supplier_name', 'kind', f,
          'product_id', l->'product_id', 'jan_code', l->'jan_code', 'product_name', l->'product_name',
          'ordered', l->'ordered', 'invoiced', l->'invoiced', 'received', l->'received',
          'inspected', l->'inspected', 'failed', l->'failed',
          'order_price', l->'order_price', 'invoice_price', l->'invoice_price');
      end loop;
    end loop;
  end loop;
  return v_out;
end;
$$;

-- An invoice, header and lines, each line resolved to our product through
-- the company's dialects. The lines are replaced as a whole.
create or replace function public.save_supplier_invoice(p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := (p->>'id')::bigint;
  v_partner bigint := (p->>'partner_id')::bigint;
  v_po bigint := (p->>'purchase_order_id')::bigint;
  v_lines jsonb := coalesce(p->'lines', '[]'::jsonb);
  v_resolved jsonb;
  v_status text;
  v_match jsonb;
  e jsonb;
  i integer := 0;
begin
  if not public.documents_can_manage() then
    raise exception 'not permitted: purchase_order.manage required';
  end if;
  if nullif(btrim(p->>'invoice_number'), '') is null then raise exception 'invoice_number is required'; end if;
  if v_po is not null then
    select coalesce(v_partner, supplier_id) into v_partner from public.purchase_orders where id = v_po;
    if not found then raise exception 'purchase order % not found', v_po; end if;
  end if;

  if v_id is null then
    insert into public.supplier_invoices (invoice_number, partner_id, purchase_order_id)
    values (btrim(p->>'invoice_number'), v_partner, v_po)
    returning id into v_id;
  else
    if exists (select 1 from public.supplier_invoices where id = v_id and status in ('approved', 'void')) then
      raise exception 'invoice % is already settled', v_id;
    end if;
    delete from public.supplier_invoice_lines where invoice_id = v_id;
  end if;
  update public.supplier_invoices set
    invoice_number = btrim(p->>'invoice_number'),
    partner_id = v_partner,
    purchase_order_id = v_po,
    delivery_plan_id = (p->>'delivery_plan_id')::bigint,
    invoice_date = public.sc_try_date(p->>'invoice_date'),
    due_date = public.sc_try_date(p->>'due_date'),
    currency = upper(nullif(btrim(p->>'currency'), '')),
    subtotal = public.sc_num(p, 'subtotal'),
    tax = public.sc_num(p, 'tax'),
    total = public.sc_num(p, 'total'),
    source = coalesce(nullif(p->>'source', ''), 'manual'),
    confidence = p->'confidence',
    note = nullif(btrim(p->>'note'), ''),
    updated_at = now()
   where id = v_id;

  select public.resolve_notation_lines(v_partner, (
           select coalesce(jsonb_agg(jsonb_build_object('jan_code', x->>'jan_code', 'maker', x->>'maker',
                    'product_name', x->>'product_name', 'product_code', x->>'product_code')), '[]')
             from jsonb_array_elements(v_lines) x))
    into v_resolved;

  for e in select * from jsonb_array_elements(v_lines) loop
    insert into public.supplier_invoice_lines (invoice_id, line_no, product_id, jan_code, product_code,
      product_name, maker, quantity, unit_price, discount_rate, amount, confidence, flags)
    values (v_id, i + 1,
      coalesce((e->>'product_id')::bigint, (v_resolved->i->'product'->>'id')::bigint),
      nullif(btrim(e->>'jan_code'), ''), nullif(btrim(e->>'product_code'), ''),
      nullif(btrim(e->>'product_name'), ''), nullif(btrim(e->>'maker'), ''),
      coalesce(public.sc_num(e, 'quantity'), 0), public.sc_num(e, 'unit_price'),
      public.sc_num(e, 'discount_rate'), public.sc_num(e, 'amount'),
      e->'confidence', e->'flags');
    i := i + 1;
  end loop;

  if v_po is not null then
    v_match := public.document_match_impl(v_po);
    v_status := case v_match->>'status' when 'match' then 'matched' when 'mismatch' then 'mismatch' else 'open' end;
  else
    v_status := 'open';
  end if;
  update public.supplier_invoices set status = v_status where id = v_id;

  perform public.log_audit('invoice.saved', 'supplier_invoice', v_id::text, null,
    jsonb_build_object('invoice_number', p->>'invoice_number', 'purchase_order_id', v_po, 'lines', i, 'status', v_status));
  return jsonb_build_object('id', v_id, 'status', v_status, 'match', v_match);
end;
$$;

create or replace function public.list_supplier_invoices(p_purchase_order_id bigint default null, p_status text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.documents_can_view() then
    raise exception 'not permitted: purchase_order.view required';
  end if;
  return coalesce((
    select jsonb_agg(to_jsonb(i) || jsonb_build_object(
             'partner_name', (select d.name from public.delivery_suppliers d where d.id = i.partner_id),
             'po_number', (select p.po_number from public.purchase_orders p where p.id = i.purchase_order_id),
             'line_count', (select count(*) from public.supplier_invoice_lines l where l.invoice_id = i.id),
             'lines_amount', (select sum(coalesce(l.amount, l.quantity * coalesce(l.unit_price, 0)))
                                from public.supplier_invoice_lines l where l.invoice_id = i.id))
           order by i.created_at desc)
      from public.supplier_invoices i
     where (p_purchase_order_id is null or i.purchase_order_id = p_purchase_order_id)
       and (p_status is null or i.status = p_status)
       and (i.purchase_order_id is null
            or exists (select 1 from public.purchase_orders p where p.id = i.purchase_order_id
                        and (p.warehouse_id is null or public.can_access_warehouse(p.warehouse_id))))), '[]');
end;
$$;

create or replace function public.supplier_invoice(p_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v jsonb;
begin
  if not public.documents_can_view() then
    raise exception 'not permitted: purchase_order.view required';
  end if;
  select to_jsonb(i) || jsonb_build_object(
           'partner_name', (select d.name from public.delivery_suppliers d where d.id = i.partner_id),
           'po_number', (select p.po_number from public.purchase_orders p where p.id = i.purchase_order_id),
           'lines', coalesce((select jsonb_agg(to_jsonb(l) order by l.line_no)
                                from public.supplier_invoice_lines l where l.invoice_id = i.id), '[]'))
    into v
    from public.supplier_invoices i where i.id = p_id;
  if v is null then raise exception 'invoice % not found', p_id; end if;
  return v;
end;
$$;

-- A person settles the invoice (§43: AI never confirms by itself). An
-- approved invoice's prices become the supply terms the profit engine reads
-- (§62), unless someone set those terms by hand.
create or replace function public.set_supplier_invoice_status(p_id bigint, p_status text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v public.supplier_invoices%rowtype;
  l record;
  v_updated integer := 0;
  v_kept integer := 0;
  v_term public.supply_chain_supplier_products%rowtype;
begin
  if not public.documents_can_manage() then
    raise exception 'not permitted: purchase_order.manage required';
  end if;
  if p_status not in ('approved', 'void', 'open') then raise exception 'unknown status %', p_status; end if;
  select * into v from public.supplier_invoices where id = p_id for update;
  if not found then raise exception 'invoice % not found', p_id; end if;
  if v.status = 'void' then raise exception 'invoice % is void', p_id; end if;

  update public.supplier_invoices set status = p_status,
         note = coalesce(nullif(btrim(p_note), ''), note),
         approved_by = case when p_status = 'approved' then auth.uid() end,
         approved_at = case when p_status = 'approved' then now() end,
         updated_at = now()
   where id = p_id;

  if p_status = 'approved' and v.partner_id is not null then
    for l in select product_id, sum(coalesce(amount, quantity * unit_price)) / nullif(sum(quantity), 0) as price
               from public.supplier_invoice_lines
              where invoice_id = p_id and product_id is not null and unit_price is not null
              group by product_id loop
      select * into v_term from public.supply_chain_supplier_products
       where partner_id = v.partner_id and product_id = l.product_id;
      if not found then
        insert into public.supply_chain_supplier_products (partner_id, product_id, unit_price, currency, source, note)
        values (v.partner_id, l.product_id, round(l.price, 4), v.currency, 'document', 'invoice ' || v.invoice_number);
        v_updated := v_updated + 1;
      elsif v_term.source <> 'manual' or (v_term.unit_price is null and v_term.list_price is null) then
        update public.supply_chain_supplier_products
           set unit_price = round(l.price, 4), currency = coalesce(v.currency, currency),
               source = 'document', note = 'invoice ' || v.invoice_number, updated_at = now()
         where id = v_term.id;
        v_updated := v_updated + 1;
      else
        v_kept := v_kept + 1;
      end if;
    end loop;
    perform public.sc_sync_nodes_impl();
  end if;

  perform public.log_audit('invoice.' || p_status, 'supplier_invoice', p_id::text, null,
    jsonb_build_object('terms_updated', v_updated, 'terms_kept', v_kept));
  return jsonb_build_object('id', p_id, 'status', p_status, 'terms_updated', v_updated, 'terms_kept', v_kept);
end;
$$;

create or replace function public.set_supplier_match_rule(p_partner_id bigint, p_qty_pct numeric, p_price_pct numeric, p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.documents_can_manage() then
    raise exception 'not permitted: purchase_order.manage required';
  end if;
  insert into public.supplier_match_rules (partner_id, qty_tolerance_pct, price_tolerance_pct, note)
  values (p_partner_id, greatest(coalesce(p_qty_pct, 0), 0), greatest(coalesce(p_price_pct, 0), 0), p_note)
  on conflict (partner_id) do update set qty_tolerance_pct = excluded.qty_tolerance_pct,
    price_tolerance_pct = excluded.price_tolerance_pct, note = excluded.note, updated_at = now();
  perform public.log_audit('invoice.match_rule', 'supplier_match_rule', p_partner_id::text, null,
    jsonb_build_object('qty_pct', p_qty_pct, 'price_pct', p_price_pct));
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'documents_can_view()', 'documents_can_manage()', 'doc_product_key(bigint, text)',
    'document_match(bigint)', 'document_exceptions(bigint, integer)', 'save_supplier_invoice(jsonb)',
    'list_supplier_invoices(bigint, text)', 'supplier_invoice(bigint)',
    'set_supplier_invoice_status(bigint, text, text)', 'set_supplier_match_rule(bigint, numeric, numeric, text)']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated, service_role', f);
  end loop;
end $$;

-- A restored entry says so (0108b).
alter table public.notation_dialects drop constraint if exists notation_dialects_source_check;
alter table public.notation_dialects add constraint notation_dialects_source_check
  check (source in ('manual', 'import', 'inspection', 'ai', 'seed', 'legacy', 'restore'));
alter table public.column_aliases drop constraint if exists column_aliases_source_check;
alter table public.column_aliases add constraint column_aliases_source_check
  check (source in ('seed', 'manual', 'import', 'ai', 'restore'));
