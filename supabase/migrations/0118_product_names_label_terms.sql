-- 0118 — a product's name in every language, and the words labels print.
--
--   * `product_names` holds one row per product and language (ja, en, zh …),
--     so every name of a product can be looked up in one place. Japanese is
--     the product's own name (`products.name`, built in our format, 0111)
--     and is kept in step by a trigger; English is mirrored back into
--     `products.name_en` (0117) so everything that reads it keeps working.
--     Other languages are set with `set_product_name`.
--   * `label_terms` holds the words printed documents and carton labels use
--     (数量 / Qty / 数量, 送り状 / DELIVERY NOTE / 送货单 …), one row per
--     word with its Japanese, English and Chinese. Editable.
--   * `print_settings` says which languages print, in order: the first is
--     the main line, the rest go under it.

create table if not exists public.product_names (
  product_id bigint not null references public.products(id) on delete cascade,
  lang text not null check (lang ~ '^[a-z]{2}$'),
  name text not null check (btrim(name) <> ''),
  source text not null default 'manual' check (source in ('system', 'manual', 'import', 'ai', 'web')),
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (product_id, lang)
);
create index if not exists product_names_lang_name on public.product_names (lang, lower(name));
alter table public.product_names enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'product_names'
                  and policyname = 'product_names: signed-in can read') then
    create policy "product_names: signed-in can read" on public.product_names
      for select to authenticated using (true);
  end if;
end $$;

-- Japanese and English as they already are.
insert into public.product_names (product_id, lang, name, source)
select id, 'ja', name, 'system' from public.products where btrim(coalesce(name, '')) <> ''
on conflict (product_id, lang) do update set name = excluded.name;
insert into public.product_names (product_id, lang, name, source)
select id, 'en', name_en, 'manual' from public.products where btrim(coalesce(name_en, '')) <> ''
on conflict (product_id, lang) do update set name = excluded.name;

-- products.name and name_en stay the source of their two rows, whatever
-- changes them (the name format, set_product_name_en, an import).
create or replace function public.products_sync_names()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if btrim(coalesce(new.name, '')) <> ''
     and (tg_op = 'INSERT' or new.name is distinct from old.name) then
    insert into public.product_names (product_id, lang, name, source)
    values (new.id, 'ja', new.name, 'system')
    on conflict (product_id, lang) do update set name = excluded.name, updated_at = now();
  end if;
  if tg_op = 'INSERT' or new.name_en is distinct from old.name_en then
    if btrim(coalesce(new.name_en, '')) = '' then
      delete from public.product_names where product_id = new.id and lang = 'en';
    else
      insert into public.product_names (product_id, lang, name, source)
      values (new.id, 'en', new.name_en, 'manual')
      on conflict (product_id, lang) do update set name = excluded.name, updated_at = now();
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.products_sync_names() from public, anon, authenticated;

create or replace trigger products_z_sync_names
  after insert or update of name, name_en on public.products
  for each row execute function public.products_sync_names();

-- {lang: name} for one product.
create or replace function public.product_names_of(p_product_id bigint)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(lang, name), '{}'::jsonb)
    from public.product_names where product_id = p_product_id;
$$;

-- A product's name in [p_lang], or null to clear it. Japanese is the
-- product's own name and is changed through its name format (0111).
create or replace function public.set_product_name(p_product_id bigint, p_lang text, p_name text, p_source text default 'manual')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_lang text := lower(btrim(coalesce(p_lang, '')));
  v_name text := public.tidy_text(p_name);
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_lang !~ '^[a-z]{2}$' then
    raise exception 'unknown language %', p_lang;
  end if;
  if v_lang = 'ja' then
    raise exception 'the Japanese name is the product name; change it with its name format';
  end if;
  if not exists (select 1 from public.products where id = p_product_id) then
    raise exception 'product % not found', p_product_id;
  end if;
  if v_lang = 'en' then
    update public.products set name_en = v_name, updated_at = now() where id = p_product_id;
  elsif v_name is null then
    delete from public.product_names where product_id = p_product_id and lang = v_lang;
  else
    insert into public.product_names (product_id, lang, name, source, updated_by)
    values (p_product_id, v_lang, v_name,
            case when p_source in ('manual', 'import', 'ai', 'web') then p_source else 'manual' end, auth.uid())
    on conflict (product_id, lang) do update
       set name = excluded.name, source = excluded.source, updated_at = now(), updated_by = excluded.updated_by;
  end if;
  perform public.log_audit('product.name_set', 'product', p_product_id::text, null,
    jsonb_build_object('lang', v_lang, 'name', v_name));
  return public.product_names_of(p_product_id);
end;
$$;

-- ------------------------------------------------------------ label words

create table if not exists public.label_terms (
  key text primary key check (key ~ '^[a-z_]+$'),
  ja text not null,
  en text not null,
  zh text not null,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.label_terms enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'label_terms'
                  and policyname = 'label_terms: signed-in can read') then
    create policy "label_terms: signed-in can read" on public.label_terms
      for select to authenticated using (true);
  end if;
end $$;

insert into public.label_terms (key, ja, en, zh, sort_order) values
  ('shipment_no', '出庫番号', 'Shipment No.', '出库单号', 10),
  ('ref_no', '整理番号', 'Ref. No.', '参考编号', 11),
  ('customer', '得意先', 'Customer', '客户', 12),
  ('customer_code', 'お客様コード', 'Customer code', '客户代码', 13),
  ('date', '日付', 'Date', '日期', 14),
  ('issued', '発行日', 'Issued', '开具日期', 15),
  ('ship_from', '出荷元', 'Ship from', '发货地', 16),
  ('destination', '仕向国', 'Destination', '目的国', 17),
  ('cartons', '箱数', 'Cartons', '箱数', 18),
  ('jan', 'JANコード', 'JAN', 'JAN码', 20),
  ('maker', 'メーカー', 'Maker', '制造商', 21),
  ('product', '品名', 'Product', '品名', 22),
  ('item_code', '品番', 'Item code', '货号', 23),
  ('spec', '規格', 'Spec', '规格', 24),
  ('qty', '数量', 'Qty', '数量', 25),
  ('unit_price', '単価', 'Unit price', '单价', 26),
  ('amount', '金額', 'Amount', '金额', 27),
  ('total', '合計', 'Total', '合计', 28),
  ('barcode', 'バーコード', 'Barcode', '条码', 29),
  ('shipping_list', '出庫リスト', 'Shipping List', '出库清单', 40),
  ('packing_list', '内容リスト', 'Packing List', '装箱清单', 41),
  ('packing_list_by_carton', '段ボール別 内容リスト', 'Packing List by Carton', '分箱装箱清单', 42),
  ('carton', '段ボール', 'Carton', '纸箱', 43),
  ('delivery_note', '送り状', 'DELIVERY NOTE', '送货单', 44),
  ('delivery_note_lead', '下記の通り納品いたします。', 'Please find the goods listed below.', '兹按下列明细交货。', 45),
  ('label_shipment', '出庫', 'Shipment', '出库', 60),
  ('label_box', '箱', 'Box', '箱', 61),
  ('label_qty', '数量', 'Qty', '数量', 62),
  ('label_lot', 'ロット', 'Lot', '批次', 63),
  ('label_items', '品目', 'items', '种', 64)
on conflict (key) do nothing;

create table if not exists public.print_settings (
  id integer primary key default 1 check (id = 1),
  languages text[] not null default array['ja', 'en'],
  updated_at timestamptz not null default now()
);
alter table public.print_settings enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'print_settings'
                  and policyname = 'print_settings: signed-in can read') then
    create policy "print_settings: signed-in can read" on public.print_settings
      for select to authenticated using (true);
  end if;
end $$;
insert into public.print_settings (id) values (1) on conflict (id) do nothing;

-- The words and the languages, in one read for the printer.
create or replace function public.print_language()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'languages', (select to_jsonb(languages) from public.print_settings where id = 1),
    'terms', coalesce((select jsonb_object_agg(key, jsonb_build_object('ja', ja, 'en', en, 'zh', zh))
                         from public.label_terms), '{}'::jsonb),
    'term_list', coalesce((select jsonb_agg(jsonb_build_object('key', key, 'ja', ja, 'en', en, 'zh', zh)
                                             order by sort_order, key) from public.label_terms), '[]'::jsonb));
$$;

-- Which languages print, in order (the first is the main line).
create or replace function public.set_print_languages(p_languages text[])
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v text[];
begin
  if not (public.has_permission('pack.complete') or public.has_permission('product.manage')) then
    raise exception 'not permitted: pack.complete required';
  end if;
  select array_agg(l order by ord) into v
    from (select distinct on (l) l, ord
            from unnest(p_languages) with ordinality as t(l, ord)
           where l in ('ja', 'en', 'zh') order by l, ord) x;
  if coalesce(array_length(v, 1), 0) = 0 then
    raise exception 'choose at least one language';
  end if;
  update public.print_settings set languages = v, updated_at = now() where id = 1;
  perform public.log_audit('print.languages_set', 'print_settings', '1', null, jsonb_build_object('languages', v));
  return public.print_language();
end;
$$;

-- One word in its three languages.
create or replace function public.set_label_term(p_key text, p_ja text, p_en text, p_zh text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not (public.has_permission('pack.complete') or public.has_permission('product.manage')) then
    raise exception 'not permitted: pack.complete required';
  end if;
  if public.tidy_text(p_ja) is null or public.tidy_text(p_en) is null or public.tidy_text(p_zh) is null then
    raise exception 'every language needs a word';
  end if;
  update public.label_terms
     set ja = public.tidy_text(p_ja), en = public.tidy_text(p_en), zh = public.tidy_text(p_zh), updated_at = now()
   where key = p_key;
  if not found then
    raise exception 'unknown label word %', p_key;
  end if;
  return public.print_language();
end;
$$;

-- Every name of the products a document prints, by JAN, in one read.
create or replace function public.product_names_by_jan(p_jans text[])
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(p.jan_code, public.product_names_of(p.id)), '{}'::jsonb)
    from public.products p
   where p.jan_code = any(coalesce(p_jans, '{}'));
$$;

-- The product lists carry every name, and find a product by any of them.
create or replace function public.list_products(p_search text default null, p_status text default 'active')
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('product.view') then
    raise exception 'not permitted: product.view required';
  end if;

  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', p.id, 'jan_code', p.jan_code, 'name', p.name, 'name_en', p.name_en,
        'names', public.product_names_of(p.id),
        'category', p.category, 'price', p.price, 'status', p.status,
        'sku', p.sku, 'tracking_mode', p.tracking_mode,
        'picking_rule', p.picking_rule,
        'requires_inspection', p.requires_inspection,
        'maker', p.maker,
        'unit_weight_g', p.unit_weight_g, 'weight_source', p.weight_source,
        'weight_source_url', p.weight_source_url, 'weight_note', p.weight_note,
        'created_at', p.created_at, 'updated_at', p.updated_at,
        'base_uom', (select jsonb_build_object('id', u.id, 'code', u.code, 'name', u.name)
                       from public.uoms u where u.id = p.base_uom_id),
        'uoms', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'code', u.code, 'name', u.name,
                   'conversion_factor', pu.conversion_factor,
                   'is_base', pu.uom_id = p.base_uom_id,
                   'package_weight_g', pu.package_weight_g,
                   'gross_weight_g', pu.gross_weight_g,
                   'pack_weight_g', public.pack_weight_g(p.id, pu.uom_id))
                 order by pu.conversion_factor)
            from public.product_uoms pu
            join public.uoms u on u.id = pu.uom_id
           where pu.product_id = p.id), '[]'::jsonb),
        'barcodes', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'id', b.id, 'barcode', b.barcode,
                   'barcode_type', b.barcode_type,
                   'is_primary', b.is_primary,
                   'quantity_per_scan', b.quantity_per_scan,
                   'uom', (select u.code from public.uoms u where u.id = b.uom_id))
                 order by b.is_primary desc, b.barcode)
            from public.product_barcodes b where b.product_id = p.id
        ), '[]'::jsonb),
        'supplier_names', coalesce((
          select jsonb_agg(jsonb_build_object(
                   'supplier_id', n.supplier_id, 'supplier_display_name', s.name,
                   'supplier_code', n.supplier_code, 'supplier_name', n.supplier_name)
                 order by s.name)
            from public.supplier_product_names n
            join public.delivery_suppliers s on s.id = n.supplier_id
           where n.product_id = p.id), '[]'::jsonb)
      ) order by p.name)
      from public.products p
     where (p_status is null or p.status = p_status)
       and (p_search is null or p_search = '' or
            p.name ilike '%' || p_search || '%' or
            p.name_en ilike '%' || p_search || '%' or
            exists (select 1 from public.product_names pn
                     where pn.product_id = p.id and pn.name ilike '%' || p_search || '%') or
            p.jan_code ilike '%' || p_search || '%' or
            p.sku ilike '%' || p_search || '%' or
            p.maker ilike '%' || p_search || '%' or
            exists (select 1 from public.product_barcodes b
                     where b.product_id = p.id
                       and b.barcode ilike '%' ||
                           coalesce(public.normalize_barcode(p_search), p_search) || '%') or
            exists (select 1 from public.supplier_product_names n
                     where n.product_id = p.id
                       and (n.supplier_name ilike '%' || p_search || '%'
                            or n.supplier_code ilike '%' || p_search || '%')))),
    '[]'::jsonb);
end;
$$;

create or replace function public.product_library(
  p_query text default null,
  p_without_images boolean default false,
  p_limit int default 60,
  p_offset int default 0
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_q text := nullif(trim(p_query), '');
begin
  if not public.can_view_product_images() then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(t)::jsonb order by t.name, t.id)
      from (
        select p.id, p.jan_code, p.name, p.name_en, public.product_names_of(p.id) as names, p.sku, p.maker, p.category, p.status,
               f.storage_path, coalesce(f.n, 0) as image_count
          from public.products p
          left join lateral (
            select i.storage_path, count(*) over () as n
              from public.product_images i
             where i.product_id = p.id and i.withdrawn_at is null
             order by i.position, i.id limit 1
          ) f on true
         where (v_q is null
                or p.name ilike '%' || v_q || '%'
                or p.name_en ilike '%' || v_q || '%'
                or exists (select 1 from public.product_names pn
                            where pn.product_id = p.id and pn.name ilike '%' || v_q || '%')
                or p.jan_code like '%' || regexp_replace(v_q, '\D', '', 'g') || '%' and regexp_replace(v_q, '\D', '', 'g') <> ''
                or p.sku ilike '%' || v_q || '%'
                or p.maker ilike '%' || v_q || '%')
           and (not p_without_images or f.storage_path is null)
         order by p.name, p.id
         limit greatest(1, least(coalesce(p_limit, 60), 200)) offset greatest(0, coalesce(p_offset, 0))
      ) t), '[]'::jsonb);
end;
$$;

revoke all on function public.product_names_of(bigint) from public, anon;
revoke all on function public.product_names_by_jan(text[]) from public, anon;
revoke all on function public.set_product_name(bigint, text, text, text) from public, anon;
revoke all on function public.print_language() from public, anon;
revoke all on function public.set_print_languages(text[]) from public, anon;
revoke all on function public.set_label_term(text, text, text, text) from public, anon;
grant execute on function public.product_names_of(bigint) to authenticated, service_role;
grant execute on function public.product_names_by_jan(text[]) to authenticated, service_role;
grant execute on function public.set_product_name(bigint, text, text, text) to authenticated, service_role;
grant execute on function public.print_language() to authenticated, service_role;
grant execute on function public.set_print_languages(text[]) to authenticated, service_role;
grant execute on function public.set_label_term(text, text, text, text) to authenticated, service_role;
