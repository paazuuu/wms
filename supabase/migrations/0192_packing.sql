-- 0192: 梱包（パッキング） — boxes worked out, checked on the floor, and the
-- packing list made from them.
--
-- * product_case_packs: a product's own case (メーカーの元箱) — how many go in
--   one, its size, what a full one weighs; written by hand or learned from a
--   packing list read in (source 'packing_list'), a hand-written one never
--   overwritten by a learned one.
-- * outbound_packages / outbound_package_lines: the boxes of one shipping list
--   (0188): number, mark (注番 group: BL, HL …), the carton (carton_types,
--   0115) or the product's own case, size, empty weight, the weight worked
--   out and the one weighed, when it was checked; and what is in each.
--   A new plan takes the old boxes away (removed_at), never wiped out.
-- * outbound_packing_lists: packing lists kept — read in (the original and
--   the version in the clear layout) or made from the boxes — with their
--   shipping list when there is one.
-- Seen by can_view_outbound, written by can_post_outbound (0188).

create table if not exists public.product_case_packs (
  product_id bigint primary key references public.products(id),
  case_quantity integer not null check (case_quantity > 0),
  length_cm numeric(8, 1),
  width_cm numeric(8, 1),
  height_cm numeric(8, 1),
  gross_kg numeric(10, 3),
  source text not null default 'manual' check (source in ('manual', 'packing_list')),
  seen_count integer not null default 1,
  active boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid()
);
alter table public.product_case_packs enable row level security;

create table if not exists public.outbound_packages (
  id bigint generated always as identity primary key,
  file_id bigint not null references public.outbound_files(id),
  box_no integer not null,
  mark text,
  carton_type_id bigint references public.carton_types(id),
  own_case boolean not null default false,
  length_cm numeric(8, 1),
  width_cm numeric(8, 1),
  height_cm numeric(8, 1),
  tare_kg numeric(10, 3),
  est_kg numeric(10, 3),
  gross_kg numeric(10, 3),
  note text,
  checked_at timestamptz,
  checked_by uuid,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  removed_at timestamptz
);
alter table public.outbound_packages enable row level security;
create index if not exists outbound_packages_file on public.outbound_packages (file_id, mark, box_no) where removed_at is null;

create table if not exists public.outbound_package_lines (
  id bigint generated always as identity primary key,
  package_id bigint not null references public.outbound_packages(id),
  file_line_id bigint references public.outbound_file_lines(id),
  product_id bigint references public.products(id),
  jan_code text,
  item_code text,
  product_name text,
  maker text,
  quantity integer not null check (quantity >= 0),
  checked boolean not null default false
);
alter table public.outbound_package_lines enable row level security;
create index if not exists outbound_package_lines_package on public.outbound_package_lines (package_id);

create table if not exists public.outbound_packing_lists (
  id bigint generated always as identity primary key,
  warehouse_id bigint not null references public.warehouses(id),
  file_id bigint references public.outbound_files(id),
  source text not null check (source in ('upload', 'generated')),
  original_name text,
  original_path text,
  improved_name text,
  improved_path text,
  boxes integer,
  quantity integer,
  gross_kg numeric(12, 3),
  cbm numeric(12, 4),
  note text,
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  removed_at timestamptz
);
alter table public.outbound_packing_lists enable row level security;
create index if not exists outbound_packing_lists_day on public.outbound_packing_lists (warehouse_id, created_at) where removed_at is null;

-- ---------------------------------------------------------------- 元箱と入数
create or replace function public.case_packs_list()
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.can_view_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'product_id', c.product_id, 'jan', p.jan_code, 'name', p.name, 'maker', p.maker, 'sku', p.sku,
             'unit_weight_g', p.unit_weight_g, 'case_quantity', c.case_quantity, 'length_cm', c.length_cm,
             'width_cm', c.width_cm, 'height_cm', c.height_cm, 'gross_kg', c.gross_kg, 'source', c.source,
             'seen_count', c.seen_count, 'updated_at', c.updated_at) order by p.maker nulls last, p.name)
      from public.product_case_packs c
      join public.products p on p.id = c.product_id
     where c.active), '[]'::jsonb);
end;
$$;
revoke all on function public.case_packs_list() from public, anon;
grant execute on function public.case_packs_list() to authenticated;

-- [p_rows]: [{product_id, case_quantity, length_cm, width_cm, height_cm,
-- gross_kg}]. [p_source] 'manual' writes over anything; 'packing_list' (what
-- a packing list showed) leaves a hand-written one as it is.
create or replace function public.case_packs_save(p_rows jsonb, p_source text default 'manual')
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_row jsonb;
  v_n integer := 0;
  v_pid bigint;
  v_q integer;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  if p_source not in ('manual', 'packing_list') then
    raise exception 'case_pack_source';
  end if;
  for v_row in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    v_pid := nullif(v_row->>'product_id', '')::bigint;
    v_q := public.price_num(v_row->>'case_quantity')::integer;
    if v_pid is null or coalesce(v_q, 0) <= 0 or not exists (select 1 from public.products where id = v_pid) then
      continue;
    end if;
    insert into public.product_case_packs as c (product_id, case_quantity, length_cm, width_cm, height_cm, gross_kg, source)
    values (v_pid, v_q, public.price_num(v_row->>'length_cm'), public.price_num(v_row->>'width_cm'),
            public.price_num(v_row->>'height_cm'), public.price_num(v_row->>'gross_kg'), p_source)
    on conflict (product_id) do update set
      case_quantity = excluded.case_quantity,
      length_cm = coalesce(excluded.length_cm, c.length_cm),
      width_cm = coalesce(excluded.width_cm, c.width_cm),
      height_cm = coalesce(excluded.height_cm, c.height_cm),
      gross_kg = coalesce(excluded.gross_kg, c.gross_kg),
      source = excluded.source,
      seen_count = c.seen_count + 1,
      active = true,
      updated_at = now(), updated_by = auth.uid()
     where p_source = 'manual' or c.source = 'packing_list' or not c.active;
    v_n := v_n + 1;
  end loop;
  perform public.log_audit('packing.case_packs_saved', 'product_case_pack', null, null,
    jsonb_build_object('rows', v_n, 'source', p_source));
  return v_n;
end;
$$;
revoke all on function public.case_packs_save(jsonb, text) from public, anon;
grant execute on function public.case_packs_save(jsonb, text) to authenticated;

create or replace function public.case_pack_retire(p_product_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  update public.product_case_packs set active = false, updated_at = now(), updated_by = auth.uid()
   where product_id = p_product_id and active;
  return found;
end;
$$;
revoke all on function public.case_pack_retire(bigint) from public, anon;
grant execute on function public.case_pack_retire(bigint) to authenticated;

-- ------------------------------------------------------------- the boxes
create or replace function public.outbound_packing_get(p_file_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
begin
  if auth.uid() is null or not public.can_view_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_file_id;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_file_id;
  end if;
  return jsonb_build_object('file_id', p_file_id, 'boxes', coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', b.id, 'box_no', b.box_no, 'mark', b.mark, 'carton_type_id', b.carton_type_id,
             'carton_type', t.name, 'own_case', b.own_case, 'length_cm', b.length_cm, 'width_cm', b.width_cm,
             'height_cm', b.height_cm, 'tare_kg', b.tare_kg, 'est_kg', b.est_kg, 'gross_kg', b.gross_kg,
             'note', b.note, 'checked_at', b.checked_at, 'checked_by_name', public.user_display_name(b.checked_by),
             'lines', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', l.id, 'file_line_id', l.file_line_id, 'product_id', l.product_id, 'jan', l.jan_code,
                 'code', l.item_code, 'name', l.product_name, 'maker', l.maker, 'quantity', l.quantity,
                 'checked', l.checked, 'unit_weight_g', p.unit_weight_g) order by l.id)
               from public.outbound_package_lines l
               left join public.products p on p.id = l.product_id
              where l.package_id = b.id), '[]'::jsonb))
           order by b.mark nulls first, b.box_no, b.id)
      from public.outbound_packages b
      left join public.carton_types t on t.id = b.carton_type_id
     where b.file_id = p_file_id and b.removed_at is null), '[]'::jsonb));
end;
$$;
revoke all on function public.outbound_packing_get(bigint) from public, anon;
grant execute on function public.outbound_packing_get(bigint) to authenticated;

-- [p_boxes]: [{box_no, mark, carton_type_id, own_case, length_cm, width_cm,
-- height_cm, tare_kg, est_kg, gross_kg, note, id?, checked?, lines:
-- [{file_line_id, product_id, jan, code, name, maker, quantity, checked?}]}].
-- The boxes there were are taken away first; one given back by its id keeps
-- who checked it and when.
create or replace function public.outbound_packing_save(p_file_id bigint, p_boxes jsonb)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_old public.outbound_packages;
  v_box jsonb;
  v_line jsonb;
  v_id bigint;
  v_n integer := 0;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_file_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_file_id;
  end if;
  update public.outbound_packages set removed_at = now() where file_id = p_file_id and removed_at is null;
  for v_box in select * from jsonb_array_elements(coalesce(p_boxes, '[]'::jsonb)) loop
    -- A box kept from before ({id}) keeps who checked it and when.
    select * into v_old from public.outbound_packages
     where id = nullif(v_box->>'id', '')::bigint and file_id = p_file_id;
    insert into public.outbound_packages (file_id, box_no, mark, carton_type_id, own_case, length_cm, width_cm, height_cm,
                                          tare_kg, est_kg, gross_kg, note, checked_at, checked_by)
    values (p_file_id, coalesce(public.price_num(v_box->>'box_no')::integer, v_n + 1),
            nullif(btrim(coalesce(v_box->>'mark', '')), ''), nullif(v_box->>'carton_type_id', '')::bigint,
            coalesce((v_box->>'own_case')::boolean, false), public.price_num(v_box->>'length_cm'),
            public.price_num(v_box->>'width_cm'), public.price_num(v_box->>'height_cm'),
            public.price_num(v_box->>'tare_kg'), public.price_num(v_box->>'est_kg'), public.price_num(v_box->>'gross_kg'),
            nullif(btrim(coalesce(v_box->>'note', '')), ''),
            case when coalesce((v_box->>'checked')::boolean, false) then coalesce(v_old.checked_at, now()) end,
            case when coalesce((v_box->>'checked')::boolean, false) then coalesce(v_old.checked_by, auth.uid()) end)
    returning id into v_id;
    for v_line in select * from jsonb_array_elements(coalesce(v_box->'lines', '[]'::jsonb)) loop
      insert into public.outbound_package_lines (package_id, file_line_id, product_id, jan_code, item_code, product_name,
                                                 maker, quantity, checked)
      values (v_id, nullif(v_line->>'file_line_id', '')::bigint, nullif(v_line->>'product_id', '')::bigint,
              nullif(btrim(coalesce(v_line->>'jan', '')), ''), nullif(btrim(coalesce(v_line->>'code', '')), ''),
              nullif(btrim(coalesce(v_line->>'name', '')), ''), nullif(btrim(coalesce(v_line->>'maker', '')), ''),
              greatest(coalesce(public.price_num(v_line->>'quantity')::integer, 0), 0),
              coalesce((v_line->>'checked')::boolean, false));
    end loop;
    v_n := v_n + 1;
  end loop;
  perform public.log_audit('packing.planned', 'outbound_file', p_file_id::text, v_f.warehouse_id,
    jsonb_build_object('boxes', v_n));
  return v_n;
end;
$$;
revoke all on function public.outbound_packing_save(bigint, jsonb) from public, anon;
grant execute on function public.outbound_packing_save(bigint, jsonb) to authenticated;

-- One box changed on the floor: [p] {carton_type_id, own_case, length_cm,
-- width_cm, height_cm, tare_kg, est_kg, gross_kg, note, checked, lines:
-- [{id, quantity, checked}]} — what is given is written.
create or replace function public.outbound_package_update(p_id bigint, p jsonb)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_b public.outbound_packages;
  v_wh bigint;
  v_line jsonb;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_b from public.outbound_packages where id = p_id and removed_at is null for update;
  select warehouse_id into v_wh from public.outbound_files where id = v_b.file_id;
  if v_b.id is null or not public.can_access_warehouse(v_wh) then
    raise exception 'package % not found', p_id;
  end if;
  update public.outbound_packages set
    carton_type_id = case when p ? 'carton_type_id' then nullif(p->>'carton_type_id', '')::bigint else carton_type_id end,
    own_case = case when p ? 'own_case' then coalesce((p->>'own_case')::boolean, false) else own_case end,
    length_cm = case when p ? 'length_cm' then public.price_num(p->>'length_cm') else length_cm end,
    width_cm = case when p ? 'width_cm' then public.price_num(p->>'width_cm') else width_cm end,
    height_cm = case when p ? 'height_cm' then public.price_num(p->>'height_cm') else height_cm end,
    tare_kg = case when p ? 'tare_kg' then public.price_num(p->>'tare_kg') else tare_kg end,
    est_kg = case when p ? 'est_kg' then public.price_num(p->>'est_kg') else est_kg end,
    gross_kg = case when p ? 'gross_kg' then public.price_num(p->>'gross_kg') else gross_kg end,
    note = case when p ? 'note' then nullif(btrim(coalesce(p->>'note', '')), '') else note end,
    checked_at = case when p ? 'checked' then (case when (p->>'checked')::boolean then now() end) else checked_at end,
    checked_by = case when p ? 'checked' then (case when (p->>'checked')::boolean then auth.uid() end) else checked_by end
   where id = p_id;
  for v_line in select * from jsonb_array_elements(coalesce(p->'lines', '[]'::jsonb)) loop
    update public.outbound_package_lines set
      quantity = case when v_line ? 'quantity' then greatest(coalesce(public.price_num(v_line->>'quantity')::integer, 0), 0) else quantity end,
      checked = case when v_line ? 'checked' then coalesce((v_line->>'checked')::boolean, false) else checked end
     where id = nullif(v_line->>'id', '')::bigint and package_id = p_id;
  end loop;
  return true;
end;
$$;
revoke all on function public.outbound_package_update(bigint, jsonb) from public, anon;
grant execute on function public.outbound_package_update(bigint, jsonb) to authenticated;

-- -------------------------------------------------------- packing lists
create or replace function public.packing_list_add(
  p_warehouse_id bigint, p_source text, p_file_id bigint default null,
  p_original_name text default null, p_original_path text default null,
  p_improved_name text default null, p_improved_path text default null,
  p_boxes integer default null, p_quantity integer default null, p_gross_kg numeric default null,
  p_cbm numeric default null, p_note text default null)
returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if p_source not in ('upload', 'generated') then
    raise exception 'packing_list_source';
  end if;
  if (p_original_path is not null and p_original_path not like p_warehouse_id::text || '/%')
     or (p_improved_path is not null and p_improved_path not like p_warehouse_id::text || '/%') then
    raise exception 'outbound_file_path';
  end if;
  if p_file_id is not null and not exists (
       select 1 from public.outbound_files where id = p_file_id and warehouse_id = p_warehouse_id) then
    raise exception 'outbound file % not found', p_file_id;
  end if;
  insert into public.outbound_packing_lists (warehouse_id, file_id, source, original_name, original_path, improved_name,
                                             improved_path, boxes, quantity, gross_kg, cbm, note)
  values (p_warehouse_id, p_file_id, p_source, p_original_name, p_original_path, p_improved_name, p_improved_path,
          p_boxes, p_quantity, p_gross_kg, p_cbm, nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_id;
  perform public.log_audit('packing.list_added', 'outbound_packing_list', v_id::text, p_warehouse_id,
    jsonb_build_object('source', p_source, 'file_id', p_file_id, 'name', coalesce(p_original_name, p_improved_name)));
  return v_id;
end;
$$;
revoke all on function public.packing_list_add(bigint, text, bigint, text, text, text, text, integer, integer, numeric, numeric, text) from public, anon;
grant execute on function public.packing_list_add(bigint, text, bigint, text, text, text, text, integer, integer, numeric, numeric, text) to authenticated;

-- [p_file_id]: that shipping list's; else every one kept lately (newest first).
create or replace function public.packing_lists_list(p_file_id bigint default null, p_limit integer default 200)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.can_view_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', x.id, 'warehouse_id', x.warehouse_id, 'warehouse_name', w.name, 'file_id', x.file_id,
             'file_name', f.file_name, 'shipped_on', f.shipped_on, 'source', x.source,
             'original_name', x.original_name, 'original_path', x.original_path,
             'improved_name', x.improved_name, 'improved_path', x.improved_path,
             'boxes', x.boxes, 'quantity', x.quantity, 'gross_kg', x.gross_kg, 'cbm', x.cbm, 'note', x.note,
             'created_at', x.created_at, 'created_by_name', public.user_display_name(x.created_by))
           order by x.created_at desc, x.id desc)
      from (select * from public.outbound_packing_lists l
             where l.removed_at is null and public.can_access_warehouse(l.warehouse_id)
               and (p_file_id is null or l.file_id = p_file_id)
             order by l.created_at desc, l.id desc
             limit greatest(1, least(coalesce(p_limit, 200), 1000))) x
      join public.warehouses w on w.id = x.warehouse_id
      left join public.outbound_files f on f.id = x.file_id), '[]'::jsonb);
end;
$$;
revoke all on function public.packing_lists_list(bigint, integer) from public, anon;
grant execute on function public.packing_lists_list(bigint, integer) to authenticated;

create or replace function public.packing_list_withdraw(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_wh bigint;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select warehouse_id into v_wh from public.outbound_packing_lists where id = p_id and removed_at is null;
  if v_wh is null or not public.can_access_warehouse(v_wh) then
    raise exception 'packing list % not found', p_id;
  end if;
  update public.outbound_packing_lists set removed_at = now() where id = p_id;
  return true;
end;
$$;
revoke all on function public.packing_list_withdraw(bigint) from public, anon;
grant execute on function public.packing_list_withdraw(bigint) to authenticated;
