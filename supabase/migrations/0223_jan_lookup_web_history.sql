-- 0223: JANs for invoices that print none, made surer.
--   * code_jan_lookups: what the AI found on the web for a maker's 品番
--     (or that it found nothing), kept so the same 品番 is not searched for
--     again; code_jan_save keeps only a JAN whose check digit adds up.
--   * maker_jan_prefixes: a maker's company prefixes (the first 7 digits of
--     the JANs we hold for it), which a web answer must start with.
--   * jans_by_code also takes what a person confirmed for the same 品番 on
--     an earlier file (history) and what the web gave before (web).
create table if not exists public.code_jan_lookups (
  id bigint generated always as identity primary key,
  code text not null,
  code_key text not null,
  maker text,
  maker_key text not null default '',
  jan text,
  product_name text,
  source_url text,
  confidence numeric,
  note text,
  looked_at timestamptz not null default now(),
  looked_by uuid
);
create unique index if not exists code_jan_lookups_key on public.code_jan_lookups (code_key, maker_key);
alter table public.code_jan_lookups enable row level security;

create or replace function public.maker_jan_prefixes(p_maker text)
returns text[] language sql stable security definer set search_path = '' as $$
  with m as (select nullif(btrim(normalize(coalesce(p_maker, ''), NFKC)), '') as maker),
  jans as (
    select pr.jan_code as jan from public.products pr, m
     where m.maker is not null and pr.jan_code ~ '^[0-9]{13}$'
       and (strpos(coalesce(pr.maker, ''), m.maker) > 0 or strpos(m.maker, coalesce(nullif(pr.maker, ''), '#')) > 0)
    union all
    select e.jan from public.jan_catalog_entries e join public.jan_catalogs c on c.id = e.catalog_id, m
     where m.maker is not null and e.jan ~ '^[0-9]{13}$' and strpos(coalesce(c.name, ''), m.maker) > 0
  )
  select coalesce(array_agg(p order by n desc), '{}') from (
    select left(jan, 7) as p, count(*) as n from jans group by 1 having count(*) >= 2 order by 2 desc limit 6
  ) x;
$$;
grant execute on function public.maker_jan_prefixes(text) to authenticated, service_role;
revoke execute on function public.maker_jan_prefixes(text) from public, anon;

-- p: [{code, maker, jan, product_name, source_url, confidence, note}]. Kept
-- (or replaced) per 品番 and maker. How many.
create or replace function public.code_jan_save(p jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_e jsonb;
  v_n integer := 0;
  v_code text;
  v_key text;
  v_jan text;
begin
  if not (public.has_permission('inventory.adjust') or public.has_permission('product.manage')) then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  for v_e in select value from jsonb_array_elements(coalesce(p, '[]'::jsonb)) limit 200 loop
    v_code := upper(regexp_replace(normalize(coalesce(v_e->>'code', ''), NFKC), '\s+', '', 'g'));
    v_key := regexp_replace(v_code, '[^A-Z0-9]', '', 'g');
    continue when length(v_key) < 3;
    v_jan := nullif(regexp_replace(coalesce(v_e->>'jan', ''), '[^0-9]', '', 'g'), '');
    if v_jan is not null and not (length(v_jan) = 13 and public.jan_check_ok(v_jan)) then
      v_jan := null;
    end if;
    insert into public.code_jan_lookups (code, code_key, maker, maker_key, jan, product_name, source_url, confidence,
                                         note, looked_at, looked_by)
    values (v_code, v_key, nullif(btrim(v_e->>'maker'), ''),
            lower(regexp_replace(normalize(coalesce(v_e->>'maker', ''), NFKC), '\s+', '', 'g')),
            v_jan, left(nullif(btrim(v_e->>'product_name'), ''), 200), left(nullif(btrim(v_e->>'source_url'), ''), 500),
            case when v_jan is null then 0 else least(greatest(coalesce((v_e->>'confidence')::numeric, 0), 0), 1) end,
            left(nullif(btrim(v_e->>'note'), ''), 300), now(), auth.uid())
    on conflict (code_key, maker_key) do update
      set code = excluded.code, maker = excluded.maker, jan = excluded.jan, product_name = excluded.product_name,
          source_url = excluded.source_url, confidence = excluded.confidence, note = excluded.note,
          looked_at = excluded.looked_at, looked_by = excluded.looked_by;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;
grant execute on function public.code_jan_save(jsonb) to authenticated, service_role;
revoke execute on function public.code_jan_save(jsonb) from public, anon;

-- The 品番 asked about that were looked for on the web lately and not
-- found: not to be searched for again for a while.
create or replace function public.code_jan_recent_misses(p jsonb, p_days integer default 30)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(distinct e->'key'), '[]'::jsonb)
    from jsonb_array_elements(coalesce(p, '[]'::jsonb)) e
   where exists (
     select 1 from public.code_jan_lookups l
      where l.code_key = regexp_replace(upper(normalize(coalesce(e->>'code', ''), NFKC)), '[^A-Z0-9]', '', 'g')
        and l.maker_key = lower(regexp_replace(normalize(coalesce(e->>'maker', ''), NFKC), '\s+', '', 'g'))
        and l.jan is null and l.looked_at > now() - make_interval(days => p_days));
$$;
grant execute on function public.code_jan_recent_misses(jsonb, integer) to authenticated, service_role;
revoke execute on function public.code_jan_recent_misses(jsonb, integer) from public, anon;

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
  v_mkey text;
  v_hist text;
begin
  if not (public.has_permission('inventory.adjust') or public.has_permission('product.view')
          or public.has_permission('product.manage')) then
    raise exception 'not permitted: product.view required';
  end if;
  for v_e in select value from jsonb_array_elements(coalesce(p, '[]'::jsonb)) limit 500 loop
    v_code := upper(regexp_replace(normalize(coalesce(v_e->>'code', ''), NFKC), '\s+', '', 'g'));
    v_key := regexp_replace(v_code, '[^A-Z0-9]', '', 'g');
    v_maker := nullif(btrim(normalize(coalesce(v_e->>'maker', ''), NFKC)), '');
    v_mkey := lower(regexp_replace(coalesce(v_maker, ''), '\s+', '', 'g'));
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

    -- 2b. What a person confirmed for the same 品番 on an earlier file
    -- (the reading kept with the import, checked against the original).
    select r->>'jan' into v_hist
      from public.master_imports i
      cross join lateral jsonb_array_elements(coalesce(i.read_lines, '[]'::jsonb)) r
     where i.undone_at is null
       and regexp_replace(upper(normalize(coalesce(r->>'code', ''), NFKC)), '[^A-Z0-9]', '', 'g') = v_key
       and coalesce(r->>'jan', '') ~ '^[0-9]{13}$'
       and coalesce(r->'flags', '[]'::jsonb) ? 'human_checked'
       and not coalesce(r->'flags', '[]'::jsonb) ? 'human_removed'
       and (v_maker is null or coalesce(r->>'maker', '') = '' or strpos(normalize(r->>'maker', NFKC), v_maker) > 0
            or strpos(v_maker, normalize(r->>'maker', NFKC)) > 0)
     order by i.created_at desc
     limit 1;
    if v_hist is not null and public.jan_check_ok(v_hist) then
      v_out := v_out || jsonb_build_object('key', v_e->'key', 'jan', v_hist, 'source', 'history');
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
      continue;
    end if;

    -- 4. Found on the web before (0223), sure enough and checked.
    select l.jan into v_hist
      from public.code_jan_lookups l
     where l.code_key = v_key and l.jan is not null and coalesce(l.confidence, 0) >= 0.7
       and (l.maker_key = v_mkey or v_mkey = '' or l.maker_key = '')
     order by l.looked_at desc
     limit 1;
    if v_hist is not null then
      v_out := v_out || jsonb_build_object('key', v_e->'key', 'jan', v_hist, 'source', 'web');
    end if;
  end loop;
  return v_out;
end;
$$;
grant execute on function public.jans_by_code(jsonb) to authenticated, service_role;
revoke execute on function public.jans_by_code(jsonb) from public, anon;
