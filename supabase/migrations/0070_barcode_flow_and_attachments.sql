-- 0070_barcode_flow_and_attachments.sql
-- Phase B, steps 5 and 6: §26's one resolver with a scan context, and §29's
-- attachments generalised.
--
-- §26's complaint is short and specific: 「全画面が独自にJAN判定しない」. There is
-- one resolver, `resolve_barcode`, and by 0062 it already answered product,
-- serial and location. What it could not do is the second half of the section:
--
--   「Scan Contextを持たせ、… のように文脈で判定する。」
--
-- A scanner hands over a string. What that string *means* depends on what the
-- operator is in the middle of: during picking a code is probably a location
-- then a product; during QC it is probably a lot on a carton. Worse, some
-- identifiers are not globally unique at all — a lot code is unique only within
-- its product — so without a context there is no correct answer to give.
--
-- So the resolver gains a context, and the context does three things:
--
--   1. It reorders the search, so an ambiguous string resolves to the thing the
--      operator is most likely holding.
--   2. It enables branches that cannot work without it, notably lots.
--   3. It reports whether what was found is what this step was waiting for, so
--      the screen can say "that is a product, but I am waiting for a location"
--      instead of silently doing the wrong thing.
--
-- Point 3 is the one that matters on the floor. A resolver that quietly accepts
-- a product scan where a location was expected is how stock ends up in the wrong
-- bin, and no amount of per-screen JAN-sniffing fixes it.

-- ---------------------------------------------------------------------------
-- 1. What a scan can turn out to be, and what each step expects
-- ---------------------------------------------------------------------------

create table if not exists public.scan_contexts (
  code        text primary key,
  name        text not null,
  -- In priority order. The first kind that matches wins, which is what makes
  -- the same string mean a location during picking and a product during
  -- receiving.
  expects     text[] not null,
  sort_order  integer not null default 100,
  is_active   boolean not null default true
);

alter table public.scan_contexts enable row level security;
drop policy if exists "read scan contexts" on public.scan_contexts;
create policy "read scan contexts" on public.scan_contexts
  for select using (auth.uid() is not null);

insert into public.scan_contexts (code, name, expects, sort_order) values
  ('RECEIVING', '入荷',   array['receipt','delivery','product','lot','serial','location'], 10),
  ('QC',        '検品',   array['lot','serial','product','inspection','receipt'],          20),
  ('PUTAWAY',   '格納',   array['location','product','lot','serial','task'],               30),
  ('PICKING',   'ピッキング', array['location','product','serial','lot','task'],           40),
  ('PACKING',   '梱包',   array['product','serial','shipment','task'],                     50),
  ('SHIPPING',  '出荷',   array['shipment','location','product','task'],                   60),
  ('COUNTING',  '棚卸',   array['location','product','lot','serial','task'],               70),
  ('LOOKUP',    '検索',   array['product','serial','lot','location','receipt','delivery','shipment','task'], 80)
on conflict (code) do update
  set name = excluded.name, expects = excluded.expects, sort_order = excluded.sort_order;

create or replace function public.list_scan_contexts()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'code', c.code, 'name', c.name, 'expects', c.expects) order by c.sort_order), '[]'::jsonb)
  from public.scan_contexts c where c.is_active;
$$;

revoke all on function public.list_scan_contexts() from public, anon;
grant execute on function public.list_scan_contexts() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. The resolver
-- ---------------------------------------------------------------------------
--
-- Deliberately absent: carton and pallet. §26 lists them, and Phase C is where
-- they get a table. A branch that resolves nothing is worse than no branch,
-- because it reads like the feature exists.
--
-- The task branch resolves the labels this system prints — `PICK-12`, `QC-3`,
-- `COUNT-4`, `TO-9` — which is a convention this migration establishes rather
-- than one it found. It is written down here because a printed task label has to
-- say something, and a documented prefix is better than a screen guessing.

create or replace function public.resolve_barcode(
  p_barcode      text,
  p_context      text default null,
  p_product_id   bigint default null,
  p_warehouse_id bigint default null
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_code    text;
  v_raw     text := nullif(upper(btrim(coalesce(p_barcode, ''))), '');
  v_ctx     text := nullif(upper(btrim(coalesce(p_context, ''))), '');
  v_expects text[];
  v_kind    text;
  v_result  jsonb;
  v_hit     jsonb;
  v_num     bigint;
  v_n       int;
begin
  if not (public.has_permission('product.view')
          or public.has_permission('inventory.view')) then
    raise exception 'not permitted: product.view required';
  end if;

  v_code := public.normalize_barcode(p_barcode);
  if v_code is null and v_raw is null then
    return jsonb_build_object('kind', 'unknown', 'barcode', p_barcode,
                              'context', v_ctx, 'expected', false);
  end if;

  select expects into v_expects from public.scan_contexts
   where code = v_ctx and is_active;
  if v_expects is null then
    -- No context, or one this database does not know: try everything, in the
    -- order a person browsing would expect.
    v_expects := array['product','serial','lot','location','receipt','delivery','shipment','task'];
  end if;

  foreach v_kind in array v_expects loop
    v_hit := null;

    if v_kind = 'product' then
      select jsonb_build_object(
               'kind', 'product',
               'barcode', b.barcode,
               'barcode_type', b.barcode_type,
               'quantity_per_scan', b.quantity_per_scan,
               'uom', (select u.code from public.uoms u where u.id = b.uom_id),
               'base_uom', (select u.code from public.uoms u where u.id = p.base_uom_id),
               'is_primary', b.is_primary,
               'product_id', p.id, 'jan_code', p.jan_code, 'sku', p.sku,
               'name', p.name, 'category', p.category,
               'tracking_mode', p.tracking_mode, 'status', p.status,
               'requires_inspection', p.requires_inspection)
        into v_hit
        from public.product_barcodes b
        join public.products p on p.id = b.product_id
       where b.barcode = v_code;

    elsif v_kind = 'serial' then
      select jsonb_build_object(
               'kind', 'serial',
               'barcode', sn.serial_number,
               'serial_id', sn.id, 'serial_number', sn.serial_number,
               'serial_status', sn.status,
               'lot_id', sn.lot_id,
               'lot_code', (select l.lot_code from public.lots l where l.id = sn.lot_id),
               'expiry_date', (select l.expiry_date from public.lots l where l.id = sn.lot_id),
               'quantity_per_scan', 1,
               'base_uom', (select u.code from public.uoms u where u.id = p.base_uom_id),
               'product_id', p.id, 'jan_code', p.jan_code, 'sku', p.sku,
               'name', p.name, 'category', p.category,
               'tracking_mode', p.tracking_mode, 'status', p.status)
        into v_hit
        from public.serial_numbers sn
        join public.products p on p.id = sn.product_id
       where sn.serial_number in (v_raw, v_code)
       order by case when sn.serial_number = v_raw then 0 else 1 end
       limit 1;

    elsif v_kind = 'lot' then
      -- A lot code is unique only within its product. With a product in hand
      -- this is exact; without one it is a guess, so it is only answered when
      -- exactly one lot in the company matches — and when several do, the
      -- candidates are handed back rather than one of them being picked.
      if p_product_id is not null then
        select jsonb_build_object(
                 'kind', 'lot', 'barcode', l.lot_code,
                 'lot_id', l.id, 'lot_code', l.lot_code,
                 'expiry_date', l.expiry_date,
                 'manufacture_date', l.manufacture_date,
                 'is_expired', l.expiry_date is not null and l.expiry_date < current_date,
                 'quantity_per_scan', 1,
                 'product_id', p.id, 'jan_code', p.jan_code, 'name', p.name,
                 'tracking_mode', p.tracking_mode)
          into v_hit
          from public.lots l join public.products p on p.id = l.product_id
         where l.product_id = p_product_id and upper(l.lot_code) in (v_raw, v_code);
      else
        select count(*) into v_n from public.lots l
         where upper(l.lot_code) in (v_raw, v_code);
        if v_n = 1 then
          select jsonb_build_object(
                   'kind', 'lot', 'barcode', l.lot_code,
                   'lot_id', l.id, 'lot_code', l.lot_code,
                   'expiry_date', l.expiry_date,
                   'manufacture_date', l.manufacture_date,
                   'is_expired', l.expiry_date is not null and l.expiry_date < current_date,
                   'quantity_per_scan', 1,
                   'product_id', p.id, 'jan_code', p.jan_code, 'name', p.name,
                   'tracking_mode', p.tracking_mode)
            into v_hit
            from public.lots l join public.products p on p.id = l.product_id
           where upper(l.lot_code) in (v_raw, v_code);
        elsif v_n > 1 then
          select jsonb_build_object(
                   'kind', 'ambiguous', 'barcode', coalesce(v_raw, v_code),
                   'would_be', 'lot',
                   'reason', 'a lot code identifies a lot only within its product',
                   'candidates', jsonb_agg(jsonb_build_object(
                     'lot_id', l.id, 'lot_code', l.lot_code,
                     'product_id', p.id, 'jan_code', p.jan_code, 'name', p.name,
                     'expiry_date', l.expiry_date) order by l.id))
            into v_hit
            from public.lots l join public.products p on p.id = l.product_id
           where upper(l.lot_code) in (v_raw, v_code);
        end if;
      end if;

    elsif v_kind = 'location' then
      select jsonb_build_object(
               'kind', 'location',
               'barcode', coalesce(l.barcode, l.code),
               'location_id', l.id, 'code', l.code, 'name', l.name,
               'location_type', l.location_type,
               'warehouse_id', l.warehouse_id, 'bin_id', l.bin_id,
               'zone_id', l.zone_id, 'is_active', l.is_active,
               'pickable', l.pickable, 'receivable', l.receivable,
               'quarantine', l.quarantine, 'is_virtual', l.is_virtual)
        into v_hit
        from public.locations l
       where (l.barcode = v_code or upper(l.code) in (v_raw, v_code))
         and public.can_access_warehouse(l.warehouse_id)
         and (p_warehouse_id is null or l.warehouse_id = p_warehouse_id)
       order by case when l.barcode = v_code then 0 else 1 end, l.id
       limit 1;

    elsif v_kind = 'receipt' then
      select jsonb_build_object(
               'kind', 'receipt', 'barcode', r.reference_no,
               'reconciliation_id', r.id, 'reference_no', r.reference_no,
               'status', r.status, 'delivery_plan_id', r.delivery_plan_id,
               'delivery_number', dp.delivery_number,
               'supplier_name', dp.supplier_name,
               'warehouse_id', dp.warehouse_id)
        into v_hit
        from public.delivery_reconciliations r
        join public.delivery_plans dp on dp.id = r.delivery_plan_id
       where upper(r.reference_no) in (v_raw, v_code)
         and public.can_access_warehouse(
               coalesce(dp.warehouse_id, public.default_warehouse_id()))
       limit 1;

    elsif v_kind = 'delivery' then
      select jsonb_build_object(
               'kind', 'delivery', 'barcode', dp.delivery_number,
               'delivery_plan_id', dp.id, 'delivery_number', dp.delivery_number,
               'supplier_name', dp.supplier_name, 'status', dp.status,
               'warehouse_id', dp.warehouse_id)
        into v_hit
        from public.delivery_plans dp
       where upper(dp.delivery_number) in (v_raw, v_code)
         and public.can_access_warehouse(
               coalesce(dp.warehouse_id, public.default_warehouse_id()))
       limit 1;

    elsif v_kind = 'shipment' then
      select jsonb_build_object(
               'kind', 'shipment', 'barcode', sp.shipment_number,
               'shipment_plan_id', sp.id, 'shipment_number', sp.shipment_number,
               'customer_name', sp.customer_name, 'status', sp.status,
               'carrier', sp.carrier, 'tracking_number', sp.tracking_number,
               'warehouse_id', sp.warehouse_id)
        into v_hit
        from public.shipment_plans sp
       where (upper(sp.shipment_number) in (v_raw, v_code)
              or upper(coalesce(sp.tracking_number, '')) in (v_raw, v_code))
         and public.can_access_warehouse(
               coalesce(sp.warehouse_id, public.default_warehouse_id()))
       limit 1;

    elsif v_kind = 'task' or v_kind = 'inspection' then
      -- The printed-label convention: a prefix, a dash, the id.
      -- The pattern is checked before the cast, not after: 'ABC123' is a
      -- perfectly ordinary barcode and must not raise here.
      if v_raw ~ '^(PICK|QC|COUNT|TO)-[0-9]+$' then
        v_num := regexp_replace(v_raw, '^(PICK|QC|COUNT|TO)-', '')::bigint;
      else
        v_num := null;
      end if;
      if v_num is not null then
        if v_raw like 'PICK-%' and v_kind = 'task' then
          select jsonb_build_object('kind', 'task', 'task_type', 'pick_list',
                   'barcode', v_raw, 'pick_list_id', pl.id, 'status', pl.status,
                   'warehouse_id', pl.warehouse_id,
                   'shipment_plan_id', pl.shipment_plan_id)
            into v_hit from public.pick_lists pl
           where pl.id = v_num and public.can_access_warehouse(pl.warehouse_id);
        elsif v_raw like 'QC-%' then
          select jsonb_build_object('kind',
                   case when v_kind = 'inspection' then 'inspection' else 'task' end,
                   'task_type', 'inspection',
                   'barcode', v_raw, 'inspection_id', i.id, 'status', i.status,
                   'warehouse_id', i.warehouse_id,
                   'reconciliation_id', i.reconciliation_id)
            into v_hit from public.inspections i
           where i.id = v_num and public.can_access_warehouse(i.warehouse_id);
        elsif v_raw like 'COUNT-%' and v_kind = 'task' then
          select jsonb_build_object('kind', 'task', 'task_type', 'stock_count',
                   'barcode', v_raw, 'stock_count_id', c.id, 'status', c.status,
                   'warehouse_id', c.warehouse_id)
            into v_hit from public.stock_counts c
           where c.id = v_num and public.can_access_warehouse(c.warehouse_id);
        elsif v_raw like 'TO-%' and v_kind = 'task' then
          select jsonb_build_object('kind', 'task', 'task_type', 'transfer_order',
                   'barcode', v_raw, 'transfer_order_id', t.id, 'status', t.status,
                   'transfer_number', t.transfer_number,
                   'source_warehouse_id', t.source_warehouse_id,
                   'destination_warehouse_id', t.destination_warehouse_id)
            into v_hit from public.transfer_orders t
           where t.id = v_num
             and (public.can_access_warehouse(t.source_warehouse_id)
                  or public.can_access_warehouse(t.destination_warehouse_id));
        end if;
      end if;
      if v_hit is null and v_kind = 'task' then
        select jsonb_build_object('kind', 'task', 'task_type', 'transfer_order',
                 'barcode', t.transfer_number, 'transfer_order_id', t.id,
                 'status', t.status, 'transfer_number', t.transfer_number)
          into v_hit from public.transfer_orders t
         where upper(t.transfer_number) in (v_raw, v_code)
           and (public.can_access_warehouse(t.source_warehouse_id)
                or public.can_access_warehouse(t.destination_warehouse_id))
         limit 1;
      end if;
    end if;

    if v_hit is not null then
      v_result := v_hit;
      exit;
    end if;
  end loop;

  if v_result is null then
    return jsonb_build_object('kind', 'unknown',
                              'barcode', coalesce(v_code, v_raw),
                              'context', v_ctx,
                              'expected', false);
  end if;

  -- What the step was waiting for, and whether this is it. A screen that knows
  -- the scan was the wrong *kind* of thing can say so; one that only knows the
  -- lookup succeeded cannot.
  return v_result
       || jsonb_build_object(
            'context', v_ctx,
            'expected', (v_result ->> 'kind') = v_expects[1],
            'context_expects', to_jsonb(v_expects));
end;
$$;

revoke all on function public.resolve_barcode(text, text, bigint, bigint) from public, anon;
grant execute on function public.resolve_barcode(text, text, bigint, bigint)
  to authenticated, service_role;

-- Same reason as 0066 and 0068: the one-argument form beside one whose extra
-- arguments default would make every one-argument call ambiguous. Callers that
-- pass only a barcode keep working, and now get a context-free resolution.
drop function if exists public.resolve_barcode(text);

-- ---------------------------------------------------------------------------
-- 3. §29 — attachments, generalised
-- ---------------------------------------------------------------------------
--
-- The table was already polymorphic (`entity_type` / `entity_id`), which is the
-- shape §29 asks for. What it lacked is everything that makes a polymorphic
-- table safe to use: a vocabulary of what may be attached to, a warehouse for
-- the row so RLS can scope it, a note of what the file *is* (a delivery note is
-- not a damage photo), and a way to remove one.

create table if not exists public.attachment_targets (
  entity_type text primary key,
  name        text not null,
  sort_order  integer not null default 100,
  is_active   boolean not null default true
);

alter table public.attachment_targets enable row level security;
drop policy if exists "read attachment targets" on public.attachment_targets;
create policy "read attachment targets" on public.attachment_targets
  for select using (auth.uid() is not null);

insert into public.attachment_targets (entity_type, name, sort_order) values
  ('product', '商品', 10),
  ('receiving', '入荷', 20),
  ('receipt_item', '入荷明細', 25),
  ('qc', '検品', 30),
  ('stock', '在庫', 40),
  ('shipment', '出荷', 50),
  ('carton', '梱包', 60),
  ('return', '返品', 70),
  ('adjustment', '在庫調整', 80),
  ('count', '棚卸', 90),
  ('work_order', '作業指示', 100)
on conflict (entity_type) do update
  set name = excluded.name, sort_order = excluded.sort_order;

alter table public.attachments
  add column if not exists warehouse_id bigint references public.warehouses(id),
  add column if not exists kind         text,
  add column if not exists caption      text,
  add column if not exists byte_size    bigint,
  add column if not exists deleted_at   timestamptz;

comment on column public.attachments.kind is
  'What the file is: PHOTO, DELIVERY_NOTE, QC_IMAGE, DAMAGE, DOCUMENT, OTHER. A delivery note and a damage photo are not the same evidence.';
comment on column public.attachments.deleted_at is
  'Attachments are withdrawn, not deleted: a photo that was used to settle a claim has to stay findable.';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'attachments_kind_check') then
    alter table public.attachments add constraint attachments_kind_check
      check (kind is null or kind in
        ('PHOTO', 'DELIVERY_NOTE', 'QC_IMAGE', 'DAMAGE', 'DOCUMENT', 'LABEL', 'OTHER'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'attachments_entity_type_fk') then
    -- Existing rows may carry an entity_type outside the vocabulary, so the
    -- vocabulary is seeded from them first rather than the constraint refusing
    -- to be added.
    insert into public.attachment_targets (entity_type, name, sort_order)
    select distinct a.entity_type, a.entity_type, 900
      from public.attachments a
     where not exists (select 1 from public.attachment_targets t
                        where t.entity_type = a.entity_type)
    on conflict (entity_type) do nothing;
    alter table public.attachments add constraint attachments_entity_type_fk
      foreign key (entity_type) references public.attachment_targets(entity_type);
  end if;
end $$;

create index if not exists attachments_entity_idx
  on public.attachments (entity_type, entity_id) where deleted_at is null;
create index if not exists attachments_warehouse_idx
  on public.attachments (warehouse_id) where warehouse_id is not null;

-- Rows with no warehouse are company-wide (a product photo); rows with one are
-- scoped like everything else.
drop policy if exists "read attachments" on public.attachments;
create policy "read attachments" on public.attachments
  for select using (
    auth.uid() is not null
    and (warehouse_id is null or public.can_access_warehouse(warehouse_id)));

create or replace function public.record_attachment(
  p_entity_type  text,
  p_entity_id    text,
  p_storage_path text,
  p_content_type text default null,
  p_kind         text default null,
  p_caption      text default null,
  p_byte_size    bigint default null,
  p_warehouse_id bigint default null
-- Still the attachment id, not a jsonb envelope: the caller already knows what
-- it uploaded, and the client reads this value as an int.
) returns bigint
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_company bigint;
  v_type    text := lower(btrim(coalesce(p_entity_type, '')));
  v_kind    text := nullif(upper(btrim(coalesce(p_kind, ''))), '');
  v_id      bigint;
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if nullif(btrim(coalesce(p_storage_path, '')), '') is null then
    raise exception 'storage_path is required';
  end if;
  if not exists (select 1 from public.attachment_targets
                  where entity_type = v_type and is_active) then
    raise exception 'nothing can be attached to %', p_entity_type;
  end if;
  if nullif(btrim(coalesce(p_entity_id, '')), '') is null then
    raise exception 'entity_id is required';
  end if;

  select id into v_company from public.companies order by id limit 1;

  insert into public.attachments
    (company_id, entity_type, entity_id, storage_path, content_type,
     uploaded_by, warehouse_id, kind, caption, byte_size)
  values
    (v_company, v_type, btrim(p_entity_id), btrim(p_storage_path), p_content_type,
     auth.uid(), p_warehouse_id, coalesce(v_kind, 'OTHER'), nullif(btrim(coalesce(p_caption, '')), ''),
     p_byte_size)
  returning id into v_id;

  perform public.log_audit('attachment.recorded', v_type, btrim(p_entity_id),
    p_warehouse_id,
    jsonb_build_object('attachment_id', v_id, 'kind', coalesce(v_kind, 'OTHER'),
                       'content_type', p_content_type));

  return v_id;
end;
$$;

revoke all on function public.record_attachment(text, text, text, text, text, text, bigint, bigint)
  from public, anon;
grant execute on function public.record_attachment(text, text, text, text, text, text, bigint, bigint)
  to authenticated, service_role;

drop function if exists public.record_attachment(text, text, text, text);

create or replace function public.withdraw_attachment(p_attachment_id bigint, p_reason text default null)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_row public.attachments;
begin
  if not public.has_permission('inventory.adjust') then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  select * into v_row from public.attachments where id = p_attachment_id;
  if v_row.id is null then
    raise exception 'attachment % not found', p_attachment_id;
  end if;
  if v_row.warehouse_id is not null and not public.can_access_warehouse(v_row.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;

  update public.attachments set deleted_at = now() where id = p_attachment_id;

  perform public.log_audit('attachment.withdrawn', v_row.entity_type, v_row.entity_id,
    v_row.warehouse_id,
    jsonb_build_object('attachment_id', p_attachment_id, 'reason', p_reason));
  return true;
end;
$$;

revoke all on function public.withdraw_attachment(bigint, text) from public, anon;
grant execute on function public.withdraw_attachment(bigint, text) to authenticated, service_role;

create or replace function public.attachments_for(
  p_entity_type text,
  p_entity_id   text,
  p_include_withdrawn boolean default false
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
begin
  if not public.has_permission('inventory.view') then
    raise exception 'not permitted: inventory.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'attachment_id', a.id,
      'storage_path', a.storage_path,
      'content_type', a.content_type,
      'kind', a.kind,
      'caption', a.caption,
      'byte_size', a.byte_size,
      'uploaded_by', a.uploaded_by,
      'warehouse_id', a.warehouse_id,
      'created_at', a.created_at,
      'withdrawn_at', a.deleted_at) order by a.created_at desc, a.id desc)
    from public.attachments a
   where a.entity_type = lower(btrim(coalesce(p_entity_type, '')))
     and a.entity_id = btrim(coalesce(p_entity_id, ''))
     and (p_include_withdrawn or a.deleted_at is null)
     and (a.warehouse_id is null or public.can_access_warehouse(a.warehouse_id))
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.attachments_for(text, text, boolean) from public, anon;
grant execute on function public.attachments_for(text, text, boolean)
  to authenticated, service_role;

create or replace function public.list_attachment_targets()
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'entity_type', t.entity_type, 'name', t.name) order by t.sort_order), '[]'::jsonb)
  from public.attachment_targets t where t.is_active;
$$;

revoke all on function public.list_attachment_targets() from public, anon;
grant execute on function public.list_attachment_targets() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Housekeeping
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
