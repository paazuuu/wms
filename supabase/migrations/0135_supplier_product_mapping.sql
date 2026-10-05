-- 0135 — Product Master at the centre of 仕入先ファイル起点の入荷.
--
-- One product, one product id; what each supplier calls it lives beside it in
-- supplier_product_names (the Supplier Product Mapping of the spec). This
-- migration:
--   - gives the mapping the fields the spec lists (model number, unit, last
--     seen, active) and fills it on its own once a plan line is tied to one of
--     our products, so the second file from that supplier is recognised;
--   - scores candidate products for a line nobody could place
--     (`product_match_candidates`), identifiers before names;
--   - lets the library search find a product by any supplier's writing,
--     including the readings learned from past files;
--   - gathers a product's inbound history (`product_inbound_history`).

alter table public.supplier_product_names
  add column if not exists supplier_model_number text,
  add column if not exists supplier_unit text,
  add column if not exists last_seen_at timestamptz,
  add column if not exists seen_count integer not null default 0,
  add column if not exists is_active boolean not null default true,
  add column if not exists source text not null default 'manual';

comment on table public.supplier_product_names is
  'Supplier Product Mapping: what a supplier calls one of our products, kept as written. One row per supplier and product; further spellings are learned as notation dialects.';

-- A plan line tied to one of our products teaches the supplier's writing for
-- it, unless the supplier is the UNKNOWN placeholder. It never stops the plan
-- from being saved.
create or replace function public.delivery_plan_line_maps_supplier()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_sup  bigint;
  v_name text := nullif(btrim(coalesce(new.product_name, '')), '');
  v_code text := nullif(btrim(coalesce(new.product_code, '')), '');
  v_prev text;
begin
  if new.product_id is null
     or (tg_op = 'UPDATE' and new.product_id is not distinct from old.product_id) then
    return null;
  end if;
  select p.supplier_id into v_sup
    from public.delivery_plans p
    join public.delivery_suppliers s on s.id = p.supplier_id
   where p.id = new.delivery_plan_id and coalesce(s.code, '') <> 'UNKNOWN';
  if v_sup is null or (v_name is null and v_code is null) then
    return null;
  end if;
  if v_code is not null and exists (
       select 1 from public.supplier_product_names
        where supplier_id = v_sup and supplier_code = v_code and product_id <> new.product_id) then
    v_code := null;
  end if;
  v_prev := current_setting('wms.learning_lines', true);
  perform set_config('wms.learning_lines', 'on', true);
  begin
    insert into public.supplier_product_names
      (supplier_id, product_id, supplier_code, supplier_name, supplier_jan_code, supplier_maker,
       source, last_seen_at, seen_count)
    values (v_sup, new.product_id, v_code, coalesce(v_name, v_code),
            nullif(btrim(coalesce(new.raw_jan_code, '')), ''), nullif(btrim(coalesce(new.maker, '')), ''),
            'receipt', now(), 1)
    on conflict (supplier_id, product_id) do update set
      supplier_code = coalesce(public.supplier_product_names.supplier_code, excluded.supplier_code),
      supplier_jan_code = coalesce(public.supplier_product_names.supplier_jan_code, excluded.supplier_jan_code),
      supplier_maker = coalesce(public.supplier_product_names.supplier_maker, excluded.supplier_maker),
      last_seen_at = now(),
      seen_count = public.supplier_product_names.seen_count + 1,
      is_active = true;
  exception when others then
    null;
  end;
  perform set_config('wms.learning_lines', coalesce(v_prev, ''), true);
  return null;
end;
$$;

create or replace trigger delivery_plan_line_maps_supplier
  after insert or update of product_id on public.delivery_plan_lines
  for each row execute function public.delivery_plan_line_maps_supplier();

-- How alike two names are: the Dice coefficient of their character pairs,
-- after the same normalising the dictionary uses (0..1).
create or replace function public.text_similarity(a text, b text)
returns numeric
language sql immutable set search_path = '' as $$
  with x as (select public.normalize_product_text(a) as s),
       y as (select public.normalize_product_text(b) as s),
       ga as (select distinct substr(x.s, i, 2) as g from x, generate_series(1, greatest(length(x.s) - 1, 0)) i),
       gb as (select distinct substr(y.s, i, 2) as g from y, generate_series(1, greatest(length(y.s) - 1, 0)) i)
  select case
    when (select s from x) = '' or (select s from y) = '' then 0
    when (select s from x) = (select s from y) then 1
    when (select count(*) from ga) + (select count(*) from gb) = 0 then 0
    else round(2.0 * (select count(*) from ga join gb using (g))
               / ((select count(*) from ga) + (select count(*) from gb)), 3)
  end;
$$;

-- Candidate products for lines nobody could place (§44): identifiers first
-- (the supplier's own code, JAN, our SKU, a model number in the name), then
-- how alike the names are, against our name, English name, other names, every
-- supplier's writing and the readings learned before. Nothing is tied here;
-- the reviewer picks.
create or replace function public.product_match_candidates(
  p_partner_id bigint, p_lines jsonb, p_limit integer default 3)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  e     jsonb;
  i     int := 0;
  v_jan text;
  v_code text;
  v_name text;
  v_maker text;
  out   jsonb := '[]'::jsonb;
  v_lim int := greatest(1, least(coalesce(p_limit, 3), 10));
begin
  if not (public.has_permission('receiving.view') or public.has_permission('product.view')
          or public.has_permission('receiving.confirm')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_jan := nullif(public.normalize_jan(coalesce(e->>'raw_jan_code', e->>'jan_code')), '');
    v_code := nullif(public.normalize_product_text(e->>'product_code'), '');
    v_name := nullif(btrim(coalesce(e->>'product_name', '')), '');
    v_maker := nullif(public.normalize_product_text(e->>'maker'), '');
    out := out || jsonb_build_object(
      'index', coalesce((e->>'index')::int, i),
      'candidates', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'product_id', c.id, 'name', c.name, 'name_en', c.name_en, 'sku', c.sku,
                 'jan_code', c.jan_code, 'maker', c.maker,
                 'score', least(c.score + case when c.maker_hit then 0.03 else 0 end, 0.99),
                 'reasons', c.reasons) order by c.score desc, c.id)
          from (
            select s.* from (
              select p.id, p.name, p.name_en, p.sku, p.jan_code, p.maker,
                     (v_maker is not null and public.normalize_product_text(p.maker) = v_maker) as maker_hit,
                     greatest(k.code_hit, k.jan_hit, k.supplier_jan_hit, k.sku_hit, k.model_hit, k.name_sim * 0.9) as score,
                     to_jsonb(array_remove(array[
                       case when k.code_hit > 0 then 'supplier_code' end,
                       case when k.jan_hit > 0 then 'jan' end,
                       case when k.supplier_jan_hit > 0 then 'supplier_jan' end,
                       case when k.sku_hit > 0 then 'sku' end,
                       case when k.model_hit > 0 then 'model_in_name' end,
                       case when k.name_sim >= 0.3 then 'name' end], null)) as reasons
                from public.products p
                cross join lateral (
                  select
                    case when v_code is not null and exists (
                           select 1 from public.supplier_product_names n
                            where n.product_id = p.id and n.supplier_id = p_partner_id
                              and public.normalize_product_text(n.supplier_code) = v_code)
                         then 0.99 else 0 end as code_hit,
                    case when v_jan is not null and public.normalize_jan(p.jan_code) = v_jan then 0.99 else 0 end as jan_hit,
                    case when v_jan is not null and exists (
                           select 1 from public.supplier_product_names n
                            where n.product_id = p.id and public.normalize_jan(n.supplier_jan_code) = v_jan)
                         then 0.98 else 0 end as supplier_jan_hit,
                    case when v_code is not null and public.normalize_product_text(p.sku) = v_code then 0.95 else 0 end as sku_hit,
                    case when v_code is not null and length(v_code) >= 4
                              and public.normalize_product_text(p.name) like '%' || v_code || '%'
                         then 0.85 else 0 end as model_hit,
                    case when v_name is null then 0 else greatest(
                      public.text_similarity(v_name, p.name),
                      public.text_similarity(v_name, p.name_en),
                      coalesce((select max(public.text_similarity(v_name, pn.name))
                                  from public.product_names pn where pn.product_id = p.id), 0),
                      coalesce((select max(public.text_similarity(v_name, n.supplier_name))
                                  from public.supplier_product_names n where n.product_id = p.id), 0),
                      coalesce((select max(public.text_similarity(v_name, d.raw_value))
                                  from public.notation_dialects d
                                 where d.product_id = p.id and d.field = 'name'), 0)) end as name_sim
                ) k
               where p.status = 'active'
            ) s
             where s.score >= 0.3
             order by s.score desc, s.id
             limit v_lim
          ) c), '[]'::jsonb));
    i := i + 1;
  end loop;
  return out;
end;
$$;

-- The library search also finds a product by a supplier's JAN and by any
-- reading learned from past files (AI認識用別名).
do $$
declare
  d text := pg_get_functiondef('public.list_products(text, text)'::regprocedure);
  v_old text := $x$or n.supplier_code ilike '%' || p_search || '%')))),$x$;
  v_new text := $x$or n.supplier_code ilike '%' || p_search || '%'
                            or n.supplier_jan_code ilike '%' || p_search || '%'
                            or n.supplier_maker ilike '%' || p_search || '%')) or
            exists (select 1 from public.notation_dialects d
                     where d.product_id = p.id
                       and array_to_string(d.raw_values, ' ') ilike '%' || p_search || '%'))),$x$;
begin
  if position(v_old in d) = 0 then
    if position('notation_dialects d' in d) > 0 then
      return;
    end if;
    raise exception 'list_products has changed; update 0135 by hand';
  end if;
  execute replace(d, v_old, v_new);
end $$;

-- Everything that came in for one product (§51, §52): the plans that expected
-- it, each receipt with its inspection, the supplier files behind them, what
-- each supplier calls it and the readings learned for it.
create or replace function public.product_inbound_history(p_product_id bigint, p_limit integer default 100)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_lim int := greatest(1, least(coalesce(p_limit, 100), 500));
begin
  if not (public.has_permission('product.view') or public.has_permission('receiving.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product % not found', p_product_id;
  end if;

  return jsonb_build_object(
    'expected', coalesce((
      select jsonb_agg(x.j order by x.created_at desc) from (
        select dp.created_at, jsonb_build_object(
                 'plan_id', dp.id, 'delivery_number', dp.delivery_number, 'reference_no', dp.reference_no,
                 'supplier_name', dp.supplier_name, 'expected_arrival_date', dp.expected_arrival_date,
                 'receipt_state', dp.receipt_state, 'document_type', dp.document_type,
                 'planned', coalesce(l.planned_quantity, 0), 'received', coalesce(l.received_quantity, 0),
                 'unit_price', l.unit_price, 'supplier_product_name', l.product_name,
                 'supplier_product_code', l.product_code) as j
          from public.delivery_plan_lines l
          join public.delivery_plans dp on dp.id = l.delivery_plan_id
         where l.product_id = p_product_id and dp.status <> 'cancelled'
           and public.can_access_warehouse(coalesce(dp.warehouse_id, public.default_warehouse_id()))
         order by dp.created_at desc limit v_lim) x), '[]'::jsonb),
    'receipts', coalesce((
      select jsonb_agg(x.j order by x.arrived_on desc nulls last, x.id desc) from (
        select r.id, r.arrived_on, jsonb_build_object(
                 'reconciliation_id', r.id, 'plan_id', dp.id, 'delivery_number', dp.delivery_number,
                 'supplier_name', dp.supplier_name, 'arrived_on', r.arrived_on, 'status', r.status,
                 'quantity', coalesce(rl.actual_quantity, 0),
                 'inspection', (select jsonb_build_object(
                     'inspection_id', ins.id, 'status', ins.status, 'result', ii.result,
                     'scheduled_date', ins.scheduled_date, 'started_at', ins.started_at,
                     'completed_at', ins.completed_at,
                     'passed', coalesce(ii.passed_quantity, 0), 'failed', coalesce(ii.failed_quantity, 0))
                   from public.inspection_items ii
                   join public.inspections ins on ins.id = ii.inspection_id
                  where ii.reconciliation_line_id = rl.id
                  order by ii.id limit 1)) as j
          from public.reconciliation_lines rl
          join public.delivery_reconciliations r on r.id = rl.reconciliation_id
          join public.delivery_plans dp on dp.id = r.delivery_plan_id
          left join public.delivery_plan_lines pl on pl.id = rl.plan_line_id
         where coalesce(rl.product_id, pl.product_id) = p_product_id
           and coalesce(rl.actual_quantity, 0) > 0
           and public.can_access_warehouse(coalesce(dp.warehouse_id, public.default_warehouse_id()))
         order by r.arrived_on desc nulls last, r.id desc limit v_lim) x), '[]'::jsonb),
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', d.id, 'file_name', d.file_name, 'content_type', d.content_type,
               'storage_path', d.storage_path, 'document_type', d.document_type,
               'uploaded_at', d.uploaded_at, 'plan_id', d.plan_id, 'supplier_name', d.supplier_name)
             order by d.uploaded_at desc)
        from (select distinct on (doc.id) doc.id, doc.file_name, doc.content_type, doc.storage_path,
                     coalesce(k.document_type, doc.document_type) as document_type, doc.uploaded_at,
                     dp.id as plan_id, dp.supplier_name
                from public.delivery_plan_lines l
                join public.delivery_plans dp on dp.id = l.delivery_plan_id
                left join public.inbound_plan_documents k on k.delivery_plan_id = dp.id
                join public.import_documents doc
                  on doc.id = k.document_id or doc.delivery_plan_id = dp.id
               where l.product_id = p_product_id
                 and public.can_access_warehouse(coalesce(dp.warehouse_id, public.default_warehouse_id()))
               order by doc.id, dp.id
               limit v_lim) d), '[]'::jsonb),
    'supplier_names', coalesce((
      select jsonb_agg(jsonb_build_object(
               'supplier_id', n.supplier_id, 'supplier_display_name', s.name,
               'supplier_name', n.supplier_name, 'supplier_code', n.supplier_code,
               'supplier_jan_code', n.supplier_jan_code, 'supplier_maker', n.supplier_maker,
               'supplier_model_number', n.supplier_model_number, 'supplier_unit', n.supplier_unit,
               'last_seen_at', n.last_seen_at, 'seen_count', n.seen_count,
               'is_active', n.is_active, 'source', n.source) order by s.name)
        from public.supplier_product_names n
        join public.delivery_suppliers s on s.id = n.supplier_id
       where n.product_id = p_product_id), '[]'::jsonb),
    'aliases', coalesce((
      select jsonb_agg(jsonb_build_object(
               'field', d.field, 'values', to_jsonb(d.raw_values), 'partner_id', d.partner_id,
               'partner_name', s.name, 'seen_count', d.seen_count, 'last_seen_at', d.last_seen_at,
               'confirmed', d.confirmed, 'source', d.source) order by d.last_seen_at desc nulls last)
        from public.notation_dialects d
        left join public.delivery_suppliers s on s.id = d.partner_id
       where d.product_id = p_product_id), '[]'::jsonb));
end;
$$;

revoke all on function public.product_match_candidates(bigint, jsonb, integer) from public, anon;
revoke all on function public.product_inbound_history(bigint, integer) from public, anon;
grant execute on function public.text_similarity(text, text) to authenticated, service_role;
grant execute on function public.product_match_candidates(bigint, jsonb, integer) to authenticated, service_role;
grant execute on function public.product_inbound_history(bigint, integer) to authenticated, service_role;
