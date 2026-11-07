-- 0201: 出庫予定のキープ（引当）と、予定日の翌日の自動出庫.
--
-- A 出荷明細 registered as 出庫予定 (kind 'stock', status 'planned', not
-- taken back) keeps what its 'ship' rows ask for in its warehouse — with a
-- day or 未定 — until it ships or is taken back. 在庫外出荷 (kind 'proxy')
-- moves no stock and keeps nothing.
-- * outbound_kept_qty(product, warehouse): what the planned lists keep.
-- * product_stock_json: 引当 includes it, so 商品ライブラリー shows
--   在庫・引当・引当可能 with the planned lists' keep.
-- * outbound_match: each row's 'kept', so 出荷明細の取込 shows what can go.
-- * outbound_file_shortage(id): for each product of a planned list, what it
--   needs, what the warehouse has, what the lists ahead of it keep (those
--   with an earlier day, then the same day registered first; lists with no
--   day come after every list with one, in the order registered) and what is
--   short. outbound_file_detail gives it as 'shortage'.
-- * outbound_auto_ship(): run by pg_cron just after midnight (Asia/Tokyo).
--   A planned list whose day has passed is recorded as shipped on that day,
--   automatically, only when every product is there in full; one short of
--   anything stays planned, marked (auto_hold_at, auto_hold_short) for a
--   person to see to. Lists with no day are never shipped by it.
-- * outbound_file_back_to_plan(id): a shipped list (by hand or by the
--   above) that did not leave after all goes back to planned, 未定: its
--   stock comes back and it keeps again.
-- * outbound_files_list / outbound_file_detail: auto_shipped, auto_hold_at,
--   auto_hold_short.

alter table public.outbound_files add column if not exists auto_shipped boolean not null default false;
alter table public.outbound_files add column if not exists auto_hold_at timestamptz;
alter table public.outbound_files add column if not exists auto_hold_short integer;

create index if not exists outbound_file_lines_keep on public.outbound_file_lines (product_id) where action = 'ship';
create index if not exists outbound_files_planned on public.outbound_files (warehouse_id, shipped_on)
  where status = 'planned' and undone_at is null;

create or replace function public.outbound_kept_qty(p_product_id bigint, p_warehouse_id bigint)
returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(l.quantity), 0)::integer
    from public.outbound_file_lines l
    join public.outbound_files f on f.id = l.file_id
   where l.product_id = p_product_id and l.action = 'ship' and l.quantity > 0
     and f.warehouse_id = p_warehouse_id and f.kind = 'stock' and f.status = 'planned' and f.undone_at is null;
$$;
revoke all on function public.outbound_kept_qty(bigint, bigint) from public, anon, authenticated;

-- What a planned list is short of, product by product (no permission check:
-- called by the definer functions below).
create or replace function public.outbound_file_shortage(p_id bigint)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_rows jsonb;
begin
  select * into v_f from public.outbound_files where id = p_id;
  if v_f.id is null or v_f.kind <> 'stock' or v_f.status <> 'planned' or v_f.undone_at is not null then
    return null;
  end if;
  with need as (
    select l.jan_code, min(l.product_id) as product_id, min(coalesce(l.product_name, '')) as name,
           sum(l.quantity)::integer as needed
      from public.outbound_file_lines l
     where l.file_id = p_id and l.action = 'ship' and l.product_id is not null and l.quantity > 0
     group by l.jan_code
  ), ahead as (
    select l.jan_code, sum(l.quantity)::integer as kept
      from public.outbound_file_lines l
      join public.outbound_files o on o.id = l.file_id
     where o.id <> p_id and o.warehouse_id = v_f.warehouse_id and o.kind = 'stock'
       and o.status = 'planned' and o.undone_at is null
       and l.action = 'ship' and l.product_id is not null and l.quantity > 0
       and l.jan_code in (select jan_code from need)
       and case
             when v_f.date_undecided then (not o.date_undecided) or o.id < p_id
             else (not o.date_undecided)
                  and (o.shipped_on < v_f.shipped_on or (o.shipped_on = v_f.shipped_on and o.id < p_id))
           end
     group by l.jan_code
  ), x as (
    select n.jan_code, n.product_id, n.name, n.needed,
           coalesce((select sum(s.on_hand) from public.stock_levels s
                      where s.warehouse_id = v_f.warehouse_id and s.jan_code = n.jan_code), 0)::integer as on_hand,
           coalesce(a.kept, 0) as kept_ahead
      from need n left join ahead a on a.jan_code = n.jan_code
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'jan', x.jan_code, 'product_id', x.product_id, 'name', coalesce(p.name, x.name), 'needed', x.needed,
           'on_hand', x.on_hand, 'kept_ahead', x.kept_ahead,
           'free', greatest(x.on_hand - x.kept_ahead, 0),
           'short', greatest(x.needed - greatest(x.on_hand - x.kept_ahead, 0), 0))
           order by greatest(x.needed - greatest(x.on_hand - x.kept_ahead, 0), 0) desc, x.jan_code), '[]'::jsonb)
    into v_rows
    from x left join public.products p on p.id = x.product_id;
  return jsonb_build_object(
    'short_total', (select coalesce(sum((e->>'short')::integer), 0) from jsonb_array_elements(v_rows) e),
    'short_products', (select count(*) from jsonb_array_elements(v_rows) e where (e->>'short')::integer > 0),
    'products', v_rows);
end;
$$;
revoke all on function public.outbound_file_shortage(bigint) from public, anon, authenticated;

-- Planned lists whose day has passed: shipped on that day when all is there.
create or replace function public.outbound_auto_ship(p_today date default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_today date := coalesce(p_today, (now() at time zone 'Asia/Tokyo')::date);
  v_f public.outbound_files;
  v_l public.outbound_file_lines;
  v_s jsonb;
  v_short integer;
  v_before integer;
  v_mid bigint;
  v_shipped integer := 0;
  v_held integer := 0;
  v_n integer;
begin
  for v_f in select * from public.outbound_files
              where kind = 'stock' and status = 'planned' and undone_at is null
                and not date_undecided and shipped_on < v_today
              order by warehouse_id, shipped_on, id
              for update loop
    v_s := public.outbound_file_shortage(v_f.id);
    v_short := coalesce((v_s->>'short_total')::integer, 0);
    if v_short > 0 then
      update public.outbound_files set auto_hold_at = now(), auto_hold_short = v_short where id = v_f.id;
      if v_f.auto_hold_at is null then
        perform public.log_audit('outbound.auto_ship_held', 'outbound_file', v_f.id::text, v_f.warehouse_id,
          jsonb_build_object('file', v_f.file_name, 'day', v_f.shipped_on, 'short', v_short));
      end if;
      v_held := v_held + 1;
      continue;
    end if;
    v_n := 0;
    for v_l in select * from public.outbound_file_lines
                where file_id = v_f.id and action = 'ship' and product_id is not null and quantity > 0
                order by row_no, id loop
      select coalesce(sum(on_hand), 0)::integer into v_before from public.stock_levels
       where warehouse_id = v_f.warehouse_id and jan_code = v_l.jan_code;
      v_mid := public.apply_stock_movement_detail(v_f.warehouse_id, v_l.jan_code, -v_l.quantity, 'SHIP',
                 'outbound_file', v_f.id::text, v_l.product_name, null, 'auto row ' || v_l.row_no,
                 null, null, null, v_l.product_id);
      update public.outbound_file_lines set
        shipped_quantity = v_l.quantity, short_quantity = 0,
        on_hand_before = v_before, on_hand_after = v_before - v_l.quantity, movement_id = v_mid
       where id = v_l.id;
      v_n := v_n + v_l.quantity;
    end loop;
    update public.outbound_files f set
      status = 'shipped', auto_shipped = true, shipped_by = null, shipped_at = now(),
      auto_hold_at = null, auto_hold_short = null,
      shipped_total = x.s, short_total = x.sh
      from (select coalesce(sum(shipped_quantity), 0) as s, coalesce(sum(short_quantity), 0) as sh
              from public.outbound_file_lines where file_id = v_f.id) x
     where f.id = v_f.id;
    perform public.log_audit('outbound.file_auto_shipped', 'outbound_file', v_f.id::text, v_f.warehouse_id,
      jsonb_build_object('file', v_f.file_name, 'day', v_f.shipped_on, 'shipped', v_n));
    v_shipped := v_shipped + 1;
  end loop;
  return jsonb_build_object('shipped', v_shipped, 'held', v_held, 'today', v_today);
end;
$$;
revoke all on function public.outbound_auto_ship(date) from public, anon, authenticated;

-- A shipped list that did not leave after all: back to planned, 未定.
create or replace function public.outbound_file_back_to_plan(p_id bigint)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_f public.outbound_files;
  v_l public.outbound_file_lines;
  v_n integer := 0;
begin
  if auth.uid() is null or not public.can_post_outbound() then
    raise exception 'not permitted: ship.complete required';
  end if;
  select * into v_f from public.outbound_files where id = p_id for update;
  if v_f.id is null or not public.can_access_warehouse(v_f.warehouse_id) then
    raise exception 'outbound file % not found', p_id;
  end if;
  if v_f.undone_at is not null then
    raise exception 'outbound_already_undone';
  end if;
  if v_f.kind <> 'stock' or v_f.status <> 'shipped' then
    raise exception 'outbound_not_shipped';
  end if;
  for v_l in select * from public.outbound_file_lines where file_id = p_id and shipped_quantity > 0 loop
    perform public.apply_stock_movement_detail(v_f.warehouse_id, v_l.jan_code, v_l.shipped_quantity, 'SHIP_CANCEL',
              'outbound_file', p_id::text, v_l.product_name, null, 'back to plan row ' || v_l.row_no,
              null, null, null, v_l.product_id);
    v_n := v_n + v_l.shipped_quantity;
  end loop;
  update public.outbound_file_lines set shipped_quantity = 0, short_quantity = 0,
         on_hand_before = null, on_hand_after = null, movement_id = null
   where file_id = p_id;
  update public.outbound_files set status = 'planned', date_undecided = true,
         planned_on = coalesce(planned_on, shipped_on),
         shipped_by = null, shipped_at = null, auto_shipped = false, auto_hold_at = null, auto_hold_short = null,
         shipped_total = 0, short_total = 0
   where id = p_id;
  perform public.log_audit('outbound.file_back_to_plan', 'outbound_file', p_id::text, v_f.warehouse_id,
    jsonb_build_object('file', v_f.file_name, 'returned', v_n, 'was_auto', v_f.auto_shipped));
  return v_n;
end;
$$;
revoke all on function public.outbound_file_back_to_plan(bigint) from public, anon;
grant execute on function public.outbound_file_back_to_plan(bigint) to authenticated;

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.product_stock_json(bigint)'::regprocedure);
  if position('outbound_kept_qty' in d) = 0 then
    r := replace(d, 'r.status = ''ACTIVE''), 0)::int as reserved',
                    'r.status = ''ACTIVE''), 0)::int + public.outbound_kept_qty(p_product_id, w.id) as reserved');
    if r = d then
      raise exception 'product_stock_json: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.outbound_match(jsonb, bigint)'::regprocedure);
  if position('outbound_kept_qty' in d) = 0 then
    r := replace(d, '''on_hand'', v_on_hand,',
                    '''on_hand'', v_on_hand, ''kept'', case when v_pid is not null and p_warehouse_id is not null'
                    || ' then public.outbound_kept_qty(v_pid, p_warehouse_id) end,');
    if r = d then
      raise exception 'outbound_match: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.outbound_files_list(date, date, bigint)'::regprocedure);
  if position('auto_shipped' in d) = 0 then
    r := replace(d, '''date_undecided'', f.date_undecided,',
                    '''date_undecided'', f.date_undecided, ''auto_shipped'', f.auto_shipped,'
                    || ' ''auto_hold_at'', f.auto_hold_at, ''auto_hold_short'', f.auto_hold_short,');
    if r = d then
      raise exception 'outbound_files_list: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.outbound_file_detail(bigint)'::regprocedure);
  if position('auto_shipped' in d) = 0 then
    r := replace(d, '''shipped_at'', v_f.shipped_at,',
                    '''shipped_at'', v_f.shipped_at, ''auto_shipped'', v_f.auto_shipped,'
                    || ' ''auto_hold_at'', v_f.auto_hold_at, ''auto_hold_short'', v_f.auto_hold_short,'
                    || ' ''shortage'', public.outbound_file_shortage(v_f.id),');
    if r = d then
      raise exception 'outbound_file_detail: the text to change was not found';
    end if;
    execute r;
  end if;
end;
$$;

-- Just after midnight in Japan (15:07 UTC).
select cron.schedule('outbound-auto-ship', '7 15 * * *', 'select public.outbound_auto_ship();')
 where not exists (select 1 from cron.job where jobname = 'outbound-auto-ship');
