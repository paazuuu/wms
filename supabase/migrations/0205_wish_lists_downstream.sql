-- 0205: 入荷希望リスト is the wishes from downstream — an end customer's
-- (or our own plan of) what they would like us to get in. The wishes to our
-- suppliers (upstream) are kept elsewhere.
-- * purchase_requests: customer_name (依頼元), destination_id (its
--   出荷先カード, if any), wanted_by (希望時期). The supplier columns stay
--   unused.
-- * purchase_request_save also writes those three.
-- * purchase_request_set_status(id, status): 'closed' (完了: out of the
--   summary) or 'draft' (open again).
-- * purchase_requests_summary(warehouse): the open lists (draft / sent)
--   added up by product — wished in all, who wished how many by when, and
--   against it the stock, what is kept (出庫予定 and orders) and what is free;
--   short = wished beyond what is free.

alter table public.purchase_requests add column if not exists customer_name text;
alter table public.purchase_requests add column if not exists destination_id bigint references public.ship_destinations(id);
alter table public.purchase_requests add column if not exists wanted_by date;

do $$
declare
  d text;
  r text;
begin
  d := pg_get_functiondef('public.purchase_request_save(jsonb)'::regprocedure);
  if position('customer_name' in d) = 0 then
    r := replace(d, '  for e in select * from jsonb_array_elements(p->''lines'') loop',
      '  update public.purchase_requests set
    customer_name = public.tidy_text(p->>''customer_name''),
    destination_id = nullif(p->>''destination_id'', '''')::bigint,
    wanted_by = nullif(p->>''wanted_by'', '''')::date
   where id = v_id;

  for e in select * from jsonb_array_elements(p->''lines'') loop');
    if r = d then
      raise exception 'purchase_request_save: the text to change was not found';
    end if;
    execute r;
  end if;

  d := pg_get_functiondef('public.purchase_requests_list(integer)'::regprocedure);
  if position('customer_name' in d) = 0 then
    r := replace(d, 'r.title, r.note, r.reply_by,', 'r.title, r.note, r.reply_by, r.customer_name, r.destination_id, r.wanted_by,');
    if r = d then
      raise exception 'purchase_requests_list: the text to change was not found';
    end if;
    execute r;
  end if;
end;
$$;

create or replace function public.purchase_request_set_status(p_id bigint, p_status text)
returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_wh bigint;
begin
  if not public.purchase_request_can_edit() then
    raise exception 'not permitted: purchase_order.manage required';
  end if;
  if p_status not in ('draft', 'closed') then
    raise exception 'request status % not allowed', p_status;
  end if;
  update public.purchase_requests set status = p_status, updated_by = auth.uid(), updated_at = now()
   where id = p_id and status <> 'removed'
   returning warehouse_id into v_wh;
  if not found then
    raise exception 'request % not found', p_id;
  end if;
  perform public.log_audit('purchase_request.status', 'purchase_request', p_id::text, v_wh,
    jsonb_build_object('status', p_status));
  return true;
end;
$$;
revoke all on function public.purchase_request_set_status(bigint, text) from public, anon;
grant execute on function public.purchase_request_set_status(bigint, text) to authenticated;

create or replace function public.purchase_requests_summary(p_warehouse_id bigint default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.purchase_request_can_view() then
    raise exception 'not permitted: purchase_order.view required';
  end if;
  if p_warehouse_id is not null and not public.can_access_warehouse(p_warehouse_id) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  return coalesce((
    with l as (
      select x.*, r.request_number, r.customer_name, r.title, r.wanted_by, r.id as rid,
             coalesce('p' || x.product_id, 'j' || nullif(x.jan_code, ''), 'n' || x.name) as k
        from public.purchase_request_lines x
        join public.purchase_requests r on r.id = x.request_id and x.revision = r.revision
       where r.status in ('draft', 'sent')
    ), g as (
      select k, min(product_id) as product_id, min(jan_code) as jan_code, min(name) as name, min(maker) as maker,
             min(sku) as sku, sum(quantity)::integer as wanted, min(wanted_by) as first_wanted_by,
             jsonb_agg(jsonb_build_object('request_id', rid, 'number', request_number,
                       'customer', coalesce(customer_name, title), 'wanted_by', wanted_by, 'quantity', quantity)
                       order by wanted_by nulls last, request_number) as wishes
        from l group by k
    )
    select jsonb_agg(jsonb_build_object(
             'product_id', g.product_id, 'jan', g.jan_code, 'name', coalesce(p.name, g.name), 'maker', coalesce(p.maker, g.maker),
             'sku', coalesce(p.sku, g.sku), 'wanted', g.wanted, 'first_wanted_by', g.first_wanted_by, 'wishes', g.wishes,
             'on_hand', s.on_hand, 'kept', s.kept, 'free', greatest(s.on_hand - s.kept, 0),
             'short', greatest(g.wanted - greatest(s.on_hand - s.kept, 0), 0))
           order by greatest(g.wanted - greatest(s.on_hand - s.kept, 0), 0) desc, g.first_wanted_by nulls last, coalesce(p.name, g.name))
      from g
      left join public.products p on p.id = g.product_id
      cross join lateral (
        select coalesce((select sum(sl.on_hand) from public.stock_levels sl
                          where (sl.product_id = g.product_id or (g.jan_code is not null and sl.jan_code = g.jan_code))
                            and public.can_access_warehouse(sl.warehouse_id)
                            and (p_warehouse_id is null or sl.warehouse_id = p_warehouse_id)), 0)::integer as on_hand,
               case when g.product_id is null then 0 else coalesce((
                 select sum(coalesce(public.stock_reserved(g.product_id, w.id), 0) + public.outbound_kept_qty(g.product_id, w.id))
                   from public.warehouses w
                  where public.can_access_warehouse(w.id) and (p_warehouse_id is null or w.id = p_warehouse_id)), 0)::integer end as kept
      ) s), '[]'::jsonb);
end;
$$;
revoke all on function public.purchase_requests_summary(bigint) from public, anon;
grant execute on function public.purchase_requests_summary(bigint) to authenticated;
