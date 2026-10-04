-- 0130 — 商品ライブラリー registration without required fields, and alerts.
--
--   * `products.jan_code` may be empty: a product needs no JAN, maker, name,
--     品番, colour, weight or size to be registered. A product without a
--     name is called by its 品番 or JAN, else 名称未設定.
--   * A JAN (or 品番, which the table keeps unique) that is already in the
--     library is an alert, never an overwrite:
--       - `products_add_one(p)` (by hand) refuses it, naming the product
--         that has it, so the screen can say which.
--       - `products_import(lines, file)` (from a file) registers every line
--         without one and keeps each alerted line in
--         `product_import_alerts`: the line as read, why (JAN already in the
--         library, JAN twice in the file, 品番 already used), the product it
--         collides with, the file and row.
--   * Alerts are read and removed under RLS (product.view / product.manage):
--     removing is a row removal, one, some or all.

alter table public.products alter column jan_code drop not null;

create table if not exists public.product_import_alerts (
  id bigserial primary key,
  reason text not null check (reason in ('jan_exists', 'jan_in_file', 'sku_exists')),
  line jsonb not null,
  jan_code text,
  maker text,
  name text,
  item_code text,
  existing_product_id bigint references public.products(id) on delete set null,
  existing_name text,
  existing_maker text,
  existing_sku text,
  source_file text,
  row_no int,
  created_at timestamptz not null default now(),
  created_by uuid
);
create index if not exists product_import_alerts_created on public.product_import_alerts (created_at desc);
alter table public.product_import_alerts enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'product_import_alerts'
                  and policyname = 'product_import_alerts: viewers can read') then
    create policy "product_import_alerts: viewers can read" on public.product_import_alerts
      for select to authenticated using (public.has_permission('product.view'));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'product_import_alerts'
                  and policyname = 'product_import_alerts: managers can remove') then
    create policy "product_import_alerts: managers can remove" on public.product_import_alerts
      for delete to authenticated using (public.has_permission('product.manage'));
  end if;
end $$;
grant select, delete on public.product_import_alerts to authenticated;

-- One product's fields from a line or a form; null when the line has none.
create or replace function public.product_line_name(e jsonb, p_jan text)
returns text
language sql immutable set search_path = '' as $$
  select coalesce(public.tidy_text(e->>'product_name'), public.tidy_text(e->>'name'), public.tidy_text(e->>'base_name'),
                  public.tidy_text(e->>'product_code'), public.tidy_text(e->>'sku'), p_jan, '名称未設定');
$$;

-- A new product from [e] (a read line or the form). Internal: the callers
-- check permissions and collisions first.
create or replace function public.product_insert_from(e jsonb, p_jan text, p_from text, p_file text)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_company bigint;
  v_spec jsonb := public.price_book_line_spec(e);
  v_code text := coalesce(public.tidy_text(e->>'product_code'), public.tidy_text(e->>'sku'));
  v_pid bigint;
begin
  select id into v_company from public.companies order by id limit 1;
  insert into public.products
    (company_id, jan_code, name, maker, sku, base_name, unit, list_price, price, category,
     unit_weight_g, weight_source, weight_note, width_mm, depth_mm, height_mm, size_note, size_source)
  values (v_company, p_jan, public.product_line_name(e, p_jan), public.tidy_text(e->>'maker'), v_code,
          public.tidy_text(e->>'base_name'), public.tidy_text(e->>'unit'),
          nullif(e->>'list_price', '')::numeric, nullif(e->>'price', '')::numeric, public.tidy_text(e->>'category'),
          (v_spec->>'weight_g')::numeric, case when v_spec ? 'weight_g' then 'manual' end,
          case when v_spec ? 'weight_g' and p_from = 'file' then 'ファイルから' end,
          (v_spec->>'width_mm')::numeric, (v_spec->>'depth_mm')::numeric, (v_spec->>'height_mm')::numeric,
          v_spec->>'size_note',
          case when v_spec ?| array['width_mm', 'depth_mm', 'height_mm', 'size_note']
               then case when p_from = 'file' then 'file' else 'manual' end end)
  returning id into v_pid;
  perform public.product_put_attributes(v_pid, e->'attributes');
  perform public.log_audit('product.created', 'product', v_pid::text, null,
    jsonb_build_object('jan_code', p_jan, 'from', p_from, 'file', p_file));
  return v_pid;
end;
$$;
revoke all on function public.product_insert_from(jsonb, text, text, text) from public, anon, authenticated;

-- A JAN as kept: digits when it reads as one (8 or 13), else as written.
create or replace function public.product_line_jan(e jsonb)
returns text
language sql immutable set search_path = '' as $$
  select case when length(public.normalize_jan(coalesce(nullif(e->>'raw_jan_code', ''), e->>'jan_code'))) in (8, 13)
              then public.normalize_jan(coalesce(nullif(e->>'raw_jan_code', ''), e->>'jan_code'))
              else public.tidy_text(coalesce(nullif(e->>'raw_jan_code', ''), e->>'jan_code')) end;
$$;

-- By hand: every field optional. A JAN or 品番 already in the library is
-- refused with the product that has it ("jan_exists:<id>:<name>").
create or replace function public.products_add_one(p jsonb)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_jan text := public.product_line_jan(p);
  v_code text := coalesce(public.tidy_text(p->>'product_code'), public.tidy_text(p->>'sku'));
  v_hit record;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_jan is not null then
    select id, name into v_hit from public.products where jan_code = v_jan limit 1;
    if found then
      raise exception 'jan_exists:%:%', v_hit.id, v_hit.name;
    end if;
  end if;
  if v_code is not null then
    select id, name into v_hit from public.products where sku = v_code limit 1;
    if found then
      raise exception 'sku_exists:%:%', v_hit.id, v_hit.name;
    end if;
  end if;
  return public.product_insert_from(p, v_jan, 'manual', null);
end;
$$;
revoke all on function public.products_add_one(jsonb) from public, anon;
grant execute on function public.products_add_one(jsonb) to authenticated, service_role;

-- From a file: every line without an alert is registered; each alerted
-- line is kept in product_import_alerts. Replaces 0129's update-by-JAN.
create or replace function public.products_import(p_lines jsonb, p_source_file text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  e jsonb;
  v_row int := 0;
  v_jan text;
  v_code text;
  v_hit record;
  v_reason text;
  v_pid bigint;
  v_created int := 0;
  v_alerts int := 0;
  v_ids bigint[] := '{}';
  v_seen_jans text[] := '{}';
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_row := v_row + 1;
    v_jan := public.product_line_jan(e);
    v_code := coalesce(public.tidy_text(e->>'product_code'), public.tidy_text(e->>'sku'));
    v_reason := null;
    -- A line with nothing on it is no product.
    continue when v_jan is null and v_code is null and public.tidy_text(e->>'maker') is null
              and coalesce(public.tidy_text(e->>'product_name'), public.tidy_text(e->>'name'),
                           public.tidy_text(e->>'base_name')) is null;
    if v_jan is not null and v_jan = any(v_seen_jans) then
      v_reason := 'jan_in_file';
      select id, name, maker, sku into v_hit from public.products where jan_code = v_jan limit 1;
    elsif v_jan is not null then
      select id, name, maker, sku into v_hit from public.products where jan_code = v_jan limit 1;
      if v_hit.id is not null then v_reason := 'jan_exists'; end if;
    end if;
    if v_reason is null and v_code is not null then
      select id, name, maker, sku into v_hit from public.products where sku = v_code limit 1;
      if v_hit.id is not null then v_reason := 'sku_exists'; end if;
    end if;
    if v_jan is not null then v_seen_jans := v_seen_jans || v_jan; end if;
    if v_reason is not null then
      insert into public.product_import_alerts
        (reason, line, jan_code, maker, name, item_code, existing_product_id, existing_name, existing_maker,
         existing_sku, source_file, row_no, created_by)
      values (v_reason, e, v_jan, public.tidy_text(e->>'maker'), public.product_line_name(e, v_jan), v_code,
              v_hit.id, v_hit.name, v_hit.maker, v_hit.sku, p_source_file, v_row, auth.uid());
      v_alerts := v_alerts + 1;
      continue;
    end if;
    v_pid := public.product_insert_from(e, v_jan, 'file', p_source_file);
    v_created := v_created + 1;
    v_ids := v_ids || v_pid;
  end loop;
  perform public.log_audit('product.imported', 'product', coalesce(p_source_file, ''), null,
    jsonb_build_object('created', v_created, 'alerts', v_alerts));
  return jsonb_build_object('created', v_created, 'alerts', v_alerts, 'ids', to_jsonb(v_ids));
end;
$$;
revoke all on function public.products_import(jsonb, text) from public, anon;
grant execute on function public.products_import(jsonb, text) to authenticated, service_role;
