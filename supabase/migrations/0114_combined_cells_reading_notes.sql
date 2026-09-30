-- 0114 — reading each company's documents its own way.
--
-- Two real PDFs showed what training could not yet teach:
--   * アケボノクラウン puts メーカー, 品名 and 品番 in one cell, split by ／
--     ("三菱鉛筆／ユニボール エア ０．５ 黒／UBA20105.24"), under a heading
--     that says so ("メーカー/品名/品番");
--   * 新東光通商 (a scan with tight columns) writes a code, the maker in
--     半角カナ and the 品番 in its "商品名・品番" column ("9A ｺｸﾖ ﾌ-CE755P"),
--     and puts the JAN in "備考".
--
--   * `document_fields` gains 'multi': a cell holding several fields. A
--     heading can carry its `parts` (field keys, in order) and `separator`
--     (null = ／ or / when present, else spaces). The last part takes what
--     is left, so a 品番 with a space inside stays whole.
--   * What a company's headings mean, parts included, now reaches the AI
--     reading its PDFs and photos, not only its spreadsheets.
--   * `delivery_suppliers.reading_notes` — a 書式メモ in plain words, given to
--     the AI with every document from that company ("JANは備考欄", …).

insert into public.document_fields (key, sort_order, description)
values ('multi', 46, '複数の項目がまとまった欄（区切って読む）')
on conflict (key) do nothing;

alter table public.column_aliases add column if not exists parts text[];
alter table public.column_aliases add column if not exists separator text;

create or replace function public.column_alias_map(p_partner_id bigint default null)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'header_key', a.header_key, 'header', a.header_raw, 'field', a.field,
           'attribute', pa.key, 'parts', to_jsonb(a.parts), 'separator', a.separator,
           'partner', a.partner_id is not null, 'source', a.source)
         order by (a.partner_id is null)), '[]'::jsonb)
    from public.column_aliases a
    left join public.product_attributes pa on pa.id = a.attribute_id
   where (a.partner_id is null or a.partner_id = p_partner_id)
     and (a.attribute_id is null or pa.status = 'active');
$$;

-- [{header, field, attribute?, parts?, separator?}] as confirmed for this
-- company's file.
create or replace function public.learn_column_aliases(
  p_partner_id bigint, p_map jsonb, p_source text default 'import')
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_key text;
  v_n int := 0;
  g record;
  v_attr bigint;
  v_parts text[];
  v_sep text;
begin
  if not (public.has_permission('receiving.confirm') or public.has_permission('product.manage')
          or public.has_permission('pack.complete')) then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  if p_partner_id is null then
    return 0;
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_map, '[]'::jsonb)) loop
    v_key := public.normalize_product_text(e->>'header');
    continue when nullif(v_key, '') is null or nullif(e->>'field', '') is null;
    continue when not exists (select 1 from public.document_fields where key = e->>'field');
    v_attr := null;
    v_parts := null;
    v_sep := null;
    if e->>'field' = 'attr' then
      select id into v_attr from public.product_attributes where key = e->>'attribute';
      continue when v_attr is null;
    elsif e->>'field' = 'multi' then
      select array_agg(p) into v_parts
        from jsonb_array_elements_text(coalesce(e->'parts', '[]'::jsonb)) p
       where exists (select 1 from public.document_fields f where f.key = p and p not in ('multi', 'attr'));
      continue when coalesce(array_length(v_parts, 1), 0) < 2;
      v_sep := nullif(e->>'separator', '');
    end if;
    -- A heading everyone uses the same way needs no entry of this company's own.
    select field, attribute_id, parts, separator into g from public.column_aliases
     where partner_id is null and header_key = v_key;
    continue when g.field = e->>'field' and g.attribute_id is not distinct from v_attr
              and g.parts is not distinct from v_parts and g.separator is not distinct from v_sep;
    insert into public.column_aliases (partner_id, header_raw, header_key, field, attribute_id, parts, separator, source)
    values (p_partner_id, btrim(e->>'header'), v_key, e->>'field', v_attr, v_parts, v_sep,
            case when p_source in ('manual', 'import', 'ai') then p_source else 'import' end)
    on conflict (coalesce(partner_id, 0), header_key) do update
       set field = excluded.field, attribute_id = excluded.attribute_id,
           parts = excluded.parts, separator = excluded.separator,
           seen_count = column_aliases.seen_count + 1, last_seen_at = now();
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

create or replace function public.list_column_aliases(p_partner_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('purchase_order.view')) then
    raise exception 'not permitted: product.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', a.id, 'partner_id', a.partner_id, 'partner_name', s.name,
             'header', a.header_raw, 'field', a.field,
             'attribute', pa.key, 'attribute_name', pa.name,
             'parts', to_jsonb(a.parts), 'separator', a.separator, 'source', a.source,
             'seen_count', a.seen_count, 'last_seen_at', a.last_seen_at)
           order by (a.partner_id is null), a.field, a.header_raw)
      from public.column_aliases a
      left join public.delivery_suppliers s on s.id = a.partner_id
      left join public.product_attributes pa on pa.id = a.attribute_id
     where p_partner_id is null or a.partner_id = p_partner_id or a.partner_id is null
  ), '[]'::jsonb);
end;
$$;

-- ------------------------------------------------------------ 書式メモ

alter table public.delivery_suppliers add column if not exists reading_notes text;

create or replace function public.set_partner_reading_notes(p_id bigint, p_notes text)
returns text
language plpgsql security definer set search_path = '' as $$
declare v_notes text := nullif(btrim(coalesce(p_notes, '')), '');
begin
  if not (public.has_permission('product.manage') or public.has_permission('partner.manage')) then
    raise exception 'not permitted: product.manage required';
  end if;
  if length(coalesce(v_notes, '')) > 2000 then
    raise exception 'the notes are too long (2000 characters at most)';
  end if;
  update public.delivery_suppliers set reading_notes = v_notes, updated_at = now() where id = p_id;
  if not found then
    raise exception 'trading partner % not found', p_id;
  end if;
  perform public.log_audit('partner.reading_notes_set', 'trading_partner', p_id::text, null,
    jsonb_build_object('notes', v_notes));
  return v_notes;
end;
$$;

create or replace function public.list_trading_partners(
  p_kind text default null,
  p_search text default null,
  p_status text default 'active'
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_permission('partner.view') then
    raise exception 'not permitted: partner.view required';
  end if;
  return coalesce(
    (select jsonb_agg(jsonb_build_object(
        'id', s.id, 'code', s.code, 'name', s.name, 'kind', s.kind,
        'contact_name', s.contact_name, 'phone', s.phone, 'email', s.email,
        'address', s.address, 'payment_terms', s.payment_terms, 'notes', s.notes,
        'status', s.status, 'country_code', s.country_code, 'created_at', s.created_at, 'updated_at', s.updated_at,
        'their_code_for_us', s.their_code_for_us,
        'vendor_codes', (select count(*) from public.partner_vendor_codes c where c.partner_id = s.id),
        'reading_notes', s.reading_notes
      ) order by s.name)
      from public.delivery_suppliers s
     where (p_status is null or s.status = p_status)
       and (p_kind is null or s.kind = p_kind or s.kind = 'both')
       and (p_search is null or p_search = '' or
            s.name ilike '%' || p_search || '%' or
            coalesce(s.code, '') ilike '%' || p_search || '%' or
            coalesce(s.their_code_for_us, '') ilike '%' || p_search || '%')),
    '[]'::jsonb);
end;
$$;

revoke all on function public.set_partner_reading_notes(bigint, text) from public, anon;
grant execute on function public.set_partner_reading_notes(bigint, text) to authenticated, service_role;
grant execute on function public.column_alias_map(bigint) to authenticated, service_role;
grant execute on function public.learn_column_aliases(bigint, jsonb, text) to authenticated, service_role;
grant execute on function public.list_column_aliases(bigint) to authenticated, service_role;
grant execute on function public.list_trading_partners(text, text, text) to authenticated, service_role;
