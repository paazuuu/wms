-- 0155: weights from the makers' catalogs, catalogs from a PDF, and the
-- weights the AI found on the web kept apart.
--
-- * jan_catalog_entries gains the weight the catalog prints for the JAN
--   (weight_g, the text as printed, and what it weighs: the product, its
--   package, or a pack of refills). The jan-catalog function reads it from
--   the page by where it sits: under the JAN (Tombow), or above a group of
--   JANs (Pilot). A weight it cannot place for sure is left out.
-- * A catalog can be a PDF (kind 'pdf'): its text read in the browser, sent
--   page by page; its URL, when given, opens the PDF at the page.
-- * jan_weight_lookups: what the AI found on the web for a JAN with no
--   catalog weight — its own table, never mixed with the catalogs.
-- * A product's weight (products.unit_weight_g) is filled by rule:
--     a person's (manual / measured)  — never replaced here
--     the catalog's (source 'catalog') — replaces the AI's
--     the AI's (source 'web')          — only where there is nothing else
--   on a product's JAN set or changed (a trigger), after a catalog is read,
--   and after an AI lookup is kept.

alter table public.jan_catalogs add column if not exists kind text not null default 'icata';
alter table public.jan_catalogs add column if not exists file_name text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'jan_catalogs_kind_check') then
    alter table public.jan_catalogs add constraint jan_catalogs_kind_check check (kind in ('icata', 'pdf'));
  end if;
end $$;
alter table public.jan_catalogs alter column host set default '';
alter table public.jan_catalogs alter column url set default '';

alter table public.jan_catalog_entries add column if not exists weight_g numeric;
alter table public.jan_catalog_entries add column if not exists weight_text text;
alter table public.jan_catalog_entries add column if not exists weight_basis text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'jan_catalog_entries_weight_check') then
    alter table public.jan_catalog_entries add constraint jan_catalog_entries_weight_check
      check ((weight_g is null or weight_g > 0)
         and (weight_basis is null or weight_basis in ('product', 'package', 'pack')));
  end if;
end $$;

-- What the AI found on the web for a JAN (lookup_spec), one row a JAN.
create table if not exists public.jan_weight_lookups (
  jan text primary key check (jan ~ '^[0-9]{13}$'),
  weight_g numeric check (weight_g is null or weight_g > 0),
  weight_basis text check (weight_basis is null or weight_basis in ('product', 'package')),
  source_url text,
  confidence numeric,
  estimated boolean not null default false,
  note text,
  asked_name text,
  looked_up_at timestamptz not null default now(),
  looked_up_by uuid
);
alter table public.jan_weight_lookups enable row level security;
create policy jan_weight_lookups_read on public.jan_weight_lookups
  for select to authenticated using (public.has_permission('product.view'));
grant select on public.jan_weight_lookups to authenticated;

-- A product's weight may now come from a catalog.
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'products_weight_source_check'
              and pg_get_constraintdef(oid) not like '%catalog%') then
    alter table public.products drop constraint products_weight_source_check;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'products_weight_source_check') then
    alter table public.products add constraint products_weight_source_check
      check (weight_source is null or weight_source in ('manual', 'web', 'measured', 'catalog'));
  end if;
end $$;

-- The viewer at a JAN's page; a PDF at its page when its URL is known.
create or replace function public.jan_catalog_page_url(c public.jan_catalogs, p_page_group text)
returns text language sql immutable set search_path = '' as $$
  select case
    when c.kind = 'pdf' then
      case when coalesce(c.url, '') ~ '^https?://' then c.url || '#page=' || coalesce(p_page_group, '') end
    else 'https://' || c.host || '/iportal/CatalogViewInterfaceStartUpAction.do?method=startUp&mode=PAGE'
      || '&volumeID=' || c.volume_id || '&catalogId=' || c.catalog_id
      || '&pageGroupId=' || coalesce(p_page_group, '')
      || '&designID=' || c.design_id || '&designConfirmFlg='
  end;
$$;

-- The catalog weight for a JAN (the newest catalog that prints one).
create or replace function public.jan_catalog_weight(p_jan text)
returns table (weight_g numeric, weight_text text, weight_basis text, page_url text, catalog_name text)
language sql stable security definer set search_path = '' as $$
  select e.weight_g, e.weight_text, e.weight_basis, public.jan_catalog_page_url(c, e.page_group), c.name
    from public.jan_catalog_entries e join public.jan_catalogs c on c.id = e.catalog_id
   where e.jan = p_jan and e.weight_g is not null
   order by e.catalog_id desc limit 1;
$$;
revoke all on function public.jan_catalog_weight(text) from public, anon;

-- An AI figure good enough to stand as a product's weight: found on a page,
-- not guessed, and sure enough (the same bar 重さをまとめて調べる uses).
create or replace function public.jan_ai_weight(p_jan text)
returns table (weight_g numeric, weight_basis text, source_url text, note text)
language sql stable security definer set search_path = '' as $$
  select l.weight_g, l.weight_basis, l.source_url, l.note
    from public.jan_weight_lookups l
   where l.jan = p_jan and l.weight_g is not null and not l.estimated and coalesce(l.confidence, 0) >= 0.7;
$$;
revoke all on function public.jan_ai_weight(text) from public, anon;

-- Products' weights by the rule above, for these JANs (all when null).
-- Returns how many products changed.
create or replace function public.apply_jan_weights(p_jans text[] default null)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select p.id, p.jan_code, p.unit_weight_g, p.weight_source, cw.weight_g cw_g, cw.weight_text, cw.weight_basis cw_basis,
           cw.page_url, cw.catalog_name, aw.weight_g aw_g, aw.weight_basis aw_basis, aw.source_url aw_url
      from public.products p
      left join lateral public.jan_catalog_weight(p.jan_code) cw on true
      left join lateral public.jan_ai_weight(p.jan_code) aw on true
     where p.jan_code ~ '^[0-9]{13}$'
       and (p_jans is null or p.jan_code = any (p_jans))
       and coalesce(p.weight_source, '') not in ('manual', 'measured')
       and (cw.weight_g is not null or aw.weight_g is not null)
  loop
    if r.cw_g is not null then
      if r.weight_source is distinct from 'catalog' or r.unit_weight_g is distinct from r.cw_g then
        update public.products
           set unit_weight_g = r.cw_g, weight_source = 'catalog', weight_source_url = r.page_url,
               weight_note = concat_ws(' ', r.catalog_name, r.weight_text),
               weight_updated_at = now(), updated_at = now()
         where id = r.id;
        n := n + 1;
      end if;
    elsif r.unit_weight_g is null then
      update public.products
         set unit_weight_g = r.aw_g, weight_source = 'web', weight_source_url = r.aw_url,
             weight_note = 'AI（Web検索）' || case when r.aw_basis = 'package' then '・梱包込み' else '' end,
             weight_updated_at = now(), updated_at = now()
       where id = r.id;
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.apply_jan_weights(text[]) from public, anon, authenticated;
grant execute on function public.apply_jan_weights(text[]) to service_role;

-- A product given a JAN (new, or changed) with no weight a person set: the
-- catalog's, else the AI's, at once.
create or replace function public.products_fill_jan_weight()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  cw record;
  aw record;
begin
  if new.jan_code is null or new.jan_code !~ '^[0-9]{13}$'
     or coalesce(new.weight_source, '') in ('manual', 'measured') then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.jan_code is not distinct from old.jan_code then
    return new;
  end if;
  select * into cw from public.jan_catalog_weight(new.jan_code);
  if cw.weight_g is not null then
    new.unit_weight_g := cw.weight_g;
    new.weight_source := 'catalog';
    new.weight_source_url := cw.page_url;
    new.weight_note := concat_ws(' ', cw.catalog_name, cw.weight_text);
    new.weight_updated_at := now();
    return new;
  end if;
  if new.unit_weight_g is null then
    select * into aw from public.jan_ai_weight(new.jan_code);
    if aw.weight_g is not null then
      new.unit_weight_g := aw.weight_g;
      new.weight_source := 'web';
      new.weight_source_url := aw.source_url;
      new.weight_note := 'AI（Web検索）' || case when aw.weight_basis = 'package' then '・梱包込み' else '' end;
      new.weight_updated_at := now();
    end if;
  end if;
  return new;
end;
$$;
create or replace trigger products_fill_jan_weight before insert or update of jan_code on public.products
  for each row execute function public.products_fill_jan_weight();

-- What the AI found, kept (by whoever may look it up: product.manage), and
-- the products of those JANs given it where they have nothing better.
create or replace function public.jan_weight_save(p_items jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  i jsonb;
  jans text[] := '{}';
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  for i in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    continue when coalesce(i->>'jan', '') !~ '^[0-9]{13}$';
    insert into public.jan_weight_lookups as l
      (jan, weight_g, weight_basis, source_url, confidence, estimated, note, asked_name, looked_up_at, looked_up_by)
    values (i->>'jan',
            nullif(i->>'weight_g', '')::numeric,
            case when i->>'weight_basis' in ('product', 'package') then i->>'weight_basis' end,
            nullif(btrim(coalesce(i->>'source_url', '')), ''),
            nullif(i->>'confidence', '')::numeric,
            coalesce((i->>'estimated')::boolean, false),
            left(nullif(btrim(coalesce(i->>'note', '')), ''), 500),
            left(nullif(btrim(coalesce(i->>'name', '')), ''), 200),
            now(), auth.uid())
    on conflict (jan) do update set
      weight_g = excluded.weight_g, weight_basis = excluded.weight_basis, source_url = excluded.source_url,
      confidence = excluded.confidence, estimated = excluded.estimated, note = excluded.note,
      asked_name = excluded.asked_name, looked_up_at = now(), looked_up_by = auth.uid();
    jans := jans || (i->>'jan');
  end loop;
  if cardinality(jans) > 0 then
    perform public.apply_jan_weights(jans);
  end if;
  return cardinality(jans);
end;
$$;
revoke all on function public.jan_weight_save(jsonb) from public, anon;
grant execute on function public.jan_weight_save(jsonb) to authenticated;

-- Each JAN asked about: what the catalogs say (as jan_catalog_lookup), and
-- its weight as it stands: a product's own (a person's), the catalog's, then
-- the AI's — and where it came from.
create or replace function public.jan_lookup(p_jans text[])
returns table (
  jan text, found boolean, covered boolean, maker text, catalog_name text,
  code_hint text, line_text text, page_number text, page_url text,
  weight_g numeric, weight_source text, weight_text text, weight_basis text, weight_url text,
  weight_estimated boolean)
language sql stable security definer set search_path = '' as $$
  with asked as (
    select distinct j as jan from unnest(coalesce(p_jans, '{}')) j
     where j ~ '^[0-9]{13}$' and public.has_permission('product.view')
     limit 2000
  )
  select a.jan,
         e.jan is not null,
         e.jan is not null or exists (
           select 1 from public.jan_catalog_entries x where left(x.jan, 7) = left(a.jan, 7)),
         c.maker, c.name, e.code_hint, e.line_text, e.page_number,
         case when c.id is not null then public.jan_catalog_page_url(c, e.page_group) end,
         coalesce(pw.unit_weight_g, cw.weight_g, l.weight_g),
         case when pw.unit_weight_g is not null then pw.weight_source
              when cw.weight_g is not null then 'catalog'
              when l.weight_g is not null then 'ai' end,
         case when pw.unit_weight_g is not null then pw.weight_note
              when cw.weight_g is not null then cw.weight_text
              else l.note end,
         case when pw.unit_weight_g is not null then null
              when cw.weight_g is not null then cw.weight_basis
              else l.weight_basis end,
         case when pw.unit_weight_g is not null then pw.weight_source_url
              when cw.weight_g is not null then cw.page_url
              else l.source_url end,
         pw.unit_weight_g is null and cw.weight_g is null and coalesce(l.estimated, false)
    from asked a
    left join lateral (
      select * from public.jan_catalog_entries x where x.jan = a.jan order by x.catalog_id desc limit 1) e on true
    left join public.jan_catalogs c on c.id = e.catalog_id
    left join lateral public.jan_catalog_weight(a.jan) cw on true
    -- A person's weight on a product of this JAN.
    left join lateral (
      select p.unit_weight_g, p.weight_source, p.weight_note, p.weight_source_url
        from public.products p
       where p.jan_code = a.jan and p.unit_weight_g is not null and p.weight_source in ('manual', 'measured')
       order by p.weight_updated_at desc nulls last limit 1) pw on true
    left join public.jan_weight_lookups l on l.jan = a.jan;
$$;
revoke all on function public.jan_lookup(text[]) from public, anon;
grant execute on function public.jan_lookup(text[]) to authenticated;
