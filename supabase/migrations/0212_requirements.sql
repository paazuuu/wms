-- 0212: 必須項目 — what each step needs before it goes through, set by the
-- system administrator.
--
-- The numbers the profit (0211) is made of must be there when the goods
-- move: what a delivery was bought for, what a shipment was sold for, and
-- the rate that puts yuan in yen. Each such requirement is a rule here, on
-- by default; the system administrator can relax one from the app (表示:
-- 必須項目の設定), and everyone can see which are on.
--
--   receipt.unit_price          入荷（ファイル・発注の取込）: each line's 仕入単価.
--                               予定外の入荷 is not held by it: its price comes
--                               later, on the invoice it waits for (0183).
--   shipment.unit_price         出庫・在庫外出荷: each line's 出荷単価, when the
--                               list becomes 出庫済み (or is recorded).
--   shipment.fx_rate            出庫・在庫外出荷: lines in 元 need the list's
--                               rate (1元 = ?円).
--   shipment.destination_card   出庫: a 出荷先カード (0210), now a rule too.
--
-- Checked in the database, so no screen can go round them: the receipt
-- functions look at the lines they are given; a shipment is checked when it
-- turns 出庫済み (the deferred trigger of 0210, now for 在庫外出荷 as well);
-- the night run (0201) leaves a list that does not meet them planned.

create table if not exists public.system_requirements (
  key text primary key,
  required boolean not null,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.system_requirements enable row level security;

create or replace function public.requirement_keys()
returns text[]
language sql immutable set search_path = '' as $$
  select array['receipt.unit_price', 'shipment.unit_price', 'shipment.fx_rate', 'shipment.destination_card'];
$$;

-- On unless the system administrator turned it off.
create or replace function public.requirement_on(p_key text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select r.required from public.system_requirements r where r.key = p_key), true);
$$;
revoke all on function public.requirement_on(text) from public, anon;
grant execute on function public.requirement_on(text) to authenticated;

create or replace function public.is_system_admin()
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id
                  where ur.user_id = auth.uid() and r.code = 'system_admin');
$$;
revoke all on function public.is_system_admin() from public, anon;
grant execute on function public.is_system_admin() to authenticated;

-- Every rule, on or off, and who last changed it. Anyone signed in may read.
create or replace function public.requirements_list()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'can_edit', public.is_system_admin(),
    'rules', coalesce(jsonb_agg(jsonb_build_object(
      'key', k.key,
      'required', coalesce(r.required, true),
      'is_default', r.key is null,
      'updated_at', r.updated_at,
      'updated_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = r.updated_by))
      order by k.ord), '[]'::jsonb))
    from unnest(public.requirement_keys()) with ordinality as k(key, ord)
    left join public.system_requirements r on r.key = k.key
   where auth.uid() is not null;
$$;
revoke all on function public.requirements_list() from public, anon;
grant execute on function public.requirements_list() to authenticated;

create or replace function public.requirement_set(p_key text, p_required boolean)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.is_system_admin() then
    raise exception 'not permitted: system_admin required';
  end if;
  if p_key is null or not (p_key = any (public.requirement_keys())) or p_required is null then
    raise exception 'requirement_unknown';
  end if;
  insert into public.system_requirements (key, required, updated_at, updated_by)
  values (p_key, p_required, now(), auth.uid())
  on conflict (key) do update set required = excluded.required, updated_at = now(), updated_by = auth.uid();
  perform public.log_audit('system.requirement_set', 'system_requirement', p_key, null,
    jsonb_build_object('required', p_required));
  return true;
end;
$$;
revoke all on function public.requirement_set(text, boolean) from public, anon;
grant execute on function public.requirement_set(text, boolean) to authenticated;

-- A delivery's lines given to the receipt functions: each with a quantity
-- needs a price (unit price, else amount). Raises
-- 'requirement_missing:receipt.unit_price:<line numbers>'.
create or replace function public.require_receipt_prices(p_lines jsonb)
returns void
language plpgsql stable security definer set search_path = '' as $$
declare
  v_rows text;
begin
  if not public.requirement_on('receipt.unit_price')
     or current_setting('wms.receipt_price_later', true) = 'on'
     or jsonb_typeof(p_lines) is distinct from 'array' then
    return;
  end if;
  select string_agg(coalesce(e->>'line_no', '?'), ',' order by coalesce(nullif(e->>'line_no', ''), '0')::int)
    into v_rows
    from jsonb_array_elements(p_lines) e
   where coalesce(public.price_num(e->>'quantity'), 0) > 0
     and coalesce(public.price_num(e->>'unit_price'), public.price_num(e->>'unit_price_tax'),
                  public.price_num(e->>'amount'), 0) <= 0;
  if v_rows is not null then
    raise exception 'requirement_missing:receipt.unit_price:%', v_rows;
  end if;
end;
$$;
revoke all on function public.require_receipt_prices(jsonb) from public, anon;

-- What a shipping list still lacks to be 出庫済み, or null when nothing.
create or replace function public.outbound_requirement_problem(p_id bigint)
returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_rows text;
begin
  select * into v_f from public.outbound_files where id = p_id;
  if v_f.id is null or v_f.undone_at is not null then
    return null;
  end if;
  if v_f.kind = 'stock' and v_f.destination_id is null and public.requirement_on('shipment.destination_card') then
    return 'outbound_card_required';
  end if;
  if public.requirement_on('shipment.unit_price') then
    select string_agg(l.row_no::text, ',' order by l.row_no) into v_rows
      from public.outbound_file_lines l
     where l.file_id = p_id and l.action <> 'skip' and l.quantity > 0
       and coalesce(l.unit_price, l.unit_price_tax, l.amount, 0) <= 0;
    if v_rows is not null then
      return 'requirement_missing:shipment.unit_price:' || v_rows;
    end if;
  end if;
  if v_f.fx_cny_jpy is null and public.requirement_on('shipment.fx_rate') and exists (
       select 1 from public.outbound_file_lines l
        where l.file_id = p_id and l.action <> 'skip' and l.quantity > 0 and upper(coalesce(l.currency, 'JPY')) = 'CNY') then
    return 'requirement_missing:shipment.fx_rate';
  end if;
  return null;
end;
$$;
revoke all on function public.outbound_requirement_problem(bigint) from public, anon;
grant execute on function public.outbound_requirement_problem(bigint) to authenticated;

-- The 0210 trigger's check, for every rule.
create or replace function public.outbound_card_check()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_f public.outbound_files;
  v_problem text;
begin
  -- Deferred: read the row as it is at the end of the transaction.
  select * into v_f from public.outbound_files where id = new.id;
  if v_f.id is null or v_f.status <> 'shipped' or v_f.undone_at is not null then
    return null;
  end if;
  v_problem := public.outbound_requirement_problem(v_f.id);
  if v_problem is not null then
    raise exception '%', v_problem;
  end if;
  return null;
end;
$$;

-- 在庫外出荷 is recorded as shipped: checked the same way.
do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'outbound_requirements_proxy'
                   and tgrelid = 'public.outbound_files'::regclass) then
    create constraint trigger outbound_requirements_proxy
      after insert or update of status on public.outbound_files
      deferrable initially deferred
      for each row
      when (new.kind = 'proxy' and new.status = 'shipped')
      execute function public.outbound_card_check();
  end if;
end $$;

-- The night run passes over a list that does not meet the rules.
do $$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.outbound_auto_ship(date)'::regprocedure) into v_def;
  v_new := replace(v_def, 'and destination_id is not null', 'and public.outbound_requirement_problem(id) is null');
  if v_new = v_def then
    raise exception 'outbound_auto_ship: pattern not found';
  end if;
  execute v_new;
end $$;

-- The receipt functions check their lines first.
do $$
declare
  v_name text;
  v_def text;
  v_new text;
begin
  foreach v_name in array array['public.stock_file_stage(bigint,jsonb,text,text)'] loop
    select pg_get_functiondef(v_name::regprocedure) into v_def;
    v_new := replace(v_def, 'insert into public.master_imports',
                     'perform public.require_receipt_prices(p_lines);
  insert into public.master_imports');
    if v_new = v_def then
      raise exception '%: pattern not found', v_name;
    end if;
    execute v_new;
  end loop;
  -- 在庫ファイルで追加 (add) is a receipt; 数を合わせる (set) is a count.
  select pg_get_functiondef('public.stock_file_import(bigint,text,jsonb,text,text)'::regprocedure) into v_def;
  v_new := replace(v_def, 'insert into public.master_imports',
                   'if p_mode = ''add'' then
    perform public.require_receipt_prices(p_lines);
  end if;
  insert into public.master_imports');
  if v_new = v_def then
    raise exception 'stock_file_import: pattern not found';
  end if;
  execute v_new;
  -- 予定外の入荷: priced later by its invoice.
  select pg_get_functiondef('public.unplanned_stage(bigint,jsonb,text,text,text,bigint,date)'::regprocedure) into v_def;
  v_new := replace(v_def, '  v := public.stock_file_stage(',
                   '  perform set_config(''wms.receipt_price_later'', ''on'', true);
  v := public.stock_file_stage(');
  v_new := replace(v_new, '  v_id := (v->>''import_id'')::bigint;',
                   '  perform set_config(''wms.receipt_price_later'', ''off'', true);
  v_id := (v->>''import_id'')::bigint;');
  if v_new = v_def or position('receipt_price_later'', ''off''' in v_new) = 0 then
    raise exception 'unplanned_stage: pattern not found';
  end if;
  execute v_new;
end $$;
