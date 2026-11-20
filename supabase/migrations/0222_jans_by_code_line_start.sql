-- 0222: jans_by_code also takes a catalog line that starts with the code
-- ("LFBTRF30EF3B ブラック | 49-02505-437847 | …"): the entry's own JAN.
create or replace function public.jans_by_code(p jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_e jsonb;
  v_out jsonb := '[]'::jsonb;
  v_code text;
  v_key text;
  v_maker text;
  v_esc text;
  v_jans text[];
  v_pid bigint;
  v_cat text;
begin
  if not (public.has_permission('inventory.adjust') or public.has_permission('product.view')
          or public.has_permission('product.manage')) then
    raise exception 'not permitted: product.view required';
  end if;
  for v_e in select value from jsonb_array_elements(coalesce(p, '[]'::jsonb)) limit 500 loop
    v_code := upper(regexp_replace(normalize(coalesce(v_e->>'code', ''), NFKC), '\s+', '', 'g'));
    v_key := regexp_replace(v_code, '[^A-Z0-9]', '', 'g');
    v_maker := nullif(btrim(normalize(coalesce(v_e->>'maker', ''), NFKC)), '');
    continue when length(v_key) < 3;
    v_jans := null;
    v_pid := null;
    v_cat := null;

    -- 1. Our own products, by their 品番 (and maker, when both say one).
    select array_agg(distinct pr.jan_code), min(pr.id) into v_jans, v_pid
      from public.products pr
     where regexp_replace(upper(normalize(coalesce(pr.sku, ''), NFKC)), '[^A-Z0-9]', '', 'g') = v_key
       and pr.jan_code ~ '^[0-9]{8,14}$'
       and (v_maker is null or pr.maker is null or strpos(pr.maker, v_maker) > 0 or strpos(v_maker, pr.maker) > 0);
    if coalesce(array_length(v_jans, 1), 0) = 1 then
      v_out := v_out || jsonb_build_object('key', v_e->'key', 'jan', v_jans[1], 'source', 'library', 'product_id', v_pid);
      continue;
    end if;

    -- 2. The code a supplier uses for one of our products.
    select array_agg(distinct pr.jan_code), min(pr.id) into v_jans, v_pid
      from public.supplier_product_names s
      join public.products pr on pr.id = s.product_id
     where s.is_active is not false
       and v_key in (regexp_replace(upper(normalize(coalesce(s.supplier_code, ''), NFKC)), '[^A-Z0-9]', '', 'g'),
                     regexp_replace(upper(normalize(coalesce(s.supplier_model_number, ''), NFKC)), '[^A-Z0-9]', '', 'g'))
       and pr.jan_code ~ '^[0-9]{8,14}$';
    if coalesce(array_length(v_jans, 1), 0) = 1 then
      v_out := v_out || jsonb_build_object('key', v_e->'key', 'jan', v_jans[1], 'source', 'supplier', 'product_id', v_pid);
      continue;
    end if;

    -- 3. The makers' catalogs: the code with its JAN right after it, or
    -- "コード<code>" on an entry that is one JAN. The maker's own catalog
    -- first, when the line names a maker.
    v_esc := regexp_replace(v_code, '([.^$*+?()\[\]{}|\\-])', '\\\1', 'g');
    with hits as (
      select c.name as catalog, m[1] as jan,
             (v_maker is not null and strpos(coalesce(c.name, ''), v_maker) > 0) as own
        from public.jan_catalog_entries e
        join public.jan_catalogs c on c.id = e.catalog_id
        cross join lateral regexp_matches(e.line_text,
               '(?:^|JAN|コード|[^A-Z.])' || v_esc || '(?:JAN)?([0-9]{13})(?![0-9])', 'g') m
       where e.line_text like '%' || v_code || '%'
      union all
      select c.name, e.jan, (v_maker is not null and strpos(coalesce(c.name, ''), v_maker) > 0)
        from public.jan_catalog_entries e
        join public.jan_catalogs c on c.id = e.catalog_id
       where e.line_text like '%' || v_code || '%'
         and e.line_text ~ ('(?:^|コード)' || v_esc || '(?![A-Z0-9.])')
         and e.jan ~ '^[0-9]{13}$'
    ), ok as (
      select * from hits where public.jan_check_ok(jan)
    ), pick as (
      select * from ok where own or not exists (select 1 from ok where own)
    )
    select array_agg(distinct jan), min(catalog) into v_jans, v_cat from pick;
    if coalesce(array_length(v_jans, 1), 0) = 1 then
      v_out := v_out || jsonb_build_object('key', v_e->'key', 'jan', v_jans[1], 'source', 'catalog', 'catalog', v_cat);
    end if;
  end loop;
  return v_out;
end;
$$;
grant execute on function public.jans_by_code(jsonb) to authenticated, service_role;
revoke execute on function public.jans_by_code(jsonb) from public, anon;
