-- 0134 — 仕入先ファイル起点の入荷: expected and actual dates kept apart,
-- the state of an expected receipt, over-receipts confirmed, the documents
-- behind a plan, duplicates caught, and one timeline per plan.
--
-- The tables keep their names: delivery_plans is the Expected Receipt,
-- delivery_reconciliations is one Actual Receipt (a plan has as many as
-- deliveries arrive), and inspections hang off each receipt. What this
-- migration adds:
--
--   delivery_plans.expected_arrival_date   仕入先が示した入荷予定日 (null = 未定)
--   delivery_plans.scheduled_inspection_date 予定検品日 (a plan, never a fact)
--   delivery_plans.document_type           purchase_confirmation / delivery_schedule /
--                                           delivery_note / invoice / other
--   delivery_plans.receipt_state           EXPECTED / PARTIALLY_RECEIVED / RECEIVED /
--                                           OVER_RECEIVED / CLOSED / CANCELLED / ON_HOLD / DRAFT
--   delivery_plans.on_hold
--   delivery_reconciliations.arrived_on    (already there) 実際の入荷日
--   inspections.scheduled_date             検品予定日, proposed from the arrival date
--   inspections.started_at                 実際の検品開始 (first count)
--   inspections.completed_at               (already there) 実際の検品完了
--
-- Stock is untouched by any of it: a receipt still books QC_PENDING stock and
-- only a passed inspection releases it (0096, 0097).

alter table public.delivery_plans
  add column if not exists expected_arrival_date date,
  add column if not exists scheduled_inspection_date date,
  add column if not exists document_type text,
  add column if not exists receipt_state text not null default 'EXPECTED',
  add column if not exists on_hold boolean not null default false;

do $$ begin
  alter table public.delivery_plans add constraint delivery_plans_document_type_check
    check (document_type is null or document_type in
      ('purchase_confirmation', 'delivery_schedule', 'delivery_note', 'invoice', 'other'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.delivery_plans add constraint delivery_plans_receipt_state_check
    check (receipt_state in ('DRAFT', 'EXPECTED', 'PARTIALLY_RECEIVED', 'RECEIVED',
                             'OVER_RECEIVED', 'CLOSED', 'CANCELLED', 'ON_HOLD'));
exception when duplicate_object then null; end $$;

comment on column public.delivery_plans.expected_arrival_date is
  '仕入先から提示された入荷予定日。null は未定 — never filled with today.';
comment on column public.delivery_plans.scheduled_inspection_date is
  '予定検品日. A plan only: the inspection of each receipt has its own date.';
comment on column public.delivery_plans.document_type is
  'What the supplier sent: purchase_confirmation, delivery_schedule, delivery_note, invoice or other. An invoice never counts as goods received.';
comment on column public.delivery_plans.receipt_state is
  'Kept by trigger from the lines and status: EXPECTED, PARTIALLY_RECEIVED, RECEIVED, OVER_RECEIVED, CLOSED (closed short), CANCELLED, ON_HOLD, DRAFT.';

alter table public.import_documents
  add column if not exists document_type text;

alter table public.inspections
  add column if not exists scheduled_date date,
  add column if not exists started_at timestamptz;

comment on column public.inspections.scheduled_date is
  '検品予定日. Proposed from the receipt''s arrival date; the warehouse may move it.';
comment on column public.inspections.started_at is
  '実際の検品開始: the first count or judgement on any of its items.';

insert into public.permissions (code, description)
values ('receiving.over_accept', 'Accept more than was expected on a delivery')
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r, public.permissions p
 where r.code in ('system_admin', 'company_admin', 'warehouse_manager')
   and p.code = 'receiving.over_accept'
on conflict do nothing;

-- What kind of document a file name says it is. The reviewer can always
-- change it; this only fills the default.
create or replace function public.guess_document_type(p_file_name text)
returns text
language sql immutable set search_path = '' as $$
  select case
    when n is null then null
    when n ~ '請求|invoice' then 'invoice'
    when n ~ '注文請書|注文確認|発注確認|受注確認|注文書|ご注文|order ?confirm|purchase ?order' then 'purchase_confirmation'
    when n ~ '納品予定|入荷予定|出荷予定|出荷案内|納期|予定表|schedule|eta' then 'delivery_schedule'
    when n ~ '納品書|納品|送り状|delivery|packing' then 'delivery_note'
    else null
  end
  from (select nullif(lower(normalize(coalesce(p_file_name, ''), NFKC)), '') as n) s;
$$;

-- The state of an expected receipt from its lines and status.
create or replace function public.compute_receipt_state(
  p_plan_id bigint, p_status text, p_on_hold boolean)
returns text
language sql stable security definer set search_path = '' as $$
  select case
    when p_status = 'cancelled' then 'CANCELLED'
    when coalesce(p_on_hold, false) then 'ON_HOLD'
    when p_status = 'draft' then 'DRAFT'
    when coalesce(a.over_lines, 0) > 0 or coalesce(u.unexpected, 0) > 0 then 'OVER_RECEIVED'
    when coalesce(a.received, 0) = 0 then
      case when p_status = 'completed' then 'CLOSED' else 'EXPECTED' end
    when coalesce(a.outstanding, 0) = 0 then 'RECEIVED'
    when p_status = 'completed' then 'CLOSED'
    else 'PARTIALLY_RECEIVED'
  end
  from (select
          sum(coalesce(received_quantity, 0)) as received,
          sum(greatest(coalesce(planned_quantity, 0) - coalesce(received_quantity, 0), 0)) as outstanding,
          count(*) filter (where coalesce(received_quantity, 0) > coalesce(planned_quantity, 0)) as over_lines
          from public.delivery_plan_lines where delivery_plan_id = p_plan_id) a,
       (select coalesce(sum(rl.actual_quantity), 0) as unexpected
          from public.reconciliation_lines rl
          join public.delivery_reconciliations r on r.id = rl.reconciliation_id
         where r.delivery_plan_id = p_plan_id and r.status <> 'cancelled'
           and rl.plan_line_id is null and coalesce(rl.actual_quantity, 0) > 0) u;
$$;

-- The printed delivery_date (text) and the expected date (date) say the same
-- thing; whichever was written last wins. The state is recomputed on every
-- write.
create or replace function public.delivery_plan_dates_and_state()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_iso text;
begin
  if tg_op = 'INSERT' then
    if new.expected_arrival_date is null then
      v_iso := substring(coalesce(new.delivery_date, '') from '^\s*(\d{4}-\d{2}-\d{2})');
      if v_iso is not null then
        begin new.expected_arrival_date := v_iso::date; exception when others then null; end;
      end if;
    elsif new.delivery_date is null then
      new.delivery_date := to_char(new.expected_arrival_date, 'YYYY-MM-DD');
    end if;
  else
    if new.expected_arrival_date is distinct from old.expected_arrival_date then
      new.delivery_date := case when new.expected_arrival_date is null then null
                                else to_char(new.expected_arrival_date, 'YYYY-MM-DD') end;
    elsif new.delivery_date is distinct from old.delivery_date then
      v_iso := substring(coalesce(new.delivery_date, '') from '^\s*(\d{4}-\d{2}-\d{2})');
      new.expected_arrival_date := null;
      if v_iso is not null then
        begin new.expected_arrival_date := v_iso::date; exception when others then null; end;
      end if;
    end if;
  end if;
  new.receipt_state := public.compute_receipt_state(new.id, new.status, new.on_hold);
  return new;
end;
$$;

create or replace trigger delivery_plan_dates_and_state
  before insert or update on public.delivery_plans
  for each row execute function public.delivery_plan_dates_and_state();

-- Every change of a planned date is kept (§25), with the document that
-- brought it when there was one (`wms.inbound_document`).
create or replace function public.delivery_plan_dates_logged()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_doc bigint := nullif(current_setting('wms.inbound_document', true), '')::bigint;
  v_wh  bigint := coalesce(new.warehouse_id, public.default_warehouse_id());
begin
  if tg_op = 'INSERT' then
    perform public.log_audit('inbound.expected_created', 'delivery_plan', new.id::text, v_wh,
      jsonb_build_object('expected_arrival_date', new.expected_arrival_date,
                         'scheduled_inspection_date', new.scheduled_inspection_date,
                         'document_type', new.document_type,
                         'purchase_order_id', new.purchase_order_id));
    return null;
  end if;
  if new.expected_arrival_date is distinct from old.expected_arrival_date then
    perform public.log_audit('inbound.expected_date_changed', 'delivery_plan', new.id::text, v_wh,
      jsonb_build_object('field', 'expected_arrival_date',
                         'from', old.expected_arrival_date, 'to', new.expected_arrival_date,
                         'document_id', v_doc));
  end if;
  if new.scheduled_inspection_date is distinct from old.scheduled_inspection_date then
    perform public.log_audit('inbound.expected_date_changed', 'delivery_plan', new.id::text, v_wh,
      jsonb_build_object('field', 'scheduled_inspection_date',
                         'from', old.scheduled_inspection_date, 'to', new.scheduled_inspection_date,
                         'document_id', v_doc));
  end if;
  if new.receipt_state is distinct from old.receipt_state then
    perform public.log_audit('inbound.state_changed', 'delivery_plan', new.id::text, v_wh,
      jsonb_build_object('from', old.receipt_state, 'to', new.receipt_state));
  end if;
  return null;
end;
$$;

create or replace trigger delivery_plan_dates_logged
  after insert or update on public.delivery_plans
  for each row execute function public.delivery_plan_dates_logged();

create or replace function public.delivery_plan_line_state_changed()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_plan bigint := coalesce(new.delivery_plan_id, old.delivery_plan_id);
begin
  update public.delivery_plans p
     set receipt_state = public.compute_receipt_state(p.id, p.status, p.on_hold)
   where p.id = v_plan
     and p.receipt_state is distinct from public.compute_receipt_state(p.id, p.status, p.on_hold);
  return null;
end;
$$;

create or replace trigger delivery_plan_line_state_changed
  after insert or delete or update of planned_quantity, received_quantity
  on public.delivery_plan_lines
  for each row execute function public.delivery_plan_line_state_changed();

-- The receipt's arrival date: what the operator said (`wms.arrived_on`, set
-- by receive_delivery), else today in the warehouse.
create or replace function public.receipt_arrived_on_default()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_said text := nullif(current_setting('wms.arrived_on', true), '');
begin
  if new.arrived_on is null then
    new.arrived_on := coalesce(v_said::date, public.warehouse_today(coalesce(
      (select p.warehouse_id from public.delivery_plans p where p.id = new.delivery_plan_id),
      public.default_warehouse_id())));
  end if;
  return new;
end;
$$;

-- The inspection of a receipt is proposed for the day the goods arrived.
create or replace function public.inspection_scheduled_default()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.scheduled_date is null then
    new.scheduled_date := coalesce(
      (select r.arrived_on from public.delivery_reconciliations r where r.id = new.reconciliation_id),
      public.warehouse_today(new.warehouse_id));
  end if;
  return new;
end;
$$;

create or replace trigger inspection_scheduled_default
  before insert on public.inspections
  for each row execute function public.inspection_scheduled_default();

-- The first count or judgement starts the inspection.
create or replace function public.inspection_item_starts_inspection()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.counted_quantity is distinct from old.counted_quantity
     or new.sampled_quantity is distinct from old.sampled_quantity
     or new.passed_quantity is distinct from old.passed_quantity
     or new.failed_quantity is distinct from old.failed_quantity
     or new.result is distinct from old.result then
    update public.inspections set started_at = now()
     where id = new.inspection_id and started_at is null;
  end if;
  return null;
end;
$$;

create or replace trigger inspection_item_starts_inspection
  after update on public.inspection_items
  for each row execute function public.inspection_item_starts_inspection();

-- Moving the arrival date moves the inspection's proposed date with it while
-- nobody has touched that date or started counting.
create or replace function public.set_receipt_arrived_on(p_reconciliation_id bigint, p_arrived_on date)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_warehouse bigint;
  v_state     text;
  v_before    date;
begin
  if not public.has_permission('receiving.confirm') then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  select coalesce(p.warehouse_id, public.default_warehouse_id()), r.status, r.arrived_on
    into v_warehouse, v_state, v_before
    from public.delivery_reconciliations r
    join public.delivery_plans p on p.id = r.delivery_plan_id
   where r.id = p_reconciliation_id;
  if v_warehouse is null then
    raise exception 'receipt % not found', p_reconciliation_id;
  end if;
  if not public.can_access_warehouse(v_warehouse) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_state = 'cancelled' then
    raise exception 'receipt % is cancelled', p_reconciliation_id;
  end if;
  if p_arrived_on is null then
    raise exception 'an arrival date is required';
  end if;
  if p_arrived_on > public.warehouse_today(v_warehouse) then
    raise exception 'the arrival date % is in the future', p_arrived_on;
  end if;

  update public.delivery_reconciliations set arrived_on = p_arrived_on
   where id = p_reconciliation_id;
  update public.inspections set scheduled_date = p_arrived_on
   where reconciliation_id = p_reconciliation_id and status = 'PENDING'
     and started_at is null and scheduled_date is not distinct from v_before;
  perform public.log_audit('receiving.arrival_date_set', 'reconciliation',
    p_reconciliation_id::text, v_warehouse,
    jsonb_build_object('from', v_before, 'to', p_arrived_on));
  return jsonb_build_object('reconciliation_id', p_reconciliation_id, 'arrived_on', p_arrived_on);
end;
$$;

create or replace function public.set_inspection_schedule(p_inspection_id bigint, p_date date)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_ins record;
begin
  if not (public.has_permission('inspection.confirm') or public.has_permission('receiving.confirm')) then
    raise exception 'not permitted: inspection.confirm required';
  end if;
  select id, warehouse_id, status, scheduled_date into v_ins
    from public.inspections where id = p_inspection_id for update;
  if v_ins.id is null then
    raise exception 'inspection % not found', p_inspection_id;
  end if;
  if not public.can_access_warehouse(v_ins.warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_ins.status <> 'PENDING' then
    raise exception 'inspection % is already completed', p_inspection_id;
  end if;
  if p_date is null then
    raise exception 'an inspection date is required';
  end if;
  update public.inspections set scheduled_date = p_date where id = p_inspection_id;
  perform public.log_audit('inspection.scheduled', 'inspection', p_inspection_id::text,
    v_ins.warehouse_id, jsonb_build_object('from', v_ins.scheduled_date, 'to', p_date));
  return jsonb_build_object('inspection_id', p_inspection_id, 'scheduled_date', p_date);
end;
$$;

-- The documents behind a plan: the one it was made from and every later one
-- (a delivery schedule that moved the date, the delivery note, the invoice).
create table if not exists public.inbound_plan_documents (
  id bigint generated always as identity primary key,
  delivery_plan_id bigint not null references public.delivery_plans(id) on delete cascade,
  document_id bigint not null references public.import_documents(id) on delete cascade,
  document_type text,
  action text not null default 'attached'
    check (action in ('created', 'dates_updated', 'attached', 'receipt_candidate')),
  note text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (delivery_plan_id, document_id)
);

create index if not exists inbound_plan_documents_document_idx
  on public.inbound_plan_documents (document_id);

alter table public.inbound_plan_documents enable row level security;

do $$ begin
  create policy "read plan documents" on public.inbound_plan_documents
    for select to authenticated
    using (exists (select 1 from public.delivery_plans p where p.id = delivery_plan_id));
exception when duplicate_object then null; end $$;

grant select on public.inbound_plan_documents to authenticated;

comment on table public.inbound_plan_documents is
  'Supplier files behind an expected receipt (0134): the one it was made from and any that updated it later.';

-- A file kept as evidence takes its type from its name; once it is tied to a
-- plan it is listed among the plan's documents and gives the plan its type.
create or replace function public.import_document_typed()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.document_type is null and new.purpose in ('plan', 'ocr', 'training') then
    new.document_type := public.guess_document_type(new.file_name);
  end if;
  return new;
end;
$$;

create or replace trigger import_document_typed
  before insert on public.import_documents
  for each row execute function public.import_document_typed();

create or replace function public.import_document_tied_to_plan()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.delivery_plan_id is null
     or new.delivery_plan_id is not distinct from old.delivery_plan_id then
    return null;
  end if;
  insert into public.inbound_plan_documents (delivery_plan_id, document_id, document_type, action, created_by)
  values (new.delivery_plan_id, new.id, new.document_type, 'created', new.uploaded_by)
  on conflict (delivery_plan_id, document_id) do nothing;
  update public.delivery_plans set document_type = new.document_type
   where id = new.delivery_plan_id and document_type is null and new.document_type is not null;
  return null;
end;
$$;

create or replace trigger import_document_tied_to_plan
  after update of delivery_plan_id on public.import_documents
  for each row execute function public.import_document_tied_to_plan();

-- Set or clear the planned dates, the document type and the hold of a plan,
-- optionally because of a supplier file. Only the keys present in p_changes
-- change: {"expected_arrival_date": null} sets 未定.
create or replace function public.set_expected_receipt(
  p_plan_id bigint, p_changes jsonb, p_document_id bigint default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_plan  public.delivery_plans;
  v_after public.delivery_plans;
  v_type  text;
  v_doc   record;
  v_dates boolean;
begin
  if not public.has_permission('receiving.confirm') then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  select * into v_plan from public.delivery_plans where id = p_plan_id for update;
  if v_plan.id is null then
    raise exception 'delivery plan % not found', p_plan_id;
  end if;
  if not public.can_access_warehouse(coalesce(v_plan.warehouse_id, public.default_warehouse_id())) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_plan.status = 'cancelled' then
    raise exception 'delivery plan % is cancelled', p_plan_id;
  end if;
  p_changes := coalesce(p_changes, '{}'::jsonb);
  if p_changes ? 'document_type' then
    v_type := nullif(btrim(coalesce(p_changes->>'document_type', '')), '');
    if v_type is not null and v_type not in
       ('purchase_confirmation', 'delivery_schedule', 'delivery_note', 'invoice', 'other') then
      raise exception 'unknown document type %', v_type;
    end if;
  end if;
  if p_document_id is not null then
    select id, document_type, file_name into v_doc from public.import_documents where id = p_document_id;
    if v_doc.id is null then
      raise exception 'document % not found', p_document_id;
    end if;
  end if;

  perform set_config('wms.inbound_document', coalesce(p_document_id::text, ''), true);
  update public.delivery_plans set
    expected_arrival_date = case when p_changes ? 'expected_arrival_date'
      then nullif(p_changes->>'expected_arrival_date', '')::date else expected_arrival_date end,
    scheduled_inspection_date = case when p_changes ? 'scheduled_inspection_date'
      then nullif(p_changes->>'scheduled_inspection_date', '')::date else scheduled_inspection_date end,
    document_type = case when p_changes ? 'document_type' then v_type else document_type end,
    on_hold = case when p_changes ? 'on_hold' then coalesce((p_changes->>'on_hold')::boolean, false)
                   else on_hold end
   where id = p_plan_id
  returning * into v_after;
  perform set_config('wms.inbound_document', '', true);

  v_dates := v_after.expected_arrival_date is distinct from v_plan.expected_arrival_date
          or v_after.scheduled_inspection_date is distinct from v_plan.scheduled_inspection_date;

  if p_document_id is not null then
    if p_changes ? 'document_type' and v_type is not null then
      update public.import_documents set document_type = v_type
       where id = p_document_id and document_type is distinct from v_type;
    end if;
    insert into public.inbound_plan_documents (delivery_plan_id, document_id, document_type, action, note)
    values (p_plan_id, p_document_id, coalesce(v_type, v_doc.document_type),
            case when coalesce(p_changes->>'action', '') = 'receipt_candidate' then 'receipt_candidate'
                 when v_dates then 'dates_updated' else 'attached' end,
            nullif(btrim(coalesce(p_changes->>'note', '')), ''))
    on conflict (delivery_plan_id, document_id) do update
       set action = case when excluded.action = 'attached' then public.inbound_plan_documents.action
                         else excluded.action end,
           document_type = coalesce(excluded.document_type, public.inbound_plan_documents.document_type);
  end if;

  return jsonb_build_object(
    'plan_id', p_plan_id,
    'expected_arrival_date', v_after.expected_arrival_date,
    'scheduled_inspection_date', v_after.scheduled_inspection_date,
    'document_type', v_after.document_type,
    'on_hold', v_after.on_hold,
    'receipt_state', v_after.receipt_state,
    'dates_changed', v_dates);
end;
$$;

-- Plans the same file or the same document number already became (§23).
create or replace function public.inbound_duplicates(
  p_document_id bigint default null,
  p_supplier_id bigint default null,
  p_supplier_name text default null,
  p_doc_number text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_sha  text;
  v_num  text := nullif(btrim(coalesce(p_doc_number, '')), '');
  v_name text := nullif(btrim(coalesce(p_supplier_name, '')), '');
begin
  if not (public.has_permission('receiving.view') or public.has_permission('receiving.confirm')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  if p_document_id is not null then
    select sha256 into v_sha from public.import_documents where id = p_document_id;
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'plan_id', p.id, 'delivery_number', p.delivery_number, 'reference_no', p.reference_no,
      'doc_number', p.doc_number, 'supplier_name', p.supplier_name,
      'expected_arrival_date', p.expected_arrival_date, 'receipt_state', p.receipt_state,
      'document_type', p.document_type, 'created_at', p.created_at,
      'reasons', m.reasons) order by p.id desc)
    from (
      select plan_id, jsonb_agg(distinct reason) as reasons from (
        select d.delivery_plan_id as plan_id, 'same_file' as reason
          from public.import_documents d
         where v_sha is not null and d.sha256 = v_sha and d.delivery_plan_id is not null
           and d.id is distinct from p_document_id
        union all
        select ipd.delivery_plan_id, 'same_file'
          from public.inbound_plan_documents ipd
          join public.import_documents d on d.id = ipd.document_id
         where v_sha is not null and d.sha256 = v_sha
        union all
        select p.id, 'same_number'
          from public.delivery_plans p
         where v_num is not null
           and (btrim(coalesce(p.doc_number, '')) = v_num or btrim(coalesce(p.delivery_number, '')) = v_num)
           and (p_supplier_id is not null and p.supplier_id = p_supplier_id
                or v_name is not null and p.supplier_name = v_name)
      ) hits group by plan_id
    ) m
    join public.delivery_plans p on p.id = m.plan_id
   where p.status <> 'cancelled'
     and public.can_access_warehouse(coalesce(p.warehouse_id, public.default_warehouse_id()))
  ), '[]'::jsonb);
end;
$$;

-- Most elements of an entry's parcels kept, up to p_keep units.
create or replace function public.trim_receipt_items(p_items jsonb, p_keep integer)
returns jsonb
language plpgsql immutable set search_path = '' as $$
declare
  it    jsonb;
  out   jsonb := '[]'::jsonb;
  left_ int := greatest(coalesce(p_keep, 0), 0);
  q     int;
begin
  if jsonb_typeof(p_items) is distinct from 'array' then
    return '[]'::jsonb;
  end if;
  for it in select * from jsonb_array_elements(p_items) loop
    exit when left_ <= 0;
    q := least(coalesce((it->>'quantity')::int, 0), left_);
    continue when q <= 0;
    out := out || jsonb_set(it, '{quantity}', to_jsonb(q));
    left_ := left_ - q;
  end loop;
  return out;
end;
$$;

-- One delivery received against a plan, as a guarded call. More than the
-- plan still expects stops with OVER_RECEIPT and the lines in JSON, unless
-- the caller said what to do with the excess:
--   accept  receive everything (receiving.over_accept)
--   cap     receive only what was still expected
--   hold    receive everything, the excess on HOLD until someone decides
create or replace function public.receive_delivery(
  p_plan_id bigint,
  p_lines jsonb,
  p_complete boolean default false,
  p_note_reference text default null,
  p_arrived_on date default null,
  p_over text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_plan    record;
  v_wh      bigint;
  v_policy  text := lower(nullif(btrim(coalesce(p_over, '')), ''));
  e         jsonb;
  v_lines   jsonb := '[]'::jsonb;
  v_over    jsonb := '[]'::jsonb;
  v_taken   jsonb := '{}'::jsonb;
  v_pl      record;
  v_qty     int;
  v_before  int;
  v_rem     int;
  v_extra   int;
  v_recon   bigint;
  v_after   record;
begin
  if not public.has_permission('receiving.confirm') then
    raise exception 'not permitted: receiving.confirm required';
  end if;
  select id, warehouse_id, status into v_plan
    from public.delivery_plans where id = p_plan_id for update;
  if v_plan.id is null then
    raise exception 'delivery plan % not found', p_plan_id;
  end if;
  v_wh := coalesce(v_plan.warehouse_id, public.default_warehouse_id());
  if not public.can_access_warehouse(v_wh) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  if v_plan.status = 'cancelled' then
    raise exception 'delivery plan % is cancelled', p_plan_id;
  end if;
  if p_arrived_on is not null and p_arrived_on > public.warehouse_today(v_wh) then
    raise exception 'the arrival date % is in the future', p_arrived_on;
  end if;
  if v_policy is not null and v_policy not in ('accept', 'cap', 'hold') then
    raise exception 'unknown over-receipt choice %', p_over;
  end if;
  if jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'lines are required';
  end if;

  for e in select * from jsonb_array_elements(p_lines) loop
    v_qty := coalesce((e->>'actual_quantity')::int, 0);
    select id, planned_quantity, received_quantity, product_name into v_pl
      from public.delivery_plan_lines
     where delivery_plan_id = p_plan_id and jan_code = e->>'jan_code'
     order by id limit 1;
    if v_pl.id is not null and v_qty > 0 then
      v_before := coalesce(v_pl.received_quantity, 0) + coalesce((v_taken->>v_pl.id::text)::int, 0);
      v_rem := greatest(coalesce(v_pl.planned_quantity, 0) - v_before, 0);
      v_extra := v_qty - v_rem;
      if v_extra > 0 then
        v_over := v_over || jsonb_build_object(
          'jan_code', e->>'jan_code', 'product_name', v_pl.product_name,
          'planned', coalesce(v_pl.planned_quantity, 0), 'received', v_before,
          'arriving', v_qty, 'remaining', v_rem, 'over', v_extra);
        if v_policy = 'cap' then
          if v_rem = 0 then
            continue;
          end if;
          e := jsonb_set(e, '{actual_quantity}', to_jsonb(v_rem));
          if e ? 'items' then
            e := jsonb_set(e, '{items}', public.trim_receipt_items(e->'items', v_rem));
          end if;
          v_qty := v_rem;
        elsif v_policy = 'hold' then
          e := jsonb_set(e, '{items}',
                 public.trim_receipt_items(e->'items', v_rem)
                 || jsonb_build_array(jsonb_build_object(
                      'quantity', v_extra, 'status', 'HOLD', 'note', 'over receipt')));
        end if;
      end if;
      v_taken := jsonb_set(v_taken, array[v_pl.id::text],
        to_jsonb(coalesce((v_taken->>v_pl.id::text)::int, 0) + v_qty));
    end if;
    v_lines := v_lines || e;
  end loop;

  if jsonb_array_length(v_over) > 0 then
    if v_policy is null then
      raise exception 'OVER_RECEIPT %', v_over::text;
    end if;
    if v_policy = 'accept' and not public.has_permission('receiving.over_accept') then
      raise exception 'not permitted: receiving.over_accept required';
    end if;
  end if;

  perform set_config('wms.arrived_on', coalesce(p_arrived_on::text, ''), true);
  v_recon := public.reconcile_delivery_plan(p_plan_id, coalesce(p_complete, false), p_note_reference, v_lines);
  perform set_config('wms.arrived_on', '', true);

  if jsonb_array_length(v_over) > 0 then
    perform public.log_audit('receiving.over_receipt', 'reconciliation', v_recon::text, v_wh,
      jsonb_build_object('plan_id', p_plan_id, 'choice', v_policy, 'lines', v_over));
  end if;

  select p.receipt_state, r.arrived_on, i.id as inspection_id, i.scheduled_date
    into v_after
    from public.delivery_plans p
    join public.delivery_reconciliations r on r.id = v_recon
    left join public.inspections i on i.reconciliation_id = v_recon
   where p.id = p_plan_id;

  return jsonb_build_object(
    'reconciliation_id', v_recon,
    'plan_id', p_plan_id,
    'receipt_state', v_after.receipt_state,
    'arrived_on', v_after.arrived_on,
    'inspection_id', v_after.inspection_id,
    'scheduled_inspection_date', v_after.scheduled_date,
    'over', v_over,
    'over_choice', v_policy);
end;
$$;

-- One expected receipt with everything that happened to it (§17, §18, §25):
-- lines with what is left, each receipt with its inspection, the documents
-- and the history.
create or replace function public.expected_receipt_timeline(p_plan_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_plan public.delivery_plans;
  v_wh   bigint;
  v_recons bigint[];
  v_insps  bigint[];
begin
  if not (public.has_permission('receiving.view') or public.has_permission('receiving.confirm')
          or public.has_permission('inspection.view')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  select * into v_plan from public.delivery_plans where id = p_plan_id;
  if v_plan.id is null then
    raise exception 'delivery plan % not found', p_plan_id;
  end if;
  v_wh := coalesce(v_plan.warehouse_id, public.default_warehouse_id());
  if not public.can_access_warehouse(v_wh) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  select coalesce(array_agg(id), '{}') into v_recons
    from public.delivery_reconciliations where delivery_plan_id = p_plan_id;
  select coalesce(array_agg(id), '{}') into v_insps
    from public.inspections where reconciliation_id = any(v_recons);

  return jsonb_build_object(
    'plan', jsonb_build_object(
      'id', v_plan.id, 'delivery_number', v_plan.delivery_number, 'reference_no', v_plan.reference_no,
      'doc_number', v_plan.doc_number, 'supplier_id', v_plan.supplier_id,
      'supplier_name', v_plan.supplier_name, 'warehouse_id', v_plan.warehouse_id,
      'warehouse_name', (select w.name from public.warehouses w where w.id = v_plan.warehouse_id),
      'expected_arrival_date', v_plan.expected_arrival_date,
      'scheduled_inspection_date', v_plan.scheduled_inspection_date,
      'document_type', v_plan.document_type, 'receipt_state', v_plan.receipt_state,
      'on_hold', v_plan.on_hold, 'status', v_plan.status,
      'purchase_order_id', v_plan.purchase_order_id, 'created_at', v_plan.created_at,
      'today', public.warehouse_today(v_wh)),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id, 'jan_code', l.jan_code, 'product_id', l.product_id,
        'product_name', coalesce(pr.name, l.product_name), 'supplier_product_name', l.product_name,
        'product_code', l.product_code, 'maker', l.maker,
        'planned', coalesce(l.planned_quantity, 0), 'received', coalesce(l.received_quantity, 0),
        'remaining', greatest(coalesce(l.planned_quantity, 0) - coalesce(l.received_quantity, 0), 0),
        'over', greatest(coalesce(l.received_quantity, 0) - coalesce(l.planned_quantity, 0), 0),
        'state', case
          when coalesce(l.received_quantity, 0) > coalesce(l.planned_quantity, 0) then 'OVER_RECEIVED'
          when coalesce(l.received_quantity, 0) = 0 then 'EXPECTED'
          when coalesce(l.received_quantity, 0) >= coalesce(l.planned_quantity, 0) then 'RECEIVED'
          else 'PARTIALLY_RECEIVED' end) order by l.id)
      from public.delivery_plan_lines l
      left join public.products pr on pr.id = l.product_id
     where l.delivery_plan_id = p_plan_id), '[]'::jsonb),
    'receipts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'seq', r.seq, 'reference_no', r.reference_no, 'note_reference', r.note_reference,
        'status', r.status, 'arrived_on', r.arrived_on, 'created_at', r.created_at,
        'units', (select coalesce(sum(rl.actual_quantity), 0) from public.reconciliation_lines rl
                   where rl.reconciliation_id = r.id),
        'lines', coalesce((select jsonb_agg(jsonb_build_object(
                    'jan_code', rl.jan_code,
                    'product_name', coalesce(pr.name, pl.product_name),
                    'quantity', rl.actual_quantity, 'status', rl.status) order by rl.id)
                  from public.reconciliation_lines rl
                  left join public.delivery_plan_lines pl on pl.id = rl.plan_line_id
                  left join public.products pr on pr.id = coalesce(rl.product_id, pl.product_id)
                 where rl.reconciliation_id = r.id and coalesce(rl.actual_quantity, 0) > 0), '[]'::jsonb),
        'inspection', (select jsonb_build_object(
                    'id', i.id, 'status', i.status, 'scheduled_date', i.scheduled_date,
                    'started_at', i.started_at, 'completed_at', i.completed_at,
                    'passed', (select coalesce(sum(it.passed_quantity), 0) from public.inspection_items it
                                where it.inspection_id = i.id),
                    'failed', (select coalesce(sum(it.failed_quantity), 0) from public.inspection_items it
                                where it.inspection_id = i.id))
                  from public.inspections i where i.reconciliation_id = r.id
                  order by i.id limit 1)) order by r.id)
      from (select x.*, row_number() over (
                     partition by (x.status = 'cancelled') order by x.id) as seq
              from public.delivery_reconciliations x
             where x.delivery_plan_id = p_plan_id) r), '[]'::jsonb),
    'documents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'file_name', d.file_name, 'content_type', d.content_type,
        'byte_size', d.byte_size, 'storage_path', d.storage_path,
        'document_type', coalesce(k.document_type, d.document_type),
        'action', coalesce(k.action, 'created'), 'uploaded_at', d.uploaded_at,
        'doc_number', d.doc_number, 'source', d.source, 'quality', d.quality) order by d.uploaded_at)
      from public.import_documents d
      left join public.inbound_plan_documents k
        on k.document_id = d.id and k.delivery_plan_id = p_plan_id
     where d.delivery_plan_id = p_plan_id or k.id is not null), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(jsonb_build_object(
        'at', a.created_at, 'event', a.event_type, 'entity_type', a.entity_type,
        'entity_id', a.entity_id, 'details', a.details,
        'actor', (select coalesce(u.name, u.email) from public.app_users u
                   where u.id = a.actor_user_id)) order by a.created_at, a.id)
      from (select * from public.audit_log a
             where (a.entity_type = 'delivery_plan' and a.entity_id = p_plan_id::text)
                or (a.entity_type = 'reconciliation' and a.entity_id = any(
                      select unnest(v_recons)::text))
                or (a.entity_type = 'inspection' and a.entity_id = any(
                      select unnest(v_insps)::text))
             order by a.created_at desc, a.id desc limit 300) a), '[]'::jsonb));
end;
$$;

-- 今日の入荷 for the floor (§28): what is due, what waits for inspection,
-- what waits to be put away.
create or replace function public.inbound_today(p_warehouse_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_today date;
  v_putaway int := 0;
begin
  if not (public.has_permission('receiving.view') or public.has_permission('inspection.view')
          or public.has_permission('receiving.confirm')) then
    raise exception 'not permitted: receiving.view required';
  end if;
  if p_warehouse_id is null or not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  v_today := public.warehouse_today(p_warehouse_id);
  if public.warehouse_uses_locations(p_warehouse_id) then
    select count(*) into v_putaway from (
      select 1 from public.stock_units su
       where su.warehouse_id = p_warehouse_id and su.bin_id is null and su.quantity > 0
       group by su.product_id, su.lot_id, su.serial_id, su.status_id) q;
  end if;

  return jsonb_build_object(
    'today', v_today,
    'due_today', (select count(*) from public.delivery_plans p
                   where coalesce(p.warehouse_id, public.default_warehouse_id()) = p_warehouse_id
                     and p.receipt_state in ('EXPECTED', 'PARTIALLY_RECEIVED')
                     and p.expected_arrival_date = v_today),
    'overdue', (select count(*) from public.delivery_plans p
                 where coalesce(p.warehouse_id, public.default_warehouse_id()) = p_warehouse_id
                   and p.receipt_state in ('EXPECTED', 'PARTIALLY_RECEIVED')
                   and p.expected_arrival_date < v_today),
    'undated', (select count(*) from public.delivery_plans p
                 where coalesce(p.warehouse_id, public.default_warehouse_id()) = p_warehouse_id
                   and p.receipt_state in ('EXPECTED', 'PARTIALLY_RECEIVED')
                   and p.expected_arrival_date is null),
    'awaiting_inspection', (select count(*) from public.inspections i
                             where i.warehouse_id = p_warehouse_id and i.status = 'PENDING'),
    'inspection_due_today', (select count(*) from public.inspections i
                              where i.warehouse_id = p_warehouse_id and i.status = 'PENDING'
                                and i.scheduled_date <= v_today),
    'putaway_waiting', v_putaway,
    'plans', coalesce((
      select jsonb_agg(x.j order by x.ord, x.d nulls last, x.id)
        from (select p.id, p.expected_arrival_date as d,
                     case when p.expected_arrival_date < v_today then 0
                          when p.expected_arrival_date = v_today then 1
                          when p.expected_arrival_date is null then 3 else 2 end as ord,
                     jsonb_build_object(
                       'id', p.id, 'delivery_number', p.delivery_number,
                       'supplier_name', p.supplier_name,
                       'expected_arrival_date', p.expected_arrival_date,
                       'receipt_state', p.receipt_state,
                       'remaining', (select coalesce(sum(greatest(coalesce(l.planned_quantity, 0)
                                       - coalesce(l.received_quantity, 0), 0)), 0)
                                       from public.delivery_plan_lines l where l.delivery_plan_id = p.id)) as j
                from public.delivery_plans p
               where coalesce(p.warehouse_id, public.default_warehouse_id()) = p_warehouse_id
                 and p.receipt_state in ('EXPECTED', 'PARTIALLY_RECEIVED')
                 and (p.expected_arrival_date is null or p.expected_arrival_date <= v_today + 7)
               order by 3, 2 nulls last, 1 limit 20) x), '[]'::jsonb));
end;
$$;

-- No backfill: there were no plans or inspections when this was applied. On a
-- database that has some, run once:
--   update public.delivery_plans set receipt_state = public.compute_receipt_state(id, status, on_hold);
--   update public.inspections i set scheduled_date = coalesce(
--     (select r.arrived_on from public.delivery_reconciliations r where r.id = i.reconciliation_id),
--     i.created_at::date) where scheduled_date is null;

revoke all on function public.compute_receipt_state(bigint, text, boolean) from public, anon;
revoke all on function public.set_inspection_schedule(bigint, date) from public, anon;
revoke all on function public.set_expected_receipt(bigint, jsonb, bigint) from public, anon;
revoke all on function public.inbound_duplicates(bigint, bigint, text, text) from public, anon;
revoke all on function public.receive_delivery(bigint, jsonb, boolean, text, date, text) from public, anon;
revoke all on function public.expected_receipt_timeline(bigint) from public, anon;
revoke all on function public.inbound_today(bigint) from public, anon;
grant execute on function public.guess_document_type(text) to authenticated, service_role;
grant execute on function public.set_inspection_schedule(bigint, date) to authenticated, service_role;
grant execute on function public.set_expected_receipt(bigint, jsonb, bigint) to authenticated, service_role;
grant execute on function public.inbound_duplicates(bigint, bigint, text, text) to authenticated, service_role;
grant execute on function public.receive_delivery(bigint, jsonb, boolean, text, date, text) to authenticated, service_role;
grant execute on function public.expected_receipt_timeline(bigint) to authenticated, service_role;
grant execute on function public.inbound_today(bigint) to authenticated, service_role;
